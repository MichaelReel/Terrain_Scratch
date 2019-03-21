extends MeshInstance

var Graph = load("res://Graph.gd")
var HeightHash = load("res://HeightHash.gd")

var terrain_path = "TerrainDemo"
var save_dir
var index

export (Vector2) var chunk_resolution = Vector2(32.0, 32.0) # The number of points across the grid
export (Vector2) var chunks_grid = Vector2(8, 8)            # Size of the grid of chunks
export (ShaderMaterial) var chunk_material                  # Material put onto the "land" chunks
export (bool) var force_generation = true                   # Remove generated files and force creation
export (bool) var generate_colliders = false                # Set to add colliders for each chunk

var chunk_size = Vector3(1.0 / chunks_grid.x, 0.0, 1.0 / chunks_grid.y)
var total_grid = Vector2(chunk_resolution.x * chunks_grid.x, chunk_resolution.y * chunks_grid.y)
var graph                                                   # Used to generate meshes


func _ready():
	prepare_storage()
	load_index()
	if force_generation:
		remove_all_files()
	update_terrain()
	if generate_colliders:
		create_colliders()
	if not force_generation:
		save_chunks()
		save_index()

func prepare_storage():
	var save_dir_path = "user://" + terrain_path + "/"
	save_dir = Directory.new()
	if save_dir.file_exists(save_dir_path):
		print ("Found existing terrain directory")
		save_dir.open(save_dir_path)
	else:
		print ("Making new terrain directory")
		save_dir.make_dir_recursive(save_dir_path)
		save_dir.open(save_dir_path)

func remove_all_files():
	# This is more for debug than anything
	var dir = Directory.new()
	dir.remove(save_dir.get_current_dir() + "/index.json")
	for chunk_name in index["Chunks"].keys():
		if index["Chunks"][chunk_name].has("file"):
			dir.remove(save_dir.get_current_dir() + "/" + index["Chunks"][chunk_name]["file"] )
			index["Chunks"][chunk_name].erase("file")

func load_index():
	var index_file = save_dir.get_current_dir() + "/index.json"
	var load_index = File.new()
	index = {
		"Chunks": {},
		"Loads": 0,
	}

	# If file isn't there - no bother
	if !load_index.file_exists(index_file):
		return

	# File exists, try to load it
	load_index.open(index_file, File.READ)
	var result = JSON.parse(load_index.get_as_text())

	# If it can't be parsed - give up
	if result.error:
		print (result.error_string, ", ", index_file, ":", result.error_line)
		return

	index = result.result
	load_index.close()

	index["Loads"] += 1

func update_terrain():
	var shelf_limit = 11.0
	graph = Graph.new(HeightHash.new(shelf_limit, 2), 1.0 / shelf_limit, total_grid)
	index["HeightGrid"] = graph.height_grid
	graph.create_base_square_grid(chunk_resolution.x, chunk_resolution.y, chunk_size.x, chunk_size.z)
	var surface_tool = SurfaceTool.new()

	for z in range(chunks_grid.y):
		for x in range(chunks_grid.x):
			var chunk_name = str(x) + "_" + str(z)
			if index["Chunks"].has(chunk_name) and index["Chunks"][chunk_name].has("file"):
				surface_tool.clear()
				index["Chunks"][chunk_name]["data"] = load_chunk(chunk_name, surface_tool)
			else:
				index["Chunks"][chunk_name] = {}
				index["Chunks"][chunk_name]["data"] = generate_chunk(x, z)
			add_child(index["Chunks"][chunk_name]["data"])
	
	# Some debug relating to shader ranges:
	var cmin = graph.min_height
	var cmax = graph.max_height
	var rmin = graph.real_min_height
	var rmax = graph.real_max_height
	if rmin < cmin:
		print ("real min height is: " + str(rmin) + ", current: " + str(cmin))
	if rmax > cmax:
		print ("real max height is: " + str(rmax) + ", current: " + str(cmax))

func generate_chunk(x, z):

	# Get position from generation offset
	var x_offset = x * chunk_size.x
	var z_offset = z * chunk_size.z
	var offset = Vector3(x_offset - 0.5, -0.5, z_offset - 0.5)
	var grid_offset = Vector2(x * chunk_resolution.x, z * chunk_resolution.y)

	# Create and return the chunk mesh
	var chunk = MeshInstance.new()
	chunk.set_mesh(graph.generate_mesh(grid_offset))
	chunk.material_override = chunk_material
	chunk.translation = offset
	return chunk

