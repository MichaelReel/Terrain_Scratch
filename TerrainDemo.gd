extends MeshInstance3D

#var Graph = load("res://Graph.gd")
#var HeightHash = load("res://HeightHash.gd")

var terrain_path := "TerrainDemo"
var save_dir     : DirAccess
var index        : Dictionary

@export var chunk_resolution: Vector2 = Vector2(32, 32) # The number of points across the grid
@export var chunks_grid: Vector2 = Vector2(8, 8)        # Size of the grid of chunks
@export var chunk_material: ShaderMaterial              # Material put onto the "land" chunks
@export var water_material: ShaderMaterial              # Material put onto the "land" chunks
@export var force_generation: bool = true               # Remove generated files and force creation
@export var generate_colliders: bool = false            # Set to add colliders for each chunk
@export var init_seed: int = 2                          # Seed for the terrain height
@export var marker: Mesh

var chunk_size := Vector3(1.0 / chunks_grid.x, 0.0, 1.0 / chunks_grid.y)
var total_grid := Vector2(chunk_resolution.x * chunks_grid.x, chunk_resolution.y * chunks_grid.y)
var graph      : BaseTerrain                            # Used to generate meshes

var thread : Thread

func _ready() -> void:
	thread = Thread.new()
	var _err = thread.start(Callable(self, "terrain_generation_or_loading"))

func _exit_tree():
	thread.wait_to_finish()

func terrain_generation_or_loading() -> void:
	print("preping storage " + str(Time.get_ticks_usec()))
	prepare_storage()
	print("loading index " + str(Time.get_ticks_usec()))
	load_index()
	if force_generation:
		print("forcing generation (removing files) " + str(Time.get_ticks_usec()))
		remove_all_files()
	print("updating the terrain " + str(Time.get_ticks_usec()))
	update_terrain()
	if generate_colliders:
		print("creating colliders " + str(Time.get_ticks_usec()))
		create_colliders()
	if not force_generation:
		print("saving chunks " + str(Time.get_ticks_usec()))
		save_chunks()
		print("saving index " + str(Time.get_ticks_usec()))
		save_index()

func prepare_storage():
	var save_dir_path = "user://" + terrain_path + "/"
	save_dir = DirAccess.new()
	if save_dir.file_exists(save_dir_path):
		print ("Found existing terrain directory")
		#warning-ignore:return_value_discarded
		var _err = save_dir.open(save_dir_path)
	else:
		print ("Making new terrain directory")
		#warning-ignore:return_value_discarded
		var _err = save_dir.make_dir_recursive(save_dir_path)
		#warning-ignore:return_value_discarded
		_err = save_dir.open(save_dir_path)

func remove_all_files():
	# This is more for debug than anything
	var dir = DirAccess.new()
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
		"Water": [],
	}

	# If file isn't there - no bother
	if !load_index.file_exists(index_file):
		return

	# File exists, try to load it
	load_index.open(index_file, File.READ)
	var test_json_conv = JSON.new()
	test_json_conv.parse(load_index.get_as_text())
	var result = test_json_conv.get_data()

	# If it can't be parsed - give up
	if result.error:
		print (result.error_string, ", ", index_file, ":", result.error_line)
		return

	index = result.result
	load_index.close()

	index["Loads"] += 1

func update_terrain():
	var shelf_limit = 11.0
	print("create base terrain graph " + str(Time.get_ticks_usec()))
	graph = BaseTerrain.new(HeightHash.new(shelf_limit, init_seed), 1.0 / shelf_limit, total_grid)
	index["HeightGrid"] = graph.height_grid
	print("create mesh terrain tool " + str(Time.get_ticks_usec()))
	var terrain_tool := MeshTerrainTool.new(chunk_resolution.x, chunk_resolution.y, chunk_size.x, chunk_size.z)
	var surface_tool = SurfaceTool.new()

	
	for z in range(chunks_grid.y):
		for x in range(chunks_grid.x):
			var chunk_name = str(x) + "_" + str(z)
			if index["Chunks"].has(chunk_name) and index["Chunks"][chunk_name].has("file"):
				surface_tool.clear()
				index["Chunks"][chunk_name]["data"] = load_chunk(chunk_name, surface_tool)
			else:
				index["Chunks"][chunk_name] = {}
				print("generating chunk (x:" + str(x) + " ,z:" + str(z) + ") " + str(Time.get_ticks_usec()))
				index["Chunks"][chunk_name]["data"] = generate_chunk(terrain_tool, x, z)
			print("adding chunk (x:" + str(x) + " ,z:" + str(z) + ") " + str(Time.get_ticks_usec()))
			add_child(index["Chunks"][chunk_name]["data"])
			
	
	# TODO: need to selectively load water meshes, assuming intention to keep chunking
	var water_tool := MeshWaterTool.new()
	print("generating water meshes")
	var surfaces := water_tool.generate_water_meshes(graph)
	for surface in surfaces:
		var pool = MeshInstance3D.new()
		pool.set_mesh(surface)
		pool.material_override = water_material
		index["Water"].append(pool)
		add_child(pool)
		
	# DEBUG: Add markers at all the peaks
	var marker_scale := Vector3(0.01, 0.05, 0.01) # TODO: make less magical
	print("marking peaks " + str(Time.get_ticks_usec()))
	for peak in graph.flow_grid.peaks:
		var offset = graph.get_global_position(peak.get_grid_vector2(), peak.height())
		var mark := MeshInstance3D.new()
		mark.set_mesh(marker)
		add_child(mark)
		mark.global_translate(offset)
		mark.scale_object_local(marker_scale)

	# DEBUG: Add markers at all the sinks
	print("marking sinks " + str(Time.get_ticks_usec()))
	for sink in graph.flow_grid.sinks:
		var offset = graph.get_global_position(sink.get_grid_vector2(), sink.height())
		var mark := MeshInstance3D.new()
		mark.set_mesh(marker)
		add_child(mark)
		mark.global_translate(offset)
		mark.scale_object_local(marker_scale)

	# DEBUG: Draw water link map
	print("drawing water links " + str(Time.get_ticks_usec()))
	for flow_mesh in water_tool.generate_complete_link_map(graph):
		var water_flow_map := MeshInstance3D.new()
		water_flow_map.set_mesh(flow_mesh)
		water_flow_map.material_override = chunk_material
		add_child(water_flow_map)
	

