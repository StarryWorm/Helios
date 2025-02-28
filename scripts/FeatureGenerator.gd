class_name FeatureGenerator
extends Node

# Dictionary of noise generators for each feature
var noise_generators: Dictionary = {}

# Dictionary to track generated features by chunk
var chunk_features: Dictionary = {}

# NEW: Move placed_features to be a class member for persistence across chunks
var placed_features: Dictionary = {}

# Random number generator (reused)
var rng: RandomNumberGenerator

func _init(seed_value: int):
	# Initialize with world seed
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	
	# Initialize noise generators for all features
	initialize_noise_generators()
	
	# NEW: Initialize the placed_features dictionary
	for feature_id in ResourceManager.FEATURES:
		placed_features[feature_id] = []

# Initialize noise generators for all features
func initialize_noise_generators():
	print("Initializing noise generators")
	print("Available features: ", ResourceManager.FEATURES.keys())
	for feature_id in ResourceManager.FEATURES:
		var feature = ResourceManager.FEATURES[feature_id]
		
		# Create noise generator
		var noise = FastNoiseLite.new()
		noise.seed = rng.seed + feature.seed_offset
		
		# Set noise parameters from config
		noise.noise_type = feature.noise_type
		noise.frequency = feature.frequency
		
		if feature.use_fractal:
			noise.fractal_octaves = feature.octaves
			noise.fractal_lacunarity = feature.lacunarity
			noise.fractal_gain = feature.gain
			noise.fractal_weighted_strength = feature.weighted_strength
		
		noise_generators[feature_id] = noise

# Generate feature noise map for a specific chunk
func generate_feature_maps(chunk_x: int, chunk_z: int, chunk_size: int, base_height: int, height_data: Array):
	var chunk_key = Vector2i(chunk_x, chunk_z)
	var feature_maps = {}
	
	# Create empty structure to hold features for this chunk
	chunk_features[chunk_key] = {}
	
	# Sort features by priority (low to high)
	var sorted_features = []
	for feature_id in ResourceManager.FEATURES:
		sorted_features.append(ResourceManager.FEATURES[feature_id])
	
	sorted_features.sort_custom(Callable(self, "_sort_by_priority"))
	
	# Create a 2D grid to track occupied blocks
	var occupied_blocks = {}
	
	# Generate feature maps for each configured feature in priority order
	for feature in sorted_features:
		var feature_id = feature.feature_id
		var noise = noise_generators[feature_id]
		var threshold = feature.threshold
		var feature_instances = []
		
		# Check chunk positions for feature placement
		for block_x in range(chunk_size):
			var height_row = height_data[block_x]
			for block_z in range(chunk_size):
				var terrain_height = height_row[block_z]
				
				# Skip if underwater and feature shouldn't spawn in water
				if terrain_height < base_height and not feature.spawn_in_water:
					continue
				
				# Skip if this position doesn't have enough space for the feature
				if not _has_space_for_feature(block_x, block_z, feature, chunk_size):
					continue
				
				# Check that all blocks under the feature are at the same height
				# and aren't water (if feature shouldn't spawn in water)
				var can_place_height = true
				for dx in range(feature.width):
					for dz in range(feature.depth):
						var fx = block_x + dx
						var fz = block_z + dz
						
						# Skip if out of bounds
						if fx >= chunk_size or fz >= chunk_size:
							can_place_height = false
							break
						
						# Check if this block is at the same height as the primary block
						if height_data[fx][fz] != terrain_height:
							can_place_height = false
							break
							
						# Check if this block is underwater and feature shouldn't spawn in water
						if height_data[fx][fz] < base_height and not feature.spawn_in_water:
							can_place_height = false
							break
					
					if not can_place_height:
						break
				
				if not can_place_height:
					continue
				
				# Get world coordinates for noise sampling
				var world_x = block_x + chunk_x * chunk_size
				var world_z = block_z + chunk_z * chunk_size
				
				# Check noise threshold for this feature
				var noise_val = noise.get_noise_2d(world_x, world_z)
				
				if noise_val > threshold:
					# Check if the area is already occupied by a higher priority feature
					var can_place = true
					
					# Check all blocks that this feature would occupy
					for dx in range(feature.width):
						for dz in range(feature.depth):
							var fx = block_x + dx
							var fz = block_z + dz
							
							# Skip if out of bounds
							if fx >= chunk_size or fz >= chunk_size:
								can_place = false
								break
								
							var key = Vector2i(fx, fz)
							if occupied_blocks.has(key):
								var existing_priority = occupied_blocks[key]
								if existing_priority >= feature.priority:
									can_place = false
									break
					
					if not can_place:
						continue
					
					# Check blocking radius constraints
					if feature.blocking_radius > 0:
						# Calculate center position of this feature
						var feature_center_x = block_x + (feature.width / 2.0)
						var feature_center_z = block_z + (feature.depth / 2.0)
						var world_center_x = feature_center_x + chunk_x * chunk_size
						var world_center_z = feature_center_z + chunk_z * chunk_size
						
						# Check distance to all previously placed instances of the same feature
						var within_blocking_radius = false
						for placed in placed_features[feature_id]:
							var placed_x = placed.x
							var placed_z = placed.z
							
							# Calculate squared distance (more efficient than using sqrt)
							var dx = world_center_x - placed_x
							var dz = world_center_z - placed_z
							var squared_dist = dx * dx + dz * dz
							
							# Check if within blocking radius
							if squared_dist < feature.blocking_radius * feature.blocking_radius:
								within_blocking_radius = true
								break
						
						if within_blocking_radius:
							continue
					
					# Mark all blocks as occupied with this feature's priority
					for dx in range(feature.width):
						for dz in range(feature.depth):
							var fx = block_x + dx
							var fz = block_z + dz
							
							# Skip if out of bounds (already checked above, but just in case)
							if fx >= chunk_size or fz >= chunk_size:
								continue
								
							occupied_blocks[Vector2i(fx, fz)] = feature.priority
					
					# Generate variation based on config
					var scale = rng.randf_range(feature.min_scale, feature.max_scale)
					var rotation = rng.randf_range(0, TAU) if feature.random_rotation else 0.0
					var pos_x_offset = rng.randf_range(-feature.position_variance, feature.position_variance)
					var pos_z_offset = rng.randf_range(-feature.position_variance, feature.position_variance)
					
					# Calculate position based on feature size
					# Center of the feature should be at the center of its footprint
					var pos_x = block_x + (feature.width / 2.0) + pos_x_offset
					var pos_z = block_z + (feature.depth / 2.0) + pos_z_offset
					
					# World position for blocking radius tracking
					var world_pos_x = pos_x + chunk_x * chunk_size
					var world_pos_z = pos_z + chunk_z * chunk_size
					
					# Store world position for blocking radius checks
					placed_features[feature_id].append({
						"x": world_pos_x,
						"z": world_pos_z
					})
					
					# Store the feature instance data
					feature_instances.append({
						"x": pos_x,
						"z": pos_z,
						"y": terrain_height,
						"scale": scale,
						"rotation": rotation,
						"feature_id": feature_id,
						"width": feature.width,
						"depth": feature.depth
					})
		
		# Only store data if instances were found
		if feature_instances.size() > 0:
			feature_maps[feature_id] = feature_instances
			chunk_features[chunk_key][feature_id] = feature_instances
	
	return feature_maps

