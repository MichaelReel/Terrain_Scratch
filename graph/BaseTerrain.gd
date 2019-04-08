extends Object

class_name BaseTerrain

var vertex_grid     : Array
var quads           : Array

var hash_tool       : HeightHash
var scale           : float

var world_width     : int   # The total width of the terrain
var world_breadth   : int   # The total breadth of the terrain
var height_grid     : BaseGrid
var water_grid      : WaterGrid

class Quad:
	var v1_x : int
	var v1_z : int
	var v2_x : int
	var v2_z : int

	func _init(vert1_x : int, vert1_z : int, vert2_x : int, vert2_z : int):
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
	
	func A(grid : Array):
		return grid[v1_z][v1_x]
		
	func B(grid : Array):
		return grid[v1_z][v2_x]
		
	func C(grid : Array):
		return grid[v2_z][v1_x]

	func D(grid : Array):
		return grid[v2_z][v2_x]

class Corner:
	var pos       : Vector3
	var water_pos : Vector3

	func _init():
		pos = Vector3()
		water_pos = Vector3()

	func set_xz(x : float, z : float):
		pos.x = x
		pos.z = z
		water_pos.x = x
		water_pos.z = z
	
	func set_y(y : float):
		pos.y = y
	
	func set_water_height(height : float):
		water_pos.y = height





func setup_2d_Corner_array(width : int, height : int) -> Array:
	var rows := []
	for h in range(height):
		rows.append([])
		#warning-ignore:unused_variable
		for w in range(width):
			(rows[h] as Array).append(Corner.new())
	return rows

func _init(ht : HeightHash, s : float, world_size : Vector2):
	quads         = []
	hash_tool     = ht
	scale         = s
	world_width   = int(world_size.x)
	world_breadth = int(world_size.y)

	generate_height_values()

func clear():
	vertex_grid.clear()
	quads.clear()

func create_base_square_grid(grid_width : int, grid_breadth : int, chunk_width : float, chunk_breadth : float):
	var dx := ( chunk_width / grid_width )
	var dz := ( chunk_breadth / grid_breadth )
	
	vertex_grid = setup_2d_Corner_array(grid_width + 1, grid_breadth + 1)

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

			quads.append(Quad.new(z, x, z + 1, x + 1))

func generate_height_values():
	height_grid = BaseGrid.new(world_width, world_breadth, scale)
	height_grid.generate_height_values(hash_tool)

	# Use the highest edge tile as the min water level
	var sea_level = height_grid.highest_edge
	print ("sea_level: " + str(sea_level))
	
	water_grid = WaterGrid.new(height_grid)
	water_grid.priority_flood(sea_level)

func set_height_features(x_h_grid : int, z_h_grid : int):
	for z in range(len(vertex_grid)):
		for x in range(len(vertex_grid[z])):
			var bh : BaseHeight  = height_grid.get_height(x_h_grid + x, z_h_grid + z)
			var wh : WaterHeight = water_grid.get_height(x_h_grid + x, z_h_grid + z)
			vertex_grid[z][x].set_y(bh.height)
			vertex_grid[z][x].set_water_height(wh.water_height)


func create_water_display_features(surface : Array, surfTool : SurfaceTool):
	# Find a rectangle that contains all the points in the surface
	var grid_bounds := Rect2(surface.front().base_height.grid_x, surface.front().base_height.grid_z, 0, 0)
	for wh in surface:
		if wh.base_height.grid_x < grid_bounds.position.x:
			grid_bounds.position.x = wh.base_height.grid_x
		elif wh.base_height.grid_x > grid_bounds.end.x:
			grid_bounds.end.x = wh.base_height.grid_x
		if wh.base_height.grid_z < grid_bounds.position.y:
			grid_bounds.position.y = wh.base_height.grid_z
		elif wh.base_height.grid_z > grid_bounds.end.y:
			grid_bounds.end.y = wh.base_height.grid_z
	
	var water_level : float = surface.front().water_height - 0.5
	# Go through each possible quad within the surface bounds and draw all complete quads and partial tris
	for z in range(grid_bounds.position.y, grid_bounds.end.y):
		for x in range(grid_bounds.position.x, grid_bounds.end.x):
			var score : int = get_surface_occupancy_score(z, x, surface.front().water_body_ind)
			# We only care about drawing 5 posible scores
			match score:
				15: # Full quad
					draw_level_quad(surfTool, get_world_bounds_from_grid_bounds(Rect2(x, z, 1, 1)), water_level)
				14: # B - D - C
					draw_tri(
						surfTool,
						get_level_vert(Vector2(x + 1, z), water_level),
						get_level_vert(Vector2(x + 1, z + 1), water_level),
						get_level_vert(Vector2(x, z + 1), water_level)
					)
				13: # A - D - C
					draw_tri(
						surfTool,
						get_level_vert(Vector2(x, z), water_level),
						get_level_vert(Vector2(x + 1, z + 1), water_level),
						get_level_vert(Vector2(x, z + 1), water_level)
					)
				11: # A - B - D
					draw_tri(
						surfTool,
						get_level_vert(Vector2(x, z), water_level),
						get_level_vert(Vector2(x + 1, z), water_level),
						get_level_vert(Vector2(x + 1, z + 1), water_level)
					)
				7: # A - B - C
					draw_tri(
						surfTool,
						get_level_vert(Vector2(x, z), water_level),
						get_level_vert(Vector2(x + 1, z), water_level),
						get_level_vert(Vector2(x, z + 1), water_level)
					)
			
