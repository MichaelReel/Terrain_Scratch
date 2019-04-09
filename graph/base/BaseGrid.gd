extends Node

class_name BaseGrid

const MIN_HEIGHT    := -0.5 # Starting values for height extents
const MAX_HEIGHT    := 1.6

var height_grid     : Array # The fullset of height values across the grid
var world_width     : int
var world_breadth   : int
var scale           : float
var real_min_height := MIN_HEIGHT
var real_max_height := MAX_HEIGHT
var highest_edge    := MIN_HEIGHT

func _init(w, b, s):
	world_width = w
	world_breadth = b
	scale = s

func get_height(x : int, z : int) -> BaseHeight:
	return (height_grid[z][x] as BaseHeight)

func generate_height_values(hash_tool: HeightHash):
	height_grid = setup_2d_Height_array(world_width + 1, world_breadth + 1)

	for z in range(len(height_grid)):
		for x in range(len(height_grid[z])):
			var new_height := hash_tool.getHash(float((x - (world_width / 2.0)) * scale), float((z - (world_width / 2.0)) * scale))
			(height_grid[z][x] as BaseHeight).set_height(new_height)
			real_min_height = min(real_min_height, new_height)
			real_max_height = max(real_max_height, new_height)
			if z <= 0 or x <= 0 or z >= len(height_grid) - 1 or x >= len(height_grid[z]) -1:
				highest_edge = max(highest_edge, new_height)
				
func setup_2d_Height_array(width : int, breadth : int) -> Array:
	var rows := []
	for z in range(breadth):
		rows.append([])
		for x in range(width):
			(rows[z] as Array).append(BaseHeight.new(x, z))
	return rows

func get_grid_neighbours(h : BaseHeight, diamond := false):
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