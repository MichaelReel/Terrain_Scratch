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

var sea_level = 0.0        # Magic number
var water_surfaces = []

class Quad:
	var v1_x
	var v1_z
	var v2_x
	var v2_z
	
	var water_level

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
		return grid[v1_z][v1_x]
		
	func B(grid):
		return grid[v1_z][v2_x]
		
	func C(grid):
		return grid[v2_z][v1_x]

	func D(grid):
		return grid[v2_z][v2_x]

class Corner:
	var pos
	var water_pos

	func _init():
		pos = Vector3()
		water_pos = Vector3()

	func set_xz(x, z):
		pos.x = x
		pos.z = z
		water_pos.x = x
		water_pos.z = z
	
	func set_y(y):
		pos.y = y
	
	func set_water_height(height):
		water_pos.y = height


class Height:
	var height
	var grid_x
	var grid_z
	var parent
	
	var bed_rock_precision = 64 # Magic number

	var water_height
	var water_body_ind
	var closed
	var levelled

	func _init(x, z, p):
		grid_x = x
		grid_z = z
		parent = p

		closed = false
		levelled = false

	func set_height(y):
		height = y
	
	func calc_start_water_height():
		# Water should be the min water height higher
		water_height = floor(max(parent.sea_level, self.height) * bed_rock_precision) / bed_rock_precision

	static func y_sort(a, b):
		if a.height > b.height:
			return true
		elif a.height == b.height:
			if a.grid_z < b.grid_z:
				return true
			elif a.grid_z == b.grid_z:
				if a.grid_x < b.grid_x:
					return
		return false

static func place_height_in_list(list, h):
	var h_ind = list.bsearch_custom(h, Height, "y_sort")
	list.insert(h_ind, h)
	h.closed = true

# Utility function, could maybe be libraried off
func setup_2d_Height_array(width, height):
	var rows = []
	for h in range(height):
		rows.append([])
		for w in range(width):
			rows[h].append(Height.new(w, h, self))
	return rows

# Utility function, could maybe be libraried off
func setup_2d_Corner_array(width, height):
	var rows = []
	for h in range(height):
		rows.append([])
		#warning-ignore:unused_variable
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
	var highest_edge = 0

	# This sucks a bit as it means calculating all the values at once
	# But we need the whole world to generate water heights
	for z in range(len(height_grid)):
		for x in range(len(height_grid[z])):
			var new_height = hash_tool.getHash(float((x - (world_width / 2)) * scale), float((z - (world_width / 2)) * scale))
			height_grid[z][x].set_height(new_height)
			real_min_height = min(real_min_height, new_height)
			real_max_height = max(real_max_height, new_height)
			if z <= 0 or x <= 0 or z >= len(height_grid) - 1 or x >= len(height_grid[z]) -1:
				highest_edge = max(highest_edge, new_height)
			
	# Use the highest edge tile as the min water level
	sea_level = highest_edge
	print ("sea_level: " + str(sea_level))
	
	priority_flood()

func set_height_features(x_h_grid, z_h_grid):

	for z in range(len(vertex_grid)):
		for x in range(len(vertex_grid[z])):
			var corner = height_grid[z_h_grid + z][x_h_grid + x]
			vertex_grid[z][x].set_y(corner.height)
			vertex_grid[z][x].set_water_height(corner.water_height)

	# Set grid cell water heights for grids that are water level
	for quad in quads:
		quad.water_level = null
		var is_level = true
		# water levels must all be equal
		var water_height = quad.A(vertex_grid).water_pos.y
		for corner in [quad.B(vertex_grid), quad.C(vertex_grid), quad.D(vertex_grid)]:
			if water_height != corner.water_pos.y :
				is_level = false
		if not is_level:
			continue
		var terrain_lower = false
		# one corner must be lower that the water level
		for corner in [quad.A(vertex_grid), quad.B(vertex_grid), quad.C(vertex_grid), quad.D(vertex_grid)]:
			if water_height > corner.pos.y:
				terrain_lower = true
		if terrain_lower:
			quad.water_level = water_height

