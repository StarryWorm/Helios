@tool
extends MeshInstance3D

@export_tool_button("Test Mesh") var testmesh = test_mesh

@onready var cam = %MainCamera
var outline_mesh: ArrayMesh

const thickness: float = 0.1

# We'll track the total number of vertices added to our SurfaceTool.
var vertex_count: int = 0

func test_mesh():
	_ready()
	update_outline_thick(Vector3i(0, 12, 0))

func _ready() -> void:
	self.mesh = null
	outline_mesh = ArrayMesh.new()
	self.mesh = outline_mesh

# Rebuilds the outline mesh for the voxel at voxel_coord using thick edges.
func update_outline_thick(voxel_coord: Vector3i) -> void:
	# Reset our vertex counter.
	vertex_count = 0
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Compute the 8 corners of the voxel.
	var v000: Vector3i = voxel_coord
	var v100: Vector3i = voxel_coord + Vector3i(1, 0, 0)
	var v010: Vector3i = voxel_coord + Vector3i(0, 1, 0)
	var v110: Vector3i = voxel_coord + Vector3i(1, 1, 0)
	var v001: Vector3i = voxel_coord + Vector3i(0, 0, 1)
	var v101: Vector3i = voxel_coord + Vector3i(1, 0, 1)
	var v011: Vector3i = voxel_coord + Vector3i(0, 1, 1)
	var v111: Vector3i = voxel_coord + Vector3i(1, 1, 1)
	
	# Define the 12 edges as pairs of endpoints.
	var edges = [
		[v000, v100],
		[v000, v010],
		[v000, v001],
		[v100, v110],
		[v100, v101],
		[v010, v110],
		[v010, v011],
		[v001, v101],
		[v001, v011],
		[v110, v111],
		[v101, v111],
		[v011, v111]
	]
	
	for edge in edges:
		add_edge_box(st, edge[0], edge[1], thickness, Color(1, 0, 0))
	
		# Create a material that uses vertex colors.
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	self.material_override = mat
	
	var new_mesh: Mesh = st.commit()
	outline_mesh.clear_surfaces()
	# Add the generated surface arrays to our outline mesh.
	outline_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_mesh.surface_get_arrays(0))

func clear_outline() -> void:
	outline_mesh.clear_surfaces()

# Adds a thin rectangular prism (a "box") along the edge from p0 to p1.
# The box has a square cross-section of side length t, centered on the edge.
func add_edge_box(st: SurfaceTool, p0: Vector3, p1: Vector3, t: float, col: Color) -> void:
	var d: Vector3 = p1 - p0
	@warning_ignore("shadowed_global_identifier")
	var len: float = d.length()
	if len == 0:
		return
	var d_norm: Vector3 = d / len
	# Choose an arbitrary vector not parallel to d_norm.
	var a: Vector3 = Vector3(0, 1, 0) if abs(d_norm.dot(Vector3(0, 1, 0))) < 0.99 else Vector3(1, 0, 0)
	var u: Vector3 = d_norm.cross(a).normalized() * (t / 2)
	var v: Vector3 = d_norm.cross(u).normalized() * (t / 2)
	
	# Compute 8 corners for the prism.
	var p0a: Vector3 = p0 + u + v
	var p0b: Vector3 = p0 + u - v
	var p0c: Vector3 = p0 - u - v
	var p0d: Vector3 = p0 - u + v
	var p1a: Vector3 = p1 + u + v
	var p1b: Vector3 = p1 + u - v
	var p1c: Vector3 = p1 - u - v
	var p1d: Vector3 = p1 - u + v
	
	# Front face (between p0a, p0b, p1b, p1a)
	add_quad(st, p0a, p0b, p1b, p1a, ((p1a - p0a).cross(p0b - p0a)).normalized(), col)
	# Back face (between p0d, p0c, p1c, p1d)
	add_quad(st, p0d, p0c, p1c, p1d, ((p1d - p0d).cross(p0c - p0d)).normalized(), col)
	# Top face (between p0a, p0d, p1d, p1a)
	add_quad(st, p0a, p0d, p1d, p1a, ((p1a - p0a).cross(p0d - p0a)).normalized(), col)
	# Bottom face (between p0b, p0c, p1c, p1b)
	add_quad(st, p0b, p0c, p1c, p1b, ((p1b - p0b).cross(p0c - p0b)).normalized(), col)
	# Left face (between p0d, p0c, p0b, p0a)
	add_quad(st, p0d, p0c, p0b, p0a, ((p0a - p0d).cross(p0c - p0d)).normalized(), col)
	# Right face (between p1a, p1b, p1c, p1d)
	add_quad(st, p1a, p1b, p1c, p1d, ((p1d - p1a).cross(p1b - p1a)).normalized(), col)

# Helper function to add a quad (two triangles) to the SurfaceTool.
# This function uses our global vertex_count to track indices.
func add_quad(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, normal: Vector3, col: Color) -> void:
	st.set_color(col)
	st.set_normal(normal)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(v0)
	vertex_count += 1
	
	st.set_color(col)
	st.set_normal(normal)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(v1)
	vertex_count += 1
	
	st.set_color(col)
	st.set_normal(normal)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(v2)
	vertex_count += 1
	
	st.set_color(col)
	st.set_normal(normal)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(v3)
	vertex_count += 1
	
	var base_index = vertex_count - 4
	st.add_index(base_index)
	st.add_index(base_index + 1)
	st.add_index(base_index + 2)
	
	st.add_index(base_index)
	st.add_index(base_index + 2)
	st.add_index(base_index + 3)
