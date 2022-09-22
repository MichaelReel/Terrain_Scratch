extends Object

class_name BaseTerrain

var hash_tool       : HeightHash
var scale           : float

var world_width     : int   # The total width of the terrain
var world_breadth   : int   # The total breadth of the terrain
var height_grid     : BaseGrid
var pool_grid       : WaterPoolGrid
var flow_grid       : WaterFlowGrid
var water_depth     : float = 0.5


func _init(ht : HeightHash, s : float, world_size : Vector2):
	hash_tool     = ht
	scale         = s
	world_width   = int(world_size.x)
	world_breadth = int(world_size.y)

	# Create a 'bedrock' kind of layer
	print("creating bedrock layer " + str(Time.get_ticks_usec()))
	height_grid = BaseGrid.new(world_width, world_breadth, scale)
	height_grid.generate_height_values(hash_tool)

	# Use the highest edge tile as the min water level
	print("running priority flood " + str(Time.get_ticks_usec()))
	pool_grid = WaterPoolGrid.new(height_grid)
	pool_grid.priority_flood(height_grid.highest_edge)
	
	# Calculate the flows after pools found
	print("calculating water flows " + str(Time.get_ticks_usec()))
	flow_grid = WaterFlowGrid.new(height_grid)
	flow_grid.water_flow()


func get_world_bounds_from_grid_bounds(grid_bounds : Rect2) -> Rect2:
	return Rect2(
		(grid_bounds.position.x - (world_width / 2.0)) / world_width, 
		(grid_bounds.position.y - (world_width / 2.0)) / world_width, 
		grid_bounds.size.x / world_width,
		grid_bounds.size.y / world_width
	)


func adjusted_water_level(water_level : float) -> float:
	return water_level - water_depth


func get_level_vert(grid_position : Vector2, water_level : float) -> Vector3:
	return Vector3(
		(grid_position.x - (world_width / 2.0)) / world_width,
		adjusted_water_level(water_level),
		(grid_position.y - (world_width / 2.0)) / world_width
	)


func get_global_position(grid_position: Vector2, grid_height: float) -> Vector3:
	"""This is here for repositioning markers after being added to the scene"""
	var offset = Vector3(grid_position.x, grid_height, grid_position.y)
	offset.x -= world_width / 2.0
	offset.x *= 4.0
	offset.y -= water_depth
	offset.y *= 128.0
	offset.z -= world_breadth / 2.0
	offset.z *= 4.0
	return offset

