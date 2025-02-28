@tool
extends Node

# Exported buttons
@export_category("World Generation Settings")
@export_category("Simplex Noise Settings")
@export_category("Map Operations")
@export_tool_button("Generate", "Callable") var generate = _regenerate_test_mesh
@export_tool_button("Generate Random", "Callable") var generate_r = _generate_random_mesh
@export_category("Chunk Operations")
@export_tool_button("Generate Chunk", "Callable") var gen_chunk = _generate_test_chunk
@export_tool_button("Delete Chunk", "Callable") var del_chunk = _delete_chunk

# Variables for world gen
# World Var
var chunk_size: int = 50
var chunk_count: int = 20
var chunk_spacing: int = 1
@export var manual_chunk_x: int = 3
@export var manual_chunk_z: int = 1
var test_seed: int = 12345

# Terrain Var
var hill_amplitude: int = 3  # Maximum hill variation (+/- 2 blocks)
var river_depth: int = 5     # Maximum depression for rivers/lakes
var base_height: int = 10    # Base Height for the world
var frequency: float = 0.01      # Scale of the noise map
var octaves: int = 4             # Number of noise octaves
var lacunarity: float = 0.600    # Change in frequency per octave
var gain: float = 3.00           # Change in strength per octave
var weighted_strength: float = 0.130  # How much further octaves affect values if previous octaves give strong values

# Tree Var
var tree_frequency: float = 0.004


func _regenerate_test_mesh():
	%WorldControls.regenerate_test_mesh()

func _generate_random_mesh():
	%WorldControls.generate_random_mesh()

func _generate_test_chunk():
	%WorldControls.generate_chunk(manual_chunk_x, manual_chunk_z)

func _delete_chunk():
	%WorldControls.delete_chunk(manual_chunk_x, manual_chunk_z)
