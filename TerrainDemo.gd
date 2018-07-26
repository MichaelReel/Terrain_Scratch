extends MeshInstance

var Chunk = load("res://Land.gd")
var Graph = load("res://Graph.gd")
var HeightHash = load("res://HeightHash.gd")

var terrain_path = "TerrainDemo"
var save_dir
var index

export (Vector2) var chunk_resolution = Vector2(16.0, 16.0) # The number of points across the grid
export (Vector2) var chunks_grid = Vector2(16, 16)          # Size of the grid of chunks
export (ShaderMaterial) var chunk_material

var chunk_size = Vector3(1.0 / chunks_grid.x, 0.0, 1.0 / chunks_grid.y)

func _ready():
	prepare_storage()
	load_index()
	update_terrain()
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

func load_index():
	var index_file = save_dir.get_current_dir() + "/index.json"
	var load_index = File.new()
	index = {}

	# If file isn't there - no bother
	if !load_index.file_exists(index_file):
		index["Loads"] = 0
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

	if not index.has("Loads"):
		index["Loads"] = 0
	else:
		index["Loads"] += 1

func update_terrain():
	var shelf_limit = 21.0
	var graph = Graph.new(HeightHash.new(shelf_limit), 2 * shelf_limit)
	graph.create_base_square_grid(chunk_resolution.x, chunk_resolution.y, chunk_size.x, chunk_size.z)

	for z in range(chunks_grid.y):
		for x in range(chunks_grid.x):
			var x_offset = x * chunk_size.x
			var z_offset = z * chunk_size.z
			var offset = Vector3(x_offset - 0.5, -0.5, z_offset - 0.5)
			# graph.set_height_features(x_offset, z_offset)
			
			var chunk = Chunk.new(offset, graph)
			chunk.material_override = chunk_material
			chunk.generate_content()
			chunk.translation = offset
			add_child(chunk)

func save_index():
	var index_file = save_dir.get_current_dir() + "/index.json"
	var save_index = File.new()
	save_index.open(index_file, File.WRITE)
	save_index.store_line(JSON.print(index,"    "))
	save_index.close()