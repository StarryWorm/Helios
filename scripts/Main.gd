extends Node3D

@onready var WorldControls = %WorldControls

func _ready():
	await get_tree().process_frame
	ResourceManager.load_configs()
	WorldControls.generate_random_mesh()
	$MainCamera.set_current(true)
