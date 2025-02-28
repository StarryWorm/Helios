class_name CHUNK
extends Node3D

# Size & Location
var x: int
var z: int
var size: int

# Terrain stuff
var height_data: Array[Array]
var block_data: Array[Array]
var terrain_noise_data: Array[Array]
var mesh_instance: MeshInstance3D
var static_body: StaticBody3D
var collision_shape: CollisionShape3D
var terrain_params: Dictionary

# Cached materials
var vertex_color_material: StandardMaterial3D

# Color definitions (constants to avoid recreating each time)
const SIDE_COLOR = Color(48/255.0, 38/255.0, 22/255.0, 1.0)
const GRASS_COLOR = Color(48/255.0, 146/255.0, 87/255.0, 0.0)
const WATER_COLOR = Color(0/255.0, 94/255.0, 255/255.0, 0.0)
const DIRT_COLOR = Color(48/255.0, 38/255.0, 22/255.0, 1.0)

# Feature data
var feature_data: Dictionary = {}
var feature_instances: Dictionary = {}

# Feature position map for quick lookup
var feature_position_map: Dictionary = {}

func _init(chunk_x, chunk_z, chunk_size):
	self.x = chunk_x
	self.z = chunk_z
	self.size = chunk_size
	
	# Pre-create the material
	vertex_color_material = StandardMaterial3D.new()
	vertex_color_material.vertex_color_use_as_albedo = true

func generate_terrain_noise_map(terrain_noise: FastNoiseLite, terrain_generation_params: Dictionary):
	terrain_params = terrain_generation_params
	var hill_amplitude = terrain_params["hill_amplitude"]
	var river_depth = terrain_params["river_depth"]
	var base_height = terrain_params["base_height"]
	
	# Use typed arrays
	var map: Array[Array] = []
	map.resize(size)
	
	# Batch noise generation for better performance
	for block_x in range(size):
		var map_z: Array = []
		map_z.resize(size)
		
		for block_z in range(size):
			var coords = Vector2i(block_x + x * size, block_z + z * size)
			var noise_val = terrain_noise.get_noise_2d(coords.x, coords.y)
			
			# Optimize noise transforms with fewer operations
			noise_val = (-noise_val * 0.75) + 0.25
			if noise_val < 0: 
				noise_val = pow(noise_val, 4.0) * -river_depth
			else:
				noise_val *= hill_amplitude
				
			map_z[block_z] = int(floor(noise_val + base_height))
		map[block_x] = map_z
	
	terrain_noise_data = map

func generate_terrain():
	var min_y = 0
	var base_height = terrain_params["base_height"]
	
	# Pre-allocate arrays
	block_data = []
	block_data.resize(size)
	height_data = []
	height_data.resize(size)
	
	for block_x in range(size):
		var block_data_z = []
		block_data_z.resize(size)
		var height_data_z = []
		height_data_z.resize(size)
		var noise_data_z = terrain_noise_data[block_x]
		
		for block_z in range(size):
			var h = noise_data_z[block_z]
			
			# Add height to height map
			height_data_z[block_z] = max(int(h), base_height)
			
			var block_data_h = []
			
			# Add dirt at the bottom (use append_array instead of looping)
			if h > min_y:
				block_data_h.resize(h - min_y)
				for y in range(h - min_y):
					block_data_h[y] = Global.BLOCKS.DIRT
			
			# Add grass or water
			if h < base_height:
				for y in range(h, base_height + 1):
					block_data_h.append(Global.BLOCKS.WATER)
			else:
				block_data_h.append(Global.BLOCKS.GRASS)
			
			block_data_z[block_z] = block_data_h
		
		block_data[block_x] = block_data_z
		height_data[block_x] = height_data_z

func generate_features(feature_generator: FeatureGenerator):
	# Clear feature position map
	feature_position_map.clear()
	
	# Generate feature maps based on terrain data
	feature_data = feature_generator.generate_feature_maps(
		x, z, size, 
		terrain_params["base_height"], 
		terrain_noise_data
	)

