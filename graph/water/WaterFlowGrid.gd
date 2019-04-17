extends Node

class_name WaterFlowGrid

var water_grid      : Array # The fullset of height values across the grid
var peaks           := []
var rivers          := []
var sinks           := []

func _init(bg : BaseGrid):
	water_grid = setup_2d_water_array(bg)

func get_height(x : int, z : int) -> WaterHeight:
	return (water_grid[z][x] as WaterHeight)

func get_all_heights() -> Array:
	# Not super efficient, but shouldn't be called often
	var all_heights := []
	for row in water_grid:
		all_heights += row
	return all_heights

func setup_2d_water_array(base_grid : BaseGrid) -> Array:
	var width : int = base_grid.world_width + 1
	var breadth : int = base_grid.world_breadth + 1
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
		neighbours.append(get_height(x - 1, z))
		if not diamond and z > 0:
			neighbours.append(get_height(x - 1, z - 1))
		if not diamond and z < len(water_grid) - 1:
			neighbours.append(get_height(x - 1, z + 1))
	if z > 0:
		neighbours.append(get_height(x, z - 1))
	if x < len(water_grid[0]) - 1:
		neighbours.append(get_height(x + 1, z))
		if not diamond and z > 0:
			neighbours.append(get_height(x + 1, z - 1))
		if not diamond and z < len(water_grid) - 1:
			neighbours.append(get_height(x + 1, z + 1))
	if z < len(water_grid) - 1:
		neighbours.append(get_height(x, z + 1))
	return neighbours

func water_flow():
	# Take each queued point and process it
	for wh in get_all_heights():
		# Link the current height to the lowest neighbour
		var up_link = wh
		var down_link = wh
		for n in get_grid_neighbours(wh, false):
			if n.height() < down_link.height():
				down_link = n
			if n.height() > up_link.height():
				up_link = n
		# Find peaks
		if up_link == wh:
			if wh.water_height <= wh.height():
				peaks.append(wh)
		# Mark the probable flow of water
		if down_link != wh:
			wh.flow_link = down_link
		else:
			sinks.append(wh)
	
#	# Go over each grid point and update it's link's score
#	for wh in get_all_heights():
#		if wh.flow_link:
#			wh.flow_link.water_score += 1
	
#	# Go over each grid point again and remove underscoring and underwater links
#	# (The underwater link stripping will only work if flooding has been completed)
#	for wh in get_all_heights():
#		if wh.water_score <= 0 or wh.under_water():
#			wh.water_score = 0
	
	# Create the river flows and group rivers
	# Start by parsing each grid point
	var flow_ind : int = 0
	
	rivers.append([])
	for wh in get_all_heights():
		# Determine flow to the nearest pool or sink
		while wh and not wh.flow_visited and not wh.under_water():
			wh.flow_ind = flow_ind
			wh.flow_visited = true
			rivers[flow_ind].append(wh)
			wh = wh.flow_link
		flow_ind += 1
		rivers.append([])
	
	# The last node in the river might connect to the start of another river
	for river in rivers:
		if river.empty(): continue
		var tail : WaterHeight = river.back()
		var link : WaterHeight = tail.flow_link
		if link and link.flow_ind and link.flow_ind != tail.flow_ind:
			var link_river : Array = rivers[link.flow_ind]
			var link_head : WaterHeight = link_river.front()
			if link_head == link:
				# Extend current river
				var wh = link_river.pop_front()
				while wh:
					wh.flow_ind = tail.flow_ind
					river.append(wh)
					wh = link_river.pop_front()
			else:
				# This is a tributary, add to the main flow
				while link:
					link.water_score += 1
					link = link.flow_link
	
	# Strip out the empty rivers
	print("rivers before tidy: " + str(len(rivers)))
	tidy_empty_river_surfaces()
	print("rivers after tidy: " + str(len(rivers)))

func tidy_empty_river_surfaces():
	var new_rivers := []
	var new_ind := 0
	# remove empty rows and re-align indices
	while not rivers.empty():
		var river : Array = rivers.pop_front()
		if not river.empty() and river.front().flow_link:
			for wh in river:
				wh.flow_ind = new_ind
			new_rivers.append(river)
			# Remove the last node if it doesn't flow anywhere
			if not river.back().flow_link:
				river.pop_back()
			new_ind += 1
	rivers = new_rivers