func get_grid_neighbours(h, diamond = false):
	var neighbours = []
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
	var queue = []
	var surface = []

	# Add all edge heights to queue
	for z in range(len(height_grid)):
		for x in range(len(height_grid[z])):
			if z <= 0 or x <= 0 or z >= len(height_grid) - 1 or x >= len(height_grid[z]) -1:
				height_grid[z][x].calc_start_water_height()
				place_height_in_list(queue, height_grid[z][x])
	
	# Take each queued point and process it
	while not queue.empty():
		var h = queue.pop_back()
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
	var h = surface.pop_back()
	var next_ind = 0
	while h:
		if not h.water_body_ind:
			# If an adjoining point has an index, use that
			var adj_ind = get_any_adjoining_index(h)
			if adj_ind:
				# Use existing index
				h.water_body_ind = adj_ind
				water_surfaces[adj_ind].append(h)
			else:
				# Create new index
				h.water_body_ind = next_ind
				water_surfaces.append([h])
				next_ind += 1
				
		
		spread_surface_edges_into_terrain(surface, h)
		h = surface.pop_back()

	print("next_ind: " + str(next_ind))
	tidy_empty_water_surfaces()
	
	print("surfaces merged: " + str(len(water_surfaces)))

func tidy_empty_water_surfaces():
	var new_water_surfaces = []
	var new_ind = 0
	# remove empty rows and re-align indices
	while not water_surfaces.empty():
		var surface = water_surfaces.pop_front()
		if not surface.empty():
			for h in surface:
				h.water_body_ind = new_ind
			new_water_surfaces.append(surface)
			new_ind += 1
	water_surfaces = new_water_surfaces

func get_any_adjoining_index(h):
	var ind = null
	for n in get_grid_neighbours(h):
		if n.water_body_ind:
			if ind and n.water_body_ind != ind:
				# 2 body indexes have met, need to merge
				var moving_ind = n.water_body_ind
				# print ("merging: " + str(ind) + ", " + str(moving_ind))
				for mover in water_surfaces[moving_ind]:
					mover.water_body_ind = ind
				water_surfaces[ind] += water_surfaces[moving_ind]
				water_surfaces[moving_ind] = []
			else:
				# We found an index (or the same index)
				ind = n.water_body_ind
	return ind

func spread_surface_edges_into_terrain(surface, h):
	# Spread the surface to the neighbouring points
	for n in get_grid_neighbours(h):
		if n.water_height > h.water_height:
			n.water_height = h.water_height
			# TODO: setting the index should maybe be internal to the height class
			n.water_body_ind = h.water_body_ind
			water_surfaces[h.water_body_ind].append(n)
		if not n.levelled and n.water_height > n.height:
			n.levelled = true
			surface.push_back(n)

func generate_mesh(h_offset):

	set_height_features(h_offset.x, h_offset.y)

	var mesh = Mesh.new()
	var surfTool = SurfaceTool.new()
	var waterSurface = SurfaceTool.new()

	var color_scale = (2.0 / (max_height - min_height))

	surfTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	waterSurface.begin(Mesh.PRIMITIVE_TRIANGLES)
	waterSurface.add_color(Color(0.0, 0.0, 1.0, 0.25))

	for quad in quads:
		draw_terrain_quad(surfTool, quad, color_scale)
		draw_water_quad(waterSurface, quad)

	surfTool.generate_normals()
	surfTool.commit(mesh)

	waterSurface.generate_normals()
	waterSurface.commit(mesh)

	return mesh

func draw_terrain_quad(surfTool, quad, color_scale):
	
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

func draw_water_quad(surfTool, quad):
	# If ABCD water levels are over-terrain and the same height:
	if quad.water_level:
		
		surfTool.add_vertex(quad.A(vertex_grid).water_pos)
		surfTool.add_vertex(quad.B(vertex_grid).water_pos)
		surfTool.add_vertex(quad.D(vertex_grid).water_pos)

		surfTool.add_vertex(quad.A(vertex_grid).water_pos)
		surfTool.add_vertex(quad.D(vertex_grid).water_pos)
		surfTool.add_vertex(quad.C(vertex_grid).water_pos)

func add_coloured_vertex(surfTool, pos, color_scale):
	var height = pos.y
	var red   = max(((height - min_height) * color_scale) - 1.0, 0.0)
	var green = min( (height - min_height) * color_scale, 1.0)
	var blue  = max(((height - min_height) * color_scale) - 1.0, 0.0)
	surfTool.add_color(Color(red, green, blue, 1.0))
	surfTool.add_vertex(pos)