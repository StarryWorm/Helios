@tool
extends Node

# Import some global things
var profiler: Profiler

# Track the world being generated
var world_terrain_noise: FastNoiseLite
var feature_generator: FeatureGenerator
var chunks: Dictionary[Vector2i, CHUNK]

func generate_random_mesh():
	profiler = Profiler.new()
	profiler.init_profiler()
	print("Generating Random Mesh")
	generate_world_mesh()

func regenerate_test_mesh():
	profiler = Profiler.new()
	profiler.init_profiler()
	print("Regenerating Test Mesh")
	var test_seed = %Global.test_seed
	generate_world_mesh(test_seed)

func generate_world_mesh(noise_seed: int = -1):
	seed(noise_seed)
	var chunk_count = %Global.chunk_count
	
	# Delete all existing chunk meshes and clear the array
	for child in %WorldMesh.get_children():
		child.queue_free()
	chunks.clear()
	
	# Generate a random seed if none is given
	if noise_seed == -1:
		randomize()
		noise_seed = randi()
		%Global.test_seed = noise_seed
	
	# Set up noise and feature generator
	set_world_noise(noise_seed)
	
	# Generate chunks
	for chunk_x in range(chunk_count):
		for chunk_z in range(chunk_count):
			generate_chunk(chunk_x, chunk_z)
	
	profiler.end_profiling()
	print("Done Generating")

func set_world_noise(noise_seed: int):
	# Set up terrain noise
	world_terrain_noise = FastNoiseLite.new()
	world_terrain_noise.seed = noise_seed
	world_terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	world_terrain_noise.fractal_octaves = %Global.octaves if %Global.octaves > 0 else 1
	world_terrain_noise.frequency = %Global.frequency
	world_terrain_noise.fractal_gain = %Global.gain
	world_terrain_noise.fractal_lacunarity = %Global.lacunarity
	world_terrain_noise.fractal_weighted_strength = %Global.weighted_strength
	
	# Initialize feature generator with the same seed
	feature_generator = FeatureGenerator.new(noise_seed)

func generate_chunk(chunk_x, chunk_z):
	var key = Vector2i(chunk_x, chunk_z)
	var chunk_size = %Global.chunk_size
	var chunk_spacing = %Global.chunk_spacing
	
	# Parameters to pass to the chunk
	var params: Dictionary
	params["base_height"] = %Global.base_height
	params["hill_amplitude"] = %Global.hill_amplitude
	params["river_depth"] = %Global.river_depth
	
	# Delete the chunk (method handles case where chunk does not exist)
	delete_chunk(chunk_x, chunk_z)
	
	# Generate chunk - pass null for tree_mesh, will use feature system instead
	var chunk = CHUNK.new(chunk_x, chunk_z, %Global.chunk_size)
	
	# Generate terrain
	chunk.generate_terrain_noise_map(world_terrain_noise, params)
	chunk.generate_terrain()
	
	# Generate features
	chunk.generate_features(feature_generator)
	
	# Generate the chunk mesh
	chunk.generate_chunk_mesh()
	
	# Add features
	chunk.add_features(feature_generator)
	
	# Add chunk to world
	%WorldMesh.add_child(chunk)
	chunk.set_position(Vector3i(chunk_x * chunk_size * chunk_spacing, 0, chunk_z * chunk_size * chunk_spacing))
	
	# Store reference to chunk and its associated data
	chunks[key] = chunk

func delete_chunk(chunk_x, chunk_z):
	var key = Vector2i(chunk_x, chunk_z)
	
	if chunks.has(key):
		# Safely remove the node
		chunks[key].queue_free()
		# Remove the reference from the dictionary
		chunks.erase(key)

# Handle interaction with chunks
func mesh_interact(position: Vector3i, event: InputEvent):
	var chunk_size = %Global.chunk_size
	var chunk_spacing = %Global.chunk_spacing
	var chunk_count = %Global.chunk_count
	
	if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
		# Find which chunk the action happened in
		@warning_ignore("integer_division")
		var chunk_x = floori(position.x / (chunk_size * chunk_spacing))
		@warning_ignore("integer_division")
		var chunk_z = floori(position.z / (chunk_size * chunk_spacing))
		
		# Find where it happened in the chunk
		var chunk_hit_x = position.x % int(chunk_size * chunk_spacing)
		var chunk_hit_z = position.z % int(chunk_size * chunk_spacing)
		
		# Dump if it happened outside the chunks, i.e. spacing > 1, or just beyond the map
		if chunk_hit_x > chunk_size or chunk_hit_z > chunk_size or chunk_x > chunk_count or chunk_z > chunk_count:
			return
		
		var action: Global.ACTION
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				action = Global.ACTION.BREAK
			MOUSE_BUTTON_RIGHT:
				action = Global.ACTION.PLACE
		chunks[Vector2i(chunk_x,chunk_z)].update_chunk(chunk_hit_x, chunk_hit_z, position.y + 1, action)
