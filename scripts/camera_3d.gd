extends Camera3D

# Movement and rotation speeds (units per second or radians per second)
@export var move_speed: float = 500.0
@export var rotate_speed: float = 2.0

# Zoom settings
@export var zoom_speed: float = 20.0
@export var min_zoom_distance: float = 30.0
@export var max_zoom_distance: float = 2000.0
@export var initial_zoom: float = 100.0

# Fixed orbit elevation angle (in radians). This is the angle above the horizontal.
# For a 60° elevation, set orbit_pitch = deg2rad(60)
@export var orbit_pitch: float = deg_to_rad(60)

# Internal state: the point on the ground the camera looks at, current zoom distance, and current yaw rotation.
var target: Vector3 = Vector3.ZERO
var zoom_distance: float
var yaw: float = 0.0

# Which voxel the camera is looking at
var voxel_coord: Vector3i

func _ready() -> void:
	zoom_distance = initial_zoom
	update_camera_transform()

func _process(delta: float) -> void:
	# Calculate horizontal basis vectors from the current yaw.
	# These determine in which horizontal direction the camera pans.
	var pan_forward: Vector3 = Vector3(-sin(yaw), 0, -cos(yaw))
	var pan_right: Vector3 = Vector3(cos(yaw), 0, -sin(yaw))
	
	# Move the target with WASD keys:
	# W/S moves the target forward/backward along the camera’s current forward (on the ground)
	# A/D moves the target left/right.
	if Input.is_key_pressed(KEY_W):
		target += pan_forward * move_speed * delta
	if Input.is_key_pressed(KEY_S):
		target -= pan_forward * move_speed * delta
	if Input.is_key_pressed(KEY_A):
		target -= pan_right * move_speed * delta
	if Input.is_key_pressed(KEY_D):
		target += pan_right * move_speed * delta
	
	# Rotate the camera around the target with Q and E keys.
	if Input.is_key_pressed(KEY_Q):
		yaw -= rotate_speed * delta
	if Input.is_key_pressed(KEY_E):
		yaw += rotate_speed * delta
	
	update_camera_transform()
	
	## Raycast to find where the player's mouse is targeting
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = self.project_ray_origin(mouse_position)
	var ray_dir: Vector3 = self.project_ray_normal(mouse_position)
	var ray_end: Vector3 = ray_origin + ray_dir * 1000.0
	
	var space_state = get_world_3d().direct_space_state
	# Exclude the camera from collisions.
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_pos: Vector3 = result.position
		# Assume voxel grid aligned with world axes and 1m cubes.
		voxel_coord = Vector3i(floor(hit_pos.x), floor(hit_pos.y), floor(hit_pos.z))
		%HighlightBox.update_outline_thick(voxel_coord)
	else:
		%HighlightBox.clear_outline()

func _unhandled_input(event: InputEvent) -> void:
	# Use the scroll wheel to zoom in and out.
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				zoom_distance = max(min_zoom_distance, zoom_distance - zoom_speed)
			MOUSE_BUTTON_WHEEL_DOWN:
				zoom_distance = min(max_zoom_distance, zoom_distance + zoom_speed)
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
				%WorldControls.mesh_interact(voxel_coord, event)

func update_camera_transform() -> void:
	# Compute the offset from the target using spherical coordinates.
	# The X and Z components are determined by the yaw and the horizontal component of the offset (cos(orbit_pitch)).
	# The Y component is set by the vertical part (sin(orbit_pitch)).
	var offset: Vector3 = Vector3(
		zoom_distance * cos(orbit_pitch) * sin(yaw),
		zoom_distance * sin(orbit_pitch),
		zoom_distance * cos(orbit_pitch) * cos(yaw)
	)
	
	# Set the camera's global position so that it is offset from the target.
	global_position = target + offset
	
	# Ensure the camera always looks at the target with the world up vector.
	look_at(target, Vector3.UP)