# Helper function to check if there's enough space for a feature
func _has_space_for_feature(block_x: int, block_z: int, feature: FeatureStruct, chunk_size: int) -> bool:
	if block_x + feature.width > chunk_size or block_z + feature.depth > chunk_size:
		return false
	return true

# Sort function for feature priority
func _sort_by_priority(a: FeatureStruct, b: FeatureStruct) -> bool:
	return a.priority < b.priority

# Optimized feature instance creation for a chunk
func create_features_for_chunk(chunk: CHUNK):
	var chunk_key = Vector2i(chunk.x, chunk.z)
	if not chunk_features.has(chunk_key):
		return
	
	# Create MultiMeshInstance3D for each feature type
	for feature_id in chunk_features[chunk_key]:
		var feature_instances = chunk_features[chunk_key][feature_id]
		var instance_count = feature_instances.size()
		
		if instance_count == 0:
			continue
		
		var feature = ResourceManager.FEATURES[feature_id]
		var mesh = ResourceManager.load_mesh(feature.mesh_path)
		
		# Skip if no mesh available
		if mesh == null:
			continue
		
		# Create a MultiMesh for this feature type
		var multi_mesh = MultiMesh.new()
		multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
		multi_mesh.instance_count = instance_count
		multi_mesh.mesh = mesh
		
		# Set transforms for all instances at once
		for i in range(instance_count):
			var instance = feature_instances[i]
			
			# Extract instance data
			var pos_x = instance["x"]
			var pos_z = instance["z"]
			var pos_y = instance["y"]
			var scale = instance["scale"]
			var rotation = instance["rotation"]
			
			# Create basis with rotation around Y axis
			var basis = Basis(Vector3.UP, rotation)
			# Scale the basis based on feature size and scale factor
			var x_scale = scale * (instance.get("width", 1) / 1.0)
			var z_scale = scale * (instance.get("depth", 1) / 1.0)
			basis = basis.scaled(Vector3(x_scale, scale, z_scale))
			
			# Set the transform
			multi_mesh.set_instance_transform(
				i,
				Transform3D(basis, Vector3(pos_x, pos_y, pos_z))
			)
		
		# Create the multi-mesh instance
		var multi_mesh_instance = MultiMeshInstance3D.new()
		multi_mesh_instance.multimesh = multi_mesh
		
		# Store metadata for interaction
		multi_mesh_instance.set_meta("feature_id", feature_id)
		multi_mesh_instance.set_meta("width", feature.width)
		multi_mesh_instance.set_meta("depth", feature.depth)
		multi_mesh_instance.set_meta("priority", feature.priority)
		if feature.generator != null:
			multi_mesh_instance.set_meta("generator", feature.generator)
		
		# Add material override if specified in feature config
		if feature.color != Color.WHITE:
			var material = StandardMaterial3D.new()
			material.albedo_color = feature.color
			material.roughness = 0.7
			material.metallic = 0.2 if feature_id.begins_with("ore_") and not feature_id.ends_with("coal") else 0.0
			multi_mesh_instance.material_override = material
		
		# Add to chunk and store reference
		chunk.add_child(multi_mesh_instance)
		chunk.feature_instances[feature_id] = multi_mesh_instance

# NEW: Helper function to get absolute world coordinates from chunk-local coordinates
func get_world_coordinates(chunk_x: int, chunk_z: int, local_x: float, local_z: float, chunk_size: int) -> Vector2:
	return Vector2(
		local_x + chunk_x * chunk_size,
		local_z + chunk_z * chunk_size
	)

# NEW: Function to clear tracking data (useful for world regeneration)
func clear_tracking_data():
	for feature_id in placed_features:
		placed_features[feature_id].clear()
