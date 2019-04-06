extends Object

class_name Graph

var vertex_grid     : Array
var quads           : Array

var hash_tool       : HeightHash
var scale           : float

var world_width     : int   # The total width of the terrain
var world_breadth   : int   # The total breadth of the terrain
var height_grid     : Array # The fullset of height values across the grid

# Some fields used to track limits
# Set with some reasonable defaults and update later
var min_height      := -0.5
var max_height      := 1.6

var real_min_height := min_height
var real_max_height := max_height

var sea_level       := 0.0        # Magic number
var water_surfaces  := []

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


class Height:
	var height : float
	var grid_x : int
	var grid_z : int
	var parent : Graph
	
	var bed_rock_precision = 128.0 # Magic number

	var water_height   : float
	var water_body_ind : int
	var closed         : bool
	var levelled       : bool

	func _init(x : int, z : int, p : Graph):
		grid_x = x
		grid_z = z
		parent = p

		closed = false
		levelled = false

	func set_height(y : float):
		height = y
	
	func calc_start_water_height():
		# Water should be the min water height higher
		water_height = floor(max(parent.sea_level, self.height) * bed_rock_precision) / bed_rock_precision

	static func y_sort(a : Height, b : Height) -> bool:
		if a.height > b.height:
			return true
		elif a.height == b.height:
			if a.grid_z < b.grid_z:
				return true
			elif a.grid_z == b.grid_z:
				if a.grid_x < b.grid_x:
					return true
		return false

static func place_height_in_list(list : Array, h : Height):
	var h_ind := list.bsearch_custom(h, Height, "y_sort")
	list.insert(h_ind, h)
	h.closed = true

func setup_2d_Height_array(width : int, height : int, parent: Graph) -> Array:
	var rows := []
	for h in range(height):
		rows.append([])
		for w in range(width):
			rows[h].append(Height.new(w, h, parent))
	return rows

func setup_2d_Corner_array(width : int, height : int) -> Array:
	var rows := []
	for h in range(height):
		rows.append([])
		#warning-ignore:unused_variable
		for w in range(width):
			rows[h].append(Corner.new())
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
	height_grid = setup_2d_Height_array(world_width + 1, world_breadth + 1, self)
	var highest_edge = 0

	# This sucks a bit as it means calculating all the values at once
	# But we need the whole world to generate water heights
	for z in range(len(height_grid)):
		for x in range(len(height_grid[z])):
			var new_height = hash_tool.getHash(float((x - (world_width / 2.0)) * scale), float((z - (world_width / 2.0)) * scale))
			height_grid[z][x].set_height(new_height)
			real_min_height = min(real_min_height, new_height)
			real_max_height = max(real_max_height, new_height)
			if z <= 0 or x <= 0 or z >= len(height_grid) - 1 or x >= len(height_grid[z]) -1:
				highest_edge = max(highest_edge, new_height)
			
	# Use the highest edge tile as the min water level
	sea_level = highest_edge
	print ("sea_level: " + str(sea_level))
	
	priority_flood()

func set_height_features(x_h_grid : int, z_h_grid : int):
	for z in range(len(vertex_grid)):
		for x in range(len(vertex_grid[z])):
			var corner = height_grid[z_h_grid + z][x_h_grid + x]
			vertex_grid[z][x].set_y(corner.height)
			vertex_grid[z][x].set_water_height(corner.water_height)

func spread_surface_edges(surface : Array):
	var body_ind = surface.front().water_body_ind
	var water_height = surface.front().water_height
	# Spread the surface to the neighbouring points
	for h in surface:
		for n in get_grid_neighbours(h, true):
			if not n.water_body_ind and n.height < water_height:
				# Modify water height
				n.water_height = water_height
				# Append to the surface
				n.water_body_ind = body_ind
				surface.append(n)

