extends Object

class_name BaseTerrain

var hash_tool       : HeightHash
var scale           : float

var world_width     : int   # The total width of the terrain
var world_breadth   : int   # The total breadth of the terrain
var height_grid     : BaseGrid
var water_grid      : WaterPoolGrid

func _init(ht : HeightHash, s : float, world_size : Vector2):
	hash_tool     = ht
	scale         = s
	world_width   = int(world_size.x)
	world_breadth = int(world_size.y)

	# Create a 'bedrock' kind of layer
	height_grid = BaseGrid.new(world_width, world_breadth, scale)
	height_grid.generate_height_values(hash_tool)

	# Use the highest edge tile as the min water level
	water_grid = WaterPoolGrid.new(height_grid)
	water_grid.priority_flood(height_grid.highest_edge)

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