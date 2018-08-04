extends Object

var vertex_grid
var quads

var hash_tool
var scale

var world_width   # The total width of the terrain
var world_breadth # The total breadth of the terrain
var height_grid   # The fullset of height values across the grid

# Some fields used to track limits
# Set with some reasonable defaults and update later
var min_height = -0.5
var max_height = 1.6

var real_min_height = min_height
var real_max_height = max_height

class Quad:
	var v1_x
	var v1_z
	var v2_x
	var v2_z

	func _init(vert1_x, vert1_z, vert2_x, vert2_z):
		v1_x = vert1_x
		v1_z = vert1_z
		v2_x = vert2_x
		v2_z = vert2_z
	
	#      v1_x  v2_x
	#        '     '
	# v1_z-  A-----B
	#        | \   |
	#        |   \ |
	# v2_z-  C-----D
	
	func A(grid):
		return grid[v1_z][v1_x].pos
		
	func B(grid):
		return grid[v1_z][v2_x].pos
		
	func C(grid):
		return grid[v2_z][v1_x].pos

	func D(grid):
		return grid[v2_z][v2_x].pos

class Corner:
	var pos

	func _init():
		pos = Vector3()

	func set_xz(x, z):
		pos.x = x
		pos.z = z
	
	func set_y(y):
		pos.y = y

class Height:
	var height
	var grid_x
	var grid_z

	func _init(x, z):
		grid_x = x
		grid_z = z

	func set_height(y):
		height = y

# Utility function, could maybe be libraried off
func setup_2d_Height_array(width, height):
	var rows = []
	for h in range(height):
		rows.append([])
		for w in range(width):
			rows[h].append(Height.new(w,h))
	return rows

# Utility function, could maybe be libraried off
func setup_2d_Corner_array(width, height):
	var rows = []
	for h in range(height):
		rows.append([])
		for w in range(width):
			rows[h].append(Corner.new())
	return rows

func _init(ht, s, world_size):
	quads         = []
	hash_tool     = ht
	scale         = s
	world_width   = world_size.x
	world_breadth = world_size.y

	generate_height_values()

func clear():
	vertex_grid.clear()
	quads.clear()

func create_base_square_grid(grid_width, grid_breadth, chunk_width, chunk_breadth):
	var dx = ( chunk_width / grid_width )
	var dz = ( chunk_breadth / grid_breadth )
	
	vertex_grid = setup_2d_Corner_array(grid_width + 1, grid_breadth + 1)

	for z in range(grid_breadth):
		for x in range(grid_width):
			var sx = x * dx
			var sz = z * dz
			var ex = (x + 1) * dx
			var ez = (z + 1) * dz

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

			quads.append(Quad.new(z, x, z + 1, x + 1))

func generate_height_values():
	height_grid = setup_2d_Height_array(world_width + 1, world_breadth + 1)

	# This sucks a bit as it means calculating all the values at once
	# But we need the whole world to generate water heights
	for z in range(len(height_grid)):
		for x in range(len(height_grid[z])):
			var new_height = hash_tool.getHash(float((x - (world_width / 2)) * scale), float((z - (world_width / 2)) * scale))
			height_grid[z][x].set_height(new_height)
			real_min_height = min(real_min_height, new_height)
			real_max_height = max(real_max_height, new_height)

func set_height_features(x_offset, z_offset, x_h_grid, z_h_grid):

	for z in range(len(vertex_grid)):
		for x in range(len(vertex_grid[z])):
			var new_height = height_grid[z_h_grid + z][x_h_grid + x].height
			vertex_grid[z][x].set_y(new_height)

func generate_mesh(offset, h_offset):

	set_height_features(offset.x, offset.z, h_offset.x, h_offset.y)

	var mesh = Mesh.new()
	var surfTool = SurfaceTool.new()

	var color_scale = (2.0 / (max_height - min_height))

	surfTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# A-----B
	# | \   |
	# |   \ |
	# C-----D

	for quad in quads:
		add_coloured_vertex(surfTool, quad.A(vertex_grid), color_scale)
		add_coloured_vertex(surfTool, quad.B(vertex_grid), color_scale)
		add_coloured_vertex(surfTool, quad.D(vertex_grid), color_scale)
		
		add_coloured_vertex(surfTool, quad.A(vertex_grid), color_scale)
		add_coloured_vertex(surfTool, quad.D(vertex_grid), color_scale)
		add_coloured_vertex(surfTool, quad.C(vertex_grid), color_scale)

	surfTool.generate_normals()
	surfTool.commit(mesh)
	return mesh

func add_coloured_vertex(surfTool, pos, color_scale):
	var height = pos.y
	var red   = max(((height - min_height) * color_scale) - 1.0, 0.0)
	var green = min( (height - min_height) * color_scale, 1.0)
	var blue  = max(((height - min_height) * color_scale) - 1.0, 0.0)
	surfTool.add_color(Color(red, green, blue, 1.0))
	surfTool.add_vertex(pos)