func generate_chunk(terrain_tool: MeshTerrainTool, x : int, z : int) -> MeshInstance3D:

	# Get position from generation offset
	var x_offset = x * chunk_size.x
	var z_offset = z * chunk_size.z
	var offset = Vector3(x_offset - 0.5, -0.5, z_offset - 0.5)
	var grid_offset = Vector2(x * chunk_resolution.x, z * chunk_resolution.y)

	# Create and return the chunk mesh
	var chunk = MeshInstance3D.new()
	chunk.set_mesh(terrain_tool.generate_mesh(grid_offset, graph))
	chunk.material_override = chunk_material
	chunk.position = offset
	return chunk

func create_colliders():

	for chunk_name in index["Chunks"].keys():
		var chunk = index["Chunks"][chunk_name]["data"]
		# Create collision layer
		# Annoyingly, this causes the mesh_surface_get_index_array error
		# Clearly, this needs to be created by more "manual" means
		chunk.create_trimesh_collision()
		
func load_chunk(chunk_name : String, surface_tool : SurfaceTool) -> MeshInstance3D:
	
	# Prepare mesh
	var chunk = MeshInstance3D.new()
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
	#warning-ignore:unused_variable
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
	#warning-ignore:unused_variable
	for face_ind in range(face_count):
		#warning-ignore:unused_variable
		for fv_ind in range(3):
			var vertex_ind = chunk_file.get_32()
			surface_tool.add_color(colors[vertex_ind])
			surface_tool.add_vertex(vertices[vertex_ind])
	surface_tool.generate_normals()

	#warning-ignore:return_value_discarded
	surface_tool.commit(mesh)
	chunk_file.close()
	chunk.set_mesh(mesh)
	chunk.material_override = chunk_material
	chunk.position = offset

	return chunk

func save_chunks():
	var mesh_data_tool = MeshDataTool.new()
	for chunk_name in index["Chunks"].keys():
		if not index["Chunks"][chunk_name].has("file"):
			mesh_data_tool.clear()
			save_chunk(chunk_name, mesh_data_tool)

func save_chunk(chunk_name : String, mesh_data_tool : MeshDataTool):
	var chunk = index["Chunks"][chunk_name]["data"]
	index["Chunks"][chunk_name].erase("data")

	# Prepare save file
	var chunk_file_path = save_dir.get_current_dir() + "/" + chunk_name + ".chunk"
	var chunk_file = File.new()
	chunk_file.open(chunk_file_path, File.WRITE)

	# Prepare to read mesh data
	#warning-ignore:return_value_discarded
	mesh_data_tool.create_from_surface(chunk.mesh, 0)

	# Store translation
	chunk_file.store_float(chunk.position.x)
	chunk_file.store_float(chunk.position.y)
	chunk_file.store_float(chunk.position.z)

	# Store vertices
	var vertex_count = mesh_data_tool.get_vertex_count()
	chunk_file.store_32(vertex_count)
	for vertex_ind in range(vertex_count):

		# Store vertex position
		var vertex = mesh_data_tool.get_vertex(vertex_ind)
		chunk_file.store_float(vertex.x)
		chunk_file.store_float(vertex.y)
		chunk_file.store_float(vertex.z)

		# Store vertex colour
		var color = mesh_data_tool.get_vertex_color(vertex_ind)
		chunk_file.store_float(color.r)
		chunk_file.store_float(color.g)
		chunk_file.store_float(color.b)
		chunk_file.store_float(color.a)

	# Store polygons
	var face_count = mesh_data_tool.get_face_count()
	chunk_file.store_32(face_count)
	for face_ind in range(face_count):
		for fv_ind in range(3):
			var vert_ind = mesh_data_tool.get_face_vertex(face_ind, fv_ind)
			chunk_file.store_32(vert_ind)
		
	chunk_file.close()
	index["Chunks"][chunk_name]["file"] = chunk_name + ".chunk"

func save_index():
	var index_file = save_dir.get_current_dir() + "/index.json"
	var save_index = File.new()
	save_index.open(index_file, File.WRITE)
	save_index.store_line(JSON.stringify(index,"    "))
	save_index.close()