func get_surface_occupancy_score(z : int, x : int, water_body_ind : int) -> int:
	var score : int = 0
	# Assuming all surface features will have the same water height
	score += 1 if water_grid.get_height(x    , z    ).water_body_ind == water_body_ind else 0
	score += 2 if water_grid.get_height(x + 1, z    ).water_body_ind == water_body_ind else 0
	score += 4 if water_grid.get_height(x    , z + 1).water_body_ind == water_body_ind else 0
	score += 8 if water_grid.get_height(x + 1, z + 1).water_body_ind == water_body_ind else 0
	return score

func get_world_bounds_from_grid_bounds(grid_bounds : Rect2) -> Rect2:
	return Rect2(
		(grid_bounds.position.x - (world_width / 2.0)) / world_width, 
		(grid_bounds.position.y - (world_width / 2.0)) / world_width, 
		grid_bounds.size.x / world_width,
		grid_bounds.size.y / world_width
	)

func get_level_vert(grid_position : Vector2, water_level : float) -> Vector3:
	return Vector3(
		(grid_position.x - (world_width / 2.0)) / world_width,
		water_level,
		(grid_position.y - (world_width / 2.0)) / world_width
	)

func draw_level_quad(surfTool : SurfaceTool, quad : Rect2, water_level : float):
	var a := Vector3(quad.position.x, water_level, quad.position.y)
	var b := Vector3(quad.end.x,      water_level, quad.position.y)
	var c := Vector3(quad.position.x, water_level, quad.end.y)
	var d := Vector3(quad.end.x,      water_level, quad.end.y)

	draw_tri(surfTool, a, b, d)
	draw_tri(surfTool, a, d, c)

func draw_tri(surfTool : SurfaceTool, v1 : Vector3, v2 : Vector3, v3 : Vector3):
	surfTool.add_vertex(v1)
	surfTool.add_vertex(v2)
	surfTool.add_vertex(v3)
	# Draw double sided
	surfTool.add_vertex(v1)
	surfTool.add_vertex(v3)
	surfTool.add_vertex(v2)

func generate_mesh(h_offset : Vector2) -> Mesh:

	set_height_features(int(h_offset.x), int(h_offset.y))
	
	var mesh := Mesh.new()
	
	# Draw the terrain base height map
	var surfTool := SurfaceTool.new()
	var color_scale : float = (2.0 / (height_grid.real_max_height - height_grid.real_min_height))
	surfTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for quad in quads:
		draw_terrain_quad(surfTool, quad, color_scale)
	
	surfTool.generate_normals()
	#warning-ignore:return_value_discarded
	surfTool.commit(mesh)
	
	return mesh

func generate_water_meshes() -> Array:
	# Create and draw the water surfaces
	var water_meshes := []
	
	# TODO: Need to determine which water surfaces are relevant and crop accordingly
	#       Alternatively, drop the whole chunking thing and just generate everything in one big lump, at least at this level
	
	var surf_ind := 0
	var surf_step := 1.0 / len(water_grid.water_surfaces)
	for surface in water_grid.water_surfaces:
		var mesh := Mesh.new()
		var waterSurface := SurfaceTool.new()
		
		waterSurface.begin(Mesh.PRIMITIVE_TRIANGLES)
		waterSurface.add_color(Color(0.0, surf_step * surf_ind, 1.0, 0.25))
		
		create_water_display_features(surface, waterSurface)

		waterSurface.generate_normals()
		#warning-ignore:return_value_discarded
		waterSurface.commit(mesh)
		surf_ind += 1
		water_meshes.append(mesh)
	
	return water_meshes

func draw_terrain_quad(surfTool : SurfaceTool, quad : Quad, color_scale : float):
	
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
	var red   := max(((height - height_grid.real_min_height) * color_scale) - 1.0, 0.0)
	var green := min( (height - height_grid.real_min_height) * color_scale, 1.0)
	var blue  := max(((height - height_grid.real_min_height) * color_scale) - 1.0, 0.0)
	surfTool.add_color(Color(red, green, blue, 1.0))
	surfTool.add_vertex(pos)