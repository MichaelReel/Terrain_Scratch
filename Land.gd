extends MeshInstance

var Graph = load("res://Graph.gd")

var graph
var offset

const render_options = [
	Mesh.PRIMITIVE_POINTS,
	Mesh.PRIMITIVE_LINES,
	Mesh.PRIMITIVE_TRIANGLES,
]

var render_as = 2

func _init(os, communal_graph = null):
	self.offset = os

	if communal_graph:
		graph = communal_graph
	else:
		graph = Graph.new()

func generate_content(with_collision = true):
	# print ("Creating new land chunk: " + str(offset) + " with grid: " + str(grid_size) + ",")
	# print ("            translation: " + str(translation) + ", scale: " + str(scale))
	# print ("                os time: " + str(OS.get_unix_time()))


	# Update the input graph to give variable heights
	add_base_height_features(offset)

	# Creating drawing elements
	# Create a mesh from the voronoi site info
	self.set_mesh(create_mesh())

	if with_collision:
		# Make a collsion surface from this mesh and add it to the scene
		add_child(create_trimesh_collision())

	# print ("Content generated: " + str(offset))
	# print ("          os time: " + str(OS.get_unix_time()))

func add_base_height_features(offset):

	graph.set_height_features(offset.x, offset.z)

func create_mesh():
	if not graph:
		print("No input or no surface tool supplied!")
		return
	
	# Create a new mesh
	var mesh = Mesh.new()
	var surfTool = SurfaceTool.new()

	match render_options[render_as]:
		Mesh.PRIMITIVE_POINTS:
			surfTool.begin(Mesh.PRIMITIVE_POINTS)
			surfTool.add_color(Color(1.0, 1.0, 1.0, 1.0))
			for vert in graph.vertices:
				surfTool.add_vertex(vert.pos)
				surfTool.add_index(vert.index)

		Mesh.PRIMITIVE_LINES:
			surfTool.begin(Mesh.PRIMITIVE_LINES)
			surfTool.add_color(Color(1.0, 1.0, 1.0, 1.0))
			for vert in graph.vertices:
				surfTool.add_vertex(vert.pos)
			for edge in graph.edges:
				surfTool.add_index(edge.v1.index)
				surfTool.add_index(edge.v2.index)

		Mesh.PRIMITIVE_TRIANGLES:
			# Recalculate the colour scale
			var color_scale = (2.0 / (graph.max_height - graph.min_height))
			
			surfTool.begin(Mesh.PRIMITIVE_TRIANGLES)
			for tri in graph.triangles:
				add_coloured_vertex(surfTool, tri.v1.pos, color_scale)
				add_coloured_vertex(surfTool, tri.v3.pos, color_scale)
				add_coloured_vertex(surfTool, tri.v2.pos, color_scale)
			
			# surfTool.index()
			surfTool.generate_normals()

		_:
			print("Unsupported render type!")

	# Create mesh with SurfaceTool
	surfTool.commit(mesh)
	return mesh

func add_coloured_vertex(surfTool, pos, color_scale):
	var height = pos.y
	var red = max(((height - graph.min_height) * color_scale) - 1.0, 0.0)
	var green = min((height - graph.min_height) * color_scale, 1.0)
	var blue = max(((height - graph.min_height) * color_scale) - 1.0, 0.0)
	surfTool.add_color(Color(red, green, blue, 1.0))
	surfTool.add_vertex(pos)