func spread_surface_edges_into_terrain(surface : Array):
	var body_ind = surface.front().water_body_ind
	var water_height = surface.front().water_height
	var flood_height
	# Spread the surface to the neighbouring points
	var surf = surface.duplicate()
	for h in surf:
		for n in get_grid_neighbours(h):
			if not n.water_body_ind and n.height >= water_height:
				flood_height = min(flood_height, n.height) if flood_height else n.height
				# Append to the surface
				n.water_body_ind = body_ind
				surface.append(n)
	# Flood the whole surface (raise to the flood height)
	for h in surface:
		h.water_height = flood_height

func create_water_display_features(surface : Array, surfTool : SurfaceTool):
	# Find a rectangle that contains all the points in the surface
	var grid_bounds = Rect2(surface.front().grid_x, surface.front().grid_z, 0, 0)
	for h in surface:
		if h.grid_x < grid_bounds.position.x:
			grid_bounds.position.x = h.grid_x
		elif h.grid_x > grid_bounds.end.x:
			grid_bounds.end.x = h.grid_x
		if h.grid_z < grid_bounds.position.y:
			grid_bounds.position.y = h.grid_z
		elif h.grid_z > grid_bounds.end.y:
			grid_bounds.end.y = h.grid_z
	
	var water_level = surface.front().water_height - 0.5
	# Go through each possible quad within the surface bounds and draw all complete quads and partial tris
	for z in range(grid_bounds.position.y, grid_bounds.end.y):
		for x in range(grid_bounds.position.x, grid_bounds.end.x):
			var score = get_surface_occupancy_score(z, x, surface.front().water_body_ind)
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
	var score = 0
	# Assuming all surface features will have the same water height
	score += 1 if height_grid[z][x].water_body_ind == water_body_ind else 0
	score += 2 if height_grid[z][x + 1].water_body_ind == water_body_ind else 0
	score += 4 if height_grid[z + 1][x].water_body_ind == water_body_ind else 0
	score += 8 if height_grid[z + 1][x + 1].water_body_ind == water_body_ind else 0
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
	var a = Vector3(quad.position.x, water_level, quad.position.y)
	var b = Vector3(quad.end.x,      water_level, quad.position.y)
	var c = Vector3(quad.position.x, water_level, quad.end.y)
	var d = Vector3(quad.end.x,      water_level, quad.end.y)

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

func get_grid_neighbours(h : Height, diamond := false):
	var neighbours := []
	if h.grid_x > 0:
		neighbours.append(height_grid[h.grid_z][h.grid_x - 1])
		if not diamond and h.grid_z > 0:
			neighbours.append(height_grid[h.grid_z - 1][h.grid_x - 1])
		if not diamond and h.grid_z < len(height_grid) - 1:
			neighbours.append(height_grid[h.grid_z + 1][h.grid_x - 1])
	if h.grid_z > 0:
		neighbours.append(height_grid[h.grid_z - 1][h.grid_x])
	if h.grid_x < len(height_grid[0]) - 1:
		neighbours.append(height_grid[h.grid_z][h.grid_x + 1])
		if not diamond and h.grid_z > 0:
			neighbours.append(height_grid[h.grid_z - 1][h.grid_x + 1])
		if not diamond and h.grid_z < len(height_grid) - 1:
			neighbours.append(height_grid[h.grid_z + 1][h.grid_x + 1])
	if h.grid_z < len(height_grid) - 1:
		neighbours.append(height_grid[h.grid_z + 1][h.grid_x])
	return neighbours

