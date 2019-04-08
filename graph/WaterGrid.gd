extends Node

class_name WaterGrid

var base_grid       : BaseGrid
var water_grid      : Array # The fullset of height values across the grid
var water_surfaces  := []   # Each 'body' of water after flooding algorithm completed

func _init(bg : BaseGrid):
	base_grid = bg
	water_grid = setup_2d_water_array(base_grid.world_width + 1, base_grid.world_breadth + 1)

func get_height(x : int, z : int) -> WaterHeight:
	return (water_grid[z][x] as WaterHeight)

func setup_2d_water_array(width : int, breadth : int) -> Array:
	var rows := []
	for z in range(breadth):
		rows.append([])
		for x in range(width):
			(rows[z] as Array).append(WaterHeight.new(base_grid.get_height(x, z)))
	return rows

func get_grid_neighbours(wh : WaterHeight, diamond := false):
	var neighbours := []
	var z = wh.base_height.grid_z
	var x = wh.base_height.grid_x
	if x > 0:
		neighbours.append(water_grid[z][x - 1])
		if not diamond and z > 0:
			neighbours.append(water_grid[z - 1][x - 1])
		if not diamond and z < len(water_grid) - 1:
			neighbours.append(water_grid[z + 1][x - 1])
	if z > 0:
		neighbours.append(water_grid[z - 1][x])
	if x < len(water_grid[0]) - 1:
		neighbours.append(water_grid[z][x + 1])
		if not diamond and z > 0:
			neighbours.append(water_grid[z - 1][x + 1])
		if not diamond and z < len(water_grid) - 1:
			neighbours.append(water_grid[z + 1][x + 1])
	if z < len(water_grid) - 1:
		neighbours.append(water_grid[z + 1][x])
	return neighbours

func priority_flood(min_sea_level):
	var queue := []
	var surface := []

	# Add all edge heights to queue
	for z in range(len(water_grid)):
		for x in range(len(water_grid[z])):
			if z <= 0 or x <= 0 or z >= len(water_grid) - 1 or x >= len(water_grid[z]) -1:
				water_grid[z][x].calc_start_water_height(min_sea_level)
				water_grid[z][x].place_height_in_list(queue)
	
	# Take each queued point and process it
	while not queue.empty():
		var wh : WaterHeight = queue.pop_back()
		# Set up the neighbours for processing
		for n in get_grid_neighbours(wh, true):
			if n.closed: continue
			n.calc_start_water_height(min_sea_level)
			n.water_height = max(wh.water_height, n.water_height)
			n.place_height_in_list(queue)
		# If the current water height is higher than the terrain
		if wh.water_height > wh.base_height.height:
			# Add to the surface
			wh.levelled = true
			surface.append(wh)

	# Take each surface point and level out the water around it
	var h : WaterHeight = surface.pop_back()
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
	
	for surface in water_surfaces:
		spread_surface_edges(surface)
		spread_surface_edges_into_terrain(surface)

func get_and_merge_any_adjoining_index(wh : WaterHeight):
	var ind = null # Inspecific about return type as may be int or null
	for n in get_grid_neighbours(wh):
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
	
func tidy_empty_water_surfaces():
	var new_water_surfaces := []
	var new_ind := 0
	# remove empty rows and re-align indices
	while not water_surfaces.empty():
		var surface : Array = water_surfaces.pop_front()
		if not surface.empty():
			for h in surface:
				h.water_body_ind = new_ind
			new_water_surfaces.append(surface)
			new_ind += 1
	water_surfaces = new_water_surfaces

func spread_surface_edges(surface : Array):
	var body_ind     : int    = (surface.front() as WaterHeight).water_body_ind
	var water_height : float  = (surface.front() as WaterHeight).water_height
	# Spread the surface to the neighbouring points
	for wh in surface:
		for n in get_grid_neighbours(wh, true):
			if not n.water_body_ind and n.base_height.height < water_height:
				# Modify water height
				n.water_height = water_height
				# Append to the surface
				n.water_body_ind = body_ind
				surface.append(n)

func spread_surface_edges_into_terrain(surface : Array):
	var body_ind     : int    = (surface.front() as WaterHeight).water_body_ind
	var water_height : float  = (surface.front() as WaterHeight).water_height
	var flood_height : float
	# Spread the surface to the neighbouring points
	var surf := surface.duplicate()
	for wh in surf:
		for n in get_grid_neighbours(wh):
			if not n.water_body_ind and n.base_height.height >= water_height:
				flood_height = min(flood_height, n.base_height.height) if flood_height else n.base_height.height
				# Append to the surface
				n.water_body_ind = body_ind
				surface.append(n)
	# Flood the whole surface (raise to the flood height)
	for wh in surface:
		wh.water_height = flood_height