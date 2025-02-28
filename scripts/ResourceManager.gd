extends Node

var config_files: Array[String]

var RESOURCES: Dictionary[String, ResourceStruct]
var RECIPES: Dictionary[String, RecipeStruct]
var GENERATORS: Dictionary[String, GeneratorStruct]
var FEATURES: Dictionary[String, FeatureStruct]

# Mesh cache
var mesh_cache: Dictionary = {}

# Loads all config files in res://configs and initializes them
func load_configs():
	load_files("res://config", ".json", config_files)
	
	var resources: Array[String]
	var recipes: Array[String]
	var generators: Array[String]
	var features: Array[String]
	
	# Go through and move them to the correct arrays
	for file in range(config_files.size()):
		var file_path = config_files[file]
		if file_path.contains("resources"):
			resources.append(file_path)
		elif file_path.contains("recipes"):
			recipes.append(file_path)
		elif file_path.contains("generators"):
			generators.append(file_path)
		elif file_path.contains("features"):
			features.append(file_path)
	
	# Load resources first
	for file in range(resources.size()):
		var file_path = resources[file]
		var file_name = get_filename(file_path)
		var file_text = FileAccess.get_file_as_string(file_path)
		RESOURCES[file_name] = ResourceStruct.new(file_text)
	
	# Load recipes second
	for file in range(recipes.size()):
		var file_path = recipes[file]
		var file_name = get_filename(file_path)
		var file_text = FileAccess.get_file_as_string(file_path)
		RECIPES[file_name] = RecipeStruct.new(file_text)
	
	# Load generators third
	for file in range(generators.size()):
		var file_path = generators[file]
		var file_name = get_filename(file_path)
		var file_text = FileAccess.get_file_as_string(file_path)
		GENERATORS[file_name] = GeneratorStruct.new(file_text)
	
	# Load features last to connect with generators
	for file in range(features.size()):
		var file_path = features[file]
		var file_name = get_filename(file_path)
		var file_text = FileAccess.get_file_as_string(file_path)
		var feature = FeatureStruct.new(file_text)
		
		# Connect feature with its generator
		if feature.has_meta("generator_id"):
			var generator_id = feature.get_meta("generator_id")
			if GENERATORS.has(generator_id):
				feature.generator = GENERATORS[generator_id]
			else:
				push_error("Generator ID not found for feature: " + feature.feature_id)
		
		FEATURES[file_name] = feature	
	print("Loaded features: ", FEATURES.keys())

# Get features by type
func get_features_by_type(feature_type: String) -> Array[FeatureStruct]:
	var result: Array[FeatureStruct] = []
	
	for feature_id in FEATURES:
		var feature = FEATURES[feature_id]
		if feature.feature_type == feature_type:
			result.append(feature)
	
	return result

# Get features by priority
func get_features_by_priority(min_priority: int, max_priority: int) -> Array[FeatureStruct]:
	var result: Array[FeatureStruct] = []
	
	for feature_id in FEATURES:
		var feature = FEATURES[feature_id]
		if feature.priority >= min_priority and feature.priority <= max_priority:
			result.append(feature)
	
	return result

# Helper function for loading files from a directory and store their paths into an array
func load_files(path: String, extension: String, destination_array: Array) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		push_error("Cannot open directory: ", path)
		return

	# Begin directory listing; skip hidden files/directories and "." and ".."
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var file_path = path + "/" + file_name
		if dir.current_is_dir():
			# Recursively search subdirectories
			load_files(file_path, extension, destination_array)
		elif file_name.to_lower().ends_with(extension):
			destination_array.append(file_path)
		file_name = dir.get_next()
	dir.list_dir_end()

# Helper function to extract file name, without extension, from its path
func get_filename(filepath: String):
	return filepath.get_file().split(".")[0]

# Load a mesh from path and cache it
func load_mesh(mesh_path: String) -> Mesh:
	if mesh_cache.has(mesh_path):
		return mesh_cache[mesh_path]
		
	var full_path = "res://assets/meshes/" + mesh_path
	if ResourceLoader.exists(full_path):
		var mesh = ResourceLoader.load(full_path)
		if mesh is Mesh:
			mesh_cache[mesh_path] = mesh
			return mesh
			
	push_error("Failed to load mesh: " + mesh_path)
	return null

# Get all meshes for features
func get_feature_meshes() -> Dictionary:
	var meshes = {}
	
	for feature_id in FEATURES:
		var feature = FEATURES[feature_id]
		if not feature.mesh_path.is_empty():
			meshes[feature_id] = load_mesh(feature.mesh_path)
	
	return meshes