func priority_flood():
	var queue := []
	var surface := []

	# Add all edge heights to queue
	for z in range(len(height_grid)):
		for x in range(len(height_grid[z])):
			if z <= 0 or x <= 0 or z >= len(height_grid) - 1 or x >= len(height_grid[z]) -1:
				height_grid[z][x].calc_start_water_height()
				place_height_in_list(queue, height_grid[z][x])
	
	# Take each queued point and process it
	while not queue.empty():
		var h : Height = queue.pop_back()
		# Set up the neighbours for processing
		for n in get_grid_neighbours(h, true):
			if n.closed: continue
			n.calc_start_water_height()
			n.water_height = max(h.water_height, n.water_height)
			place_height_in_list(queue, n)
		# If the current water height is higher than the terrain
		if h.water_height > h.height:
			# Add to the surface
			h.levelled = true
			surface.append(h)

	# Take each surface point and level out the water around it
	var h : Height = surface.pop_back()
	var next_ind := 0
	while h:
		if not h.water_body_ind:
			# If an adjoining point has an index, use that
			var adj_ind = get_and_merge_any_adjoining_index(h)
			if adj_ind:
				# Use existing index
				h.water_body_ind = adj_ind
				water_surfaces[adj_ind].append(h)
			else:
				# Create new index
				h.water_body_ind = next_ind
				water_surfaces.append([h])
				next_ind += 1
		
		h = surface.pop_back()

	print("surfaces before tidy: " + str(next_ind))
	tidy_empty_water_surfaces()
	print("surfaces after tidy: " + str(len(water_surfaces)))

func tidy_empty_water_surfaces():
	var new_water_surfaces := []
	var new_ind := 0
	# remove empty rows and re-align indices
	while not water_surfaces.empty():
		var surface = water_surfaces.pop_front()
		if not surface.empty():
			for h in surface:
				h.water_body_ind = new_ind
			new_water_surfaces.append(surface)
			new_ind += 1
	water_surfaces = new_water_surfaces

func get_and_merge_any_adjoining_index(h : Height):
	# Inspecific about return type as may be int or null
	var ind = null
	for n in get_grid_neighbours(h):
		if n.water_body_ind:
			if ind and n.water_body_ind != ind:
				# 2 body indexes have met, need to merge
				merge_surfaces(ind , n.water_body_ind)
			else:
				# We found an index (or the same index)
				ind = n.water_body_ind
	return ind

func merge_surfaces(invader_ind : int, annexed_ind : int):
	# 2 body indexes have met, need to merge
	for mover in water_surfaces[annexed_ind]:
		mover.water_body_ind = invader_ind
	water_surfaces[invader_ind] += water_surfaces[annexed_ind]
	water_surfaces[annexed_ind] = []

func generate_mesh(h_offset : Vector2) -> Mesh:

	set_height_features(int(h_offset.x), int(h_offset.y))
	
	var mesh := Mesh.new()
	
	# Draw the terrain base height map
	var surfTool := SurfaceTool.new()
	var color_scale := (2.0 / (max_height - min_height))
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
	var surf_step := 1.0 / len(water_surfaces)
	for surface in water_surfaces:
		var mesh := Mesh.new()
		var waterSurface := SurfaceTool.new()
		
		waterSurface.begin(Mesh.PRIMITIVE_TRIANGLES)
		waterSurface.add_color(Color(0.0, surf_step * surf_ind, 1.0, 0.25))
		
		spread_surface_edges(surface)
		spread_surface_edges_into_terrain(surface)
		create_water_display_features(surface, waterSurface)

		waterSurface.generate_normals()
		#warning-ignore:return_value_discarded
		waterSurface.commit(mesh)
		surf_ind += 1
		water_meshes.append(mesh)
	
	return water_meshes

func draw_terrain_quad(surfTool : SurfaceTool, quad : Quad, color_scale : float):
	
	# Split the quad along the 2 average highest opposite vertices
	var AD = abs(quad.A(vertex_grid).pos.y - quad.D(vertex_grid).pos.y)
	var BC = abs(quad.B(vertex_grid).pos.y - quad.C(vertex_grid).pos.y)

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
	var height = pos.y
	var red   = max(((height - min_height) * color_scale) - 1.0, 0.0)
	var green = min( (height - min_height) * color_scale, 1.0)
	var blue  = max(((height - min_height) * color_scale) - 1.0, 0.0)
	surfTool.add_color(Color(red, green, blue, 1.0))
	surfTool.add_vertex(pos)