class_name FeatureStruct
extends Resource

# Resource identification
var feature_id: String
var feature_type: String  # "tree", "ore", "structure", etc.
var display_name: String
var description: String

# Mesh reference
var mesh_path: String  # Path to mesh file in res://assets/meshes/

# Generator association
var generator: GeneratorStruct  # Direct reference to associated generator

# Feature size and priority
var width: int = 1  # Width in blocks (x-axis)
var depth: int = 1  # Depth in blocks (z-axis)
var priority: int = 0  # Higher number = higher priority for collision resolution

# Noise parameters
var seed_offset: int
var noise_type: int = FastNoiseLite.TYPE_PERLIN
var frequency: float
var threshold: float  # Noise threshold for placement

# Fractal noise parameters
var use_fractal: bool = false
var octaves: int = 1
var lacunarity: float = 2.0
var gain: float = 0.5
var weighted_strength: float = 0.0

# Placement parameters
var spawn_in_water: bool = false
var min_scale: float = 1.0
var max_scale: float = 1.0
var random_rotation: bool = true
var position_variance: float = 0.0

# Visual parameters
var color: Color = Color.WHITE

func _init(json_data: String = ""):
	if json_data.is_empty():
		return
		
	var parsed = JSON.parse_string(json_data)
	if parsed == null:
		push_error("Failed to parse feature config JSON")
		return
	
	feature_id = parsed.get("feature_id", "")
	feature_type = parsed.get("feature_type", "")
	display_name = parsed.get("display_name", "")
	description = parsed.get("description", "")
	
	# Add feature size and priority
	width = parsed.get("width", 1)
	depth = parsed.get("depth", 1)
	priority = parsed.get("priority", 0)
	
	mesh_path = parsed.get("mesh_path", "")
	# Generator will be associated later in ResourceManager
	
	seed_offset = parsed.get("seed_offset", 0)
	noise_type = parsed.get("noise_type", FastNoiseLite.TYPE_PERLIN)
	frequency = parsed.get("frequency", 0.01)
	threshold = parsed.get("threshold", 0.7)
	
	use_fractal = parsed.get("use_fractal", false)
	if use_fractal:
		octaves = parsed.get("octaves", 1)
		lacunarity = parsed.get("lacunarity", 2.0)
		gain = parsed.get("gain", 0.5)
		weighted_strength = parsed.get("weighted_strength", 0.0)
	
	spawn_in_water = parsed.get("spawn_in_water", false)
	min_scale = parsed.get("min_scale", 1.0)
	max_scale = parsed.get("max_scale", 1.0)
	random_rotation = parsed.get("random_rotation", true)
	position_variance = parsed.get("position_variance", 0.0)
	
	# Color handling
	if parsed.has("color"):
		var color_data = parsed["color"]
		if color_data is Dictionary and color_data.has("r") and color_data.has("g") and color_data.has("b"):
			color = Color(color_data.r/255.0, color_data.g/255.0, color_data.b/255.0)
	
	# Store generator_id string to be resolved later
	if parsed.has("generator_id"):
		set_meta("generator_id", parsed.get("generator_id"))