func generate_chunk_mesh():
	# Create surface tool only if needed
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Greedily mesh the top faces - this is already efficient
	var top_quads = greedy_mesh_top()
	
	# Add the top faces (merged quads)
	for quad in top_quads:
		var quad_x = quad["x"]
		var quad_z = quad["z"]
		var w = quad["w"]
		var d = quad["d"]
		var h = quad["height"] - 0.05
		var block_type = quad["type"]
		
		# Lower water by .2 for visual effect
		if block_type == Global.BLOCKS.WATER: 
			h -= 0.2
		
		# Use pre-defined colors
		var col_color
		match block_type:
			Global.BLOCKS.WATER:
				col_color = WATER_COLOR
			Global.BLOCKS.GRASS:
				col_color = GRASS_COLOR
			_:
				col_color = DIRT_COLOR
		
		# Define quad vertices once
		var v0 = Vector3(quad_x, h, quad_z)
		var v1 = Vector3(quad_x + w, h, quad_z)
		var v2 = Vector3(quad_x + w, h, quad_z + d)
		var v3 = Vector3(quad_x, h, quad_z + d)
		add_quad(st, v0, v1, v2, v3, Vector3.UP, col_color)
	
	# Add bottom face
	add_quad(st, Vector3(0,0,0), Vector3(size,0,0), Vector3(size,0,size), Vector3(0,0,size), Vector3.UP, SIDE_COLOR)
	
	# Handle vertical faces with a more optimized approach
	for block_x in range(size):
		var block_data_z = block_data[block_x]
		for block_z in range(size):
			var h = height_data[block_x][block_z]
			var cur_type = block_data_z[block_z][-1] # Get the top block type
			
			# Apply water height adjustment once
			var face_h = h - (0.25 if cur_type == Global.BLOCKS.WATER else 0.05)
			
			# Get neighbor heights with bounds checking
			var n_w = 0 if block_x == 0 else height_data[block_x - 1][block_z]
			var n_e = 0 if block_x == size - 1 else height_data[block_x + 1][block_z]
			var n_n = 0 if block_z == 0 else height_data[block_x][block_z - 1]
			var n_s = 0 if block_z == size - 1 else height_data[block_x][block_z + 1]
			
			# Add faces only if needed
			if n_w < h:
				add_quad(
					st,
					Vector3(block_x, face_h, block_z),
					Vector3(block_x, face_h, block_z + 1),
					Vector3(block_x, n_w, block_z + 1),
					Vector3(block_x, n_w, block_z),
					Vector3(-1, 0, 0),
					SIDE_COLOR
				)
			
			if n_e < h:
				add_quad(
					st,
					Vector3(block_x + 1, n_e, block_z),
					Vector3(block_x + 1, n_e, block_z + 1),
					Vector3(block_x + 1, face_h, block_z + 1),
					Vector3(block_x + 1, face_h, block_z),
					Vector3(1, 0, 0),
					SIDE_COLOR
				)
			
			if n_n < h:
				add_quad(
					st,
					Vector3(block_x, face_h, block_z),
					Vector3(block_x, n_n, block_z),
					Vector3(block_x + 1, n_n, block_z),
					Vector3(block_x + 1, face_h, block_z),
					Vector3(0, 0, -1),
					SIDE_COLOR
				)
			
			if n_s < h:
				add_quad(
					st,
					Vector3(block_x + 1, face_h, block_z + 1),
					Vector3(block_x + 1, n_s, block_z + 1),
					Vector3(block_x, n_s, block_z + 1),
					Vector3(block_x, face_h, block_z + 1),
					Vector3(0, 0, 1),
					SIDE_COLOR
				)
	
	# Finalize mesh
	st.index()
	var mesh = st.commit()
	
	# Create/reuse mesh instance
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	
	# Reuse material
	mesh_instance.material_override = vertex_color_material
	
	# Create collision shape
	if static_body == null:
		static_body = StaticBody3D.new()
		mesh_instance.add_child(static_body)
		collision_shape = CollisionShape3D.new()
		static_body.add_child(collision_shape)
	
	# Generate collision trimesh
	collision_shape.shape = mesh_instance.mesh.create_trimesh_shape()
	
	# Add meshes to scene (if not already added)
	if not mesh_instance.is_inside_tree():
		add_child(mesh_instance)

func add_features(feature_generator: FeatureGenerator):
	# Clear any existing feature instances and position map
	for feature_id in feature_instances:
		var instance = feature_instances[feature_id]
		if instance != null and is_instance_valid(instance):
			instance.queue_free()
	
	feature_instances.clear()
	feature_position_map.clear()
	
	# Create feature instances using the feature generator
	feature_generator.create_features_for_chunk(self)
	
	# Update the feature position map
	update_feature_position_map()

