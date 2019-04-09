extends Node

class_name MeshTerrainTool
"Re-usable tool for creating meshes from a larger terrain data set"

var vertex_grid : Array
var quads       : Array
var min_height  : float

func _init(grid_width : int, grid_breadth : int, chunk_width : float, chunk_breadth : float):
	"Create mesh terrain tool, use set_height_features to reset for each chunk"
	
	var dx := ( chunk_width / grid_width )
	var dz := ( chunk_breadth / grid_breadth )
	
	vertex_grid = setup_2d_Corner_array(grid_width + 1, grid_breadth + 1)
	quads = []

	for z in range(grid_breadth):
		for x in range(grid_width):
			var sx := x * dx
			var sz := z * dz
			var ex := (x + 1) * dx
			var ez := (z + 1) * dz

			#      sx     ex
			#       '     '
			#  sz-  A-----B
			#       | \   |
			#       |   \ |
			#  ez-  C-----D

			vertex_grid[z    ][x    ].set_xz(sx, sz) # A
			vertex_grid[z    ][x + 1].set_xz(ex, sz) # B
			vertex_grid[z + 1][x    ].set_xz(sx, ez) # C
			vertex_grid[z + 1][x + 1].set_xz(ex, ez) # D

			quads.append(MeshQuad.new(z, x, z + 1, x + 1))

func set_height_features(x_h_grid : int, z_h_grid : int, terrain : BaseTerrain):
	"Set the height features from the terrain for the chunk at x_h_grid, z_h_grid"
	
	for z in range(len(vertex_grid)):
		for x in range(len(vertex_grid[z])):
			var bh : BaseHeight  = terrain.height_grid.get_height(x_h_grid + x, z_h_grid + z)
			var wh : WaterHeight = terrain.water_grid.get_height(x_h_grid + x, z_h_grid + z)
			vertex_grid[z][x].set_y(bh.height)
			vertex_grid[z][x].set_water_height(wh.water_height)

	min_height = terrain.height_grid.real_min_height

func generate_mesh(h_offset : Vector2, terrain : BaseTerrain) -> Mesh:

	set_height_features(int(h_offset.x), int(h_offset.y), terrain)
	
	var mesh := Mesh.new()
	
	# Draw the terrain base height map
	var surfTool := SurfaceTool.new()
	var color_scale : float = (2.0 / (terrain.height_grid.real_max_height - terrain.height_grid.real_min_height))
	surfTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for quad in quads:
		draw_terrain_quad(surfTool, quad, color_scale)
	
	surfTool.generate_normals()
	#warning-ignore:return_value_discarded
	surfTool.commit(mesh)
	
	return mesh

func draw_terrain_quad(surfTool : SurfaceTool, quad : MeshQuad, color_scale : float):
	
	# Split the quad along the 2 average highest opposite vertices
	var AD := abs(quad.A(vertex_grid).pos.y - quad.D(vertex_grid).pos.y)
	var BC := abs(quad.B(vertex_grid).pos.y - quad.C(vertex_grid).pos.y)

	if AD > BC:

		# A-----B
		# | \   |
		# |   \ |
		# C-----D

		add_coloured_vertex(surfTool, quad.A(vertex_grid).pos, color_scale)
		add_coloured_vertex(surfTool, quad.B(vertex_grid).pos, color_scale)
		add_coloured_vertex(surfTool, quad.D(vertex_grid).pos, color_scale)

		add_coloured_vertex(surfTool, quad.A(vertex_grid).pos, color_scale)
		add_coloured_vertex(surfTool, quad.D(vertex_grid).pos, color_scale)
		add_coloured_vertex(surfTool, quad.C(vertex_grid).pos, color_scale)
	
	else:

		# A-----B
		# |   / |
		# | /   |
		# C-----D

		add_coloured_vertex(surfTool, quad.A(vertex_grid).pos, color_scale)
		add_coloured_vertex(surfTool, quad.B(vertex_grid).pos, color_scale)
		add_coloured_vertex(surfTool, quad.C(vertex_grid).pos, color_scale)

		add_coloured_vertex(surfTool, quad.B(vertex_grid).pos, color_scale)
		add_coloured_vertex(surfTool, quad.D(vertex_grid).pos, color_scale)
		add_coloured_vertex(surfTool, quad.C(vertex_grid).pos, color_scale)

func add_coloured_vertex(surfTool : SurfaceTool, pos : Vector3, color_scale : float):
	var height := pos.y
	var red   := max(((height - min_height) * color_scale) - 1.0, 0.0)
	var green := min( (height - min_height) * color_scale, 1.0)
	var blue  := max(((height - min_height) * color_scale) - 1.0, 0.0)
	surfTool.add_color(Color(red, green, blue, 1.0))
	surfTool.add_vertex(pos)

static func setup_2d_Corner_array(width : int, height : int) -> Array:
	var rows := []
	for h in range(height):
		rows.append([])
		#warning-ignore:unused_variable
		for w in range(width):
			(rows[h] as Array).append(MeshCorner.new())
	return rows