func create_colliders():

	for chunk_name in index["Chunks"].keys():
		var chunk = index["Chunks"][chunk_name]["data"]
		# Create collision layer
		# Annoyingly, this causes the mesh_surface_get_index_array error
		# Clearly, this needs to be created by more "manual" means
		chunk.create_trimesh_collision()
		
func load_chunk(chunk_name, surface_tool):
	
	# Prepare mesh
	var chunk = MeshInstance.new()
	var mesh = Mesh.new()

	# Prepare load file
	var chunk_file_path = save_dir.get_current_dir() + "/" + index["Chunks"][chunk_name]["file"]
	var chunk_file = File.new()
	chunk_file.open(chunk_file_path, File.READ)

	# Load translation
	var offset = Vector3()
	offset.x = chunk_file.get_float()
	offset.y = chunk_file.get_float()
	offset.z = chunk_file.get_float()

	# Load vertices
	var vertices = []
	var colors = []
	var vertex_count = chunk_file.get_32()
	for vertex_ind in range(vertex_count):
		# Load vertex position
		var vertex = Vector3()
		vertex.x = chunk_file.get_float()
		vertex.y = chunk_file.get_float()
		vertex.z = chunk_file.get_float()
		vertices.append(vertex)

		# Load vertex colour
		var color = Color()
		color.r = chunk_file.get_float()
		color.g = chunk_file.get_float()
		color.b = chunk_file.get_float()
		color.a = chunk_file.get_float()
		colors.append(color)
	
	# Load polygons
	var face_count = chunk_file.get_32()

	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face_ind in range(face_count):
		for fv_ind in range(3):
			var vertex_ind = chunk_file.get_32()
			surface_tool.add_color(colors[vertex_ind])
			surface_tool.add_vertex(vertices[vertex_ind])
	surface_tool.generate_normals()

	surface_tool.commit(mesh)
	chunk_file.close()
	chunk.set_mesh(mesh)
	chunk.material_override = chunk_material
	chunk.translation = offset

	return chunk

func save_chunks():
	var mesh_tool = MeshDataTool.new()
	for chunk_name in index["Chunks"].keys():
		if not index["Chunks"][chunk_name].has("file"):
			mesh_tool.clear()
			save_chunk(chunk_name, mesh_tool)

func save_chunk(chunk_name, mesh_tool):
	var chunk = index["Chunks"][chunk_name]["data"]
	index["Chunks"][chunk_name].erase("data")

	# Prepare save file
	var chunk_file_path = save_dir.get_current_dir() + "/" + chunk_name + ".chunk"
	var chunk_file = File.new()
	chunk_file.open(chunk_file_path, File.WRITE)

	# Prepare to read mesh data
	mesh_tool.create_from_surface(chunk.mesh, 0)

	# Store translation
	chunk_file.store_float(chunk.translation.x)
	chunk_file.store_float(chunk.translation.y)
	chunk_file.store_float(chunk.translation.z)

	# Store vertices
	var vertex_count = mesh_tool.get_vertex_count()
	chunk_file.store_32(vertex_count)
	for vertex_ind in range(vertex_count):

		# Store vertex position
		var vertex = mesh_tool.get_vertex(vertex_ind)
		chunk_file.store_float(vertex.x)
		chunk_file.store_float(vertex.y)
		chunk_file.store_float(vertex.z)

		# Store vertex colour
		var color = mesh_tool.get_vertex_color(vertex_ind)
		chunk_file.store_float(color.r)
		chunk_file.store_float(color.g)
		chunk_file.store_float(color.b)
		chunk_file.store_float(color.a)

	# Store polygons
	var face_count = mesh_tool.get_face_count()
	chunk_file.store_32(face_count)
	for face_ind in range(face_count):
		for fv_ind in range(3):
			var vert_ind = mesh_tool.get_face_vertex(face_ind, fv_ind)
			chunk_file.store_32(vert_ind)
		
	chunk_file.close()
	index["Chunks"][chunk_name]["file"] = chunk_name + ".chunk"

func save_index():
	var index_file = save_dir.get_current_dir() + "/index.json"
	var save_index = File.new()
	save_index.open(index_file, File.WRITE)
	save_index.store_line(JSON.print(index,"    "))
	save_index.close()