# Create a map of positions to features for quick lookup
func update_feature_position_map():
	feature_position_map.clear()
	
	for feature_id in feature_instances:
		var instance = feature_instances[feature_id]
		if not is_instance_valid(instance):
			continue
			
		# Get feature data
		var width = 1
		var depth = 1
		var priority = 0
		
		if instance.has_meta("width"):
			width = instance.get_meta("width")
		if instance.has_meta("depth"):
			depth = instance.get_meta("depth")
		if instance.has_meta("priority"):
			priority = instance.get_meta("priority")
			
		# Calculate the bottom-left corner of the feature (in local chunk space)
		var local_pos = instance.transform.origin
		var start_x = int(local_pos.x - (width / 2.0))
		var start_z = int(local_pos.z - (depth / 2.0))
		
		# Add all positions occupied by this feature
		for dx in range(width):
			for dz in range(depth):
				var pos = Vector2i(start_x + dx, start_z + dz)
				
				# Only add if this position is within the chunk
				if pos.x >= 0 and pos.x < size and pos.y >= 0 and pos.y < size:
					# Check if already occupied by higher priority feature
					if feature_position_map.has(pos):
						var existing_priority = feature_position_map[pos].priority
						if priority > existing_priority:
							feature_position_map[pos] = {
								"feature_id": feature_id,
								"instance": instance,
								"priority": priority
							}
					else:
						feature_position_map[pos] = {
							"feature_id": feature_id,
							"instance": instance,
							"priority": priority
						}

# Get feature at a position (if any)
func get_feature_at_position(block_x: int, block_z: int) -> Dictionary:
	var pos = Vector2i(block_x, block_z)
	if feature_position_map.has(pos):
		return feature_position_map[pos]
	return {}

func update_chunk(target_x: int, target_z: int, target_y: int, action: Global.ACTION):
	# Check if there's a feature at this position
	var feature = get_feature_at_position(target_x, target_z)
	if not feature.is_empty():
		# Handle feature interaction in WorldControls script
		# Just return here to prevent terrain modification beneath features
		return
		
	# Fast path - check conditions that would make the operation invalid
	if action == Global.ACTION.BREAK:
		if target_y <= 1 or target_y != height_data[target_x][target_z]:
			return
			
		# Remove top block
		block_data[target_x][target_z].pop_back()
		height_data[target_x][target_z] -= 1
		
		# Regenerate the mesh
		generate_chunk_mesh()
		
	elif action == Global.ACTION.PLACE:
		if target_y >= 30 or target_y != height_data[target_x][target_z]:
			return
			
		if block_data[target_x][target_z][target_y] != Global.BLOCKS.WATER:
			# Add new block
			block_data[target_x][target_z][target_y] = Global.BLOCKS.DIRT
			block_data[target_x][target_z].append(Global.BLOCKS.GRASS)
			height_data[target_x][target_z] += 1
			
			# Regenerate the mesh
			generate_chunk_mesh()

# Optimized add_quad with fewer function calls
func add_quad(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, normal: Vector3, col: Color) -> void:
	# First triangle
	st.set_color(col)
	st.set_normal(normal)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(v0)
	
	st.set_color(col)
	st.set_normal(normal)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(v1)
	
	st.set_color(col)
	st.set_normal(normal)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(v2)
	
	# Second triangle 
	st.set_color(col)
	st.set_normal(normal)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(v0)
	
	st.set_color(col)
	st.set_normal(normal)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(v2)
	
	st.set_color(col)
	st.set_normal(normal)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(v3)

# This greedy meshing is already efficient
func greedy_mesh_top() -> Array:
	var quads = []
	var used: Array[Array] = []
	used.resize(size)
	
	for i in range(size):
		var row: Array[bool] = []
		row.resize(size)
		for j in range(size):
			row[j] = false
		used[i] = row
	
	for block_x in range(size):
		for block_z in range(size):
			if used[block_x][block_z]:
				continue
			
			var cur_height = height_data[block_x][block_z]
			var cur_type = block_data[block_x][block_z][cur_height]
			
			# Determine maximum horizontal extent
			var w_extent = block_x + 1
			while w_extent < size and not used[w_extent][block_z] and height_data[w_extent][block_z] == cur_height and block_data[w_extent][block_z][cur_height] == cur_type:
				w_extent += 1
			
			# Determine maximum vertical extent
			var d_extent = block_z + 1
			while d_extent < size:
				var valid = true
				for i in range(block_x, w_extent):
					if used[i][d_extent] or height_data[i][d_extent] != cur_height or block_data[i][d_extent][cur_height] != cur_type:
						valid = false
						break
				if not valid:
					break
				d_extent += 1
			
			# Mark cells as used
			for i in range(block_x, w_extent):
				for j in range(block_z, d_extent):
					used[i][j] = true
					
			quads.append({
				"x": block_x, 
				"z": block_z, 
				"w": w_extent - block_x, 
				"d": d_extent - block_z, 
				"height": cur_height, 
				"type": cur_type
			})
			
	return quads
