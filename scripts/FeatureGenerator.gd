class_name FeatureGenerator
extends Node

# Dictionary of noise generators for each feature
var noise_generators: Dictionary = {}

# Dictionary to track generated features by chunk
var chunk_features: Dictionary = {}

# Random number generator (reused)
var rng: RandomNumberGenerator

func _init(seed_value: int):
	# Initialize with world seed
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	
	# Initialize noise generators for each feature
	initialize_noise_generators()

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
	
	# Generate feature maps for each configured feature
	for feature_id in ResourceManager.FEATURES:
		var feature = ResourceManager.FEATURES[feature_id]
		var noise = noise_generators[feature_id]
		var threshold = feature.threshold
		var feature_instances = []
		
		# Check chunk positions for feature placement (optimized)
		for block_x in range(chunk_size):
			var height_row = height_data[block_x]
			for block_z in range(chunk_size):
				var terrain_height = height_row[block_z]
				
				# Skip if underwater and feature shouldn't spawn in water
				if terrain_height < base_height and not feature.spawn_in_water:
					continue
				
				# Get world coordinates for noise sampling
				var world_x = block_x + chunk_x * chunk_size
				var world_z = block_z + chunk_z * chunk_size
				
				# Check noise threshold for this feature
				var noise_val = noise.get_noise_2d(world_x, world_z)
				
				if noise_val > threshold:
					# Generate variation based on config
					var scale = rng.randf_range(feature.min_scale, feature.max_scale)
					var rotation = rng.randf_range(0, TAU) if feature.random_rotation else 0.0
					var pos_x_offset = rng.randf_range(-feature.position_variance, feature.position_variance)
					var pos_z_offset = rng.randf_range(-feature.position_variance, feature.position_variance)
					
					var pos_x = block_x + pos_x_offset + 0.5
					var pos_z = block_z + pos_z_offset + 0.5
					
					feature_instances.append({
						"x": pos_x,
						"z": pos_z,
						"y": terrain_height,
						"scale": scale,
						"rotation": rotation,
						"feature_id": feature_id
					})
				
				#print("Spawning tree at ", Vector2i(block_x, block_z), " in chunk ", chunk_key, ". Height: ", terrain_height)
		
		# Only store data if instances were found
		if feature_instances.size() > 0:
			feature_maps[feature_id] = feature_instances
			chunk_features[chunk_key][feature_id] = feature_instances
	
	return feature_maps

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
			basis = basis.scaled(Vector3(scale, scale, scale))
			
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
