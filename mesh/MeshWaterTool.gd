extends Node

class_name MeshWaterTool

func create_water_display_features(surface : Array, surfTool : SurfaceTool, terrain : BaseTerrain):
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
			var score : int = get_surface_occupancy_score(z, x, surface.front().water_body_ind, terrain)
			# We only care about drawing 5 posible scores
			match score:
				15: # Full quad
					draw_level_quad(surfTool, terrain.get_world_bounds_from_grid_bounds(Rect2(x, z, 1, 1)), water_level)
				14: # B - D - C
					draw_tri(
						surfTool,
						terrain.get_level_vert(Vector2(x + 1, z), water_level),
						terrain.get_level_vert(Vector2(x + 1, z + 1), water_level),
						terrain.get_level_vert(Vector2(x, z + 1), water_level)
					)
				13: # A - D - C
					draw_tri(
						surfTool,
						terrain.get_level_vert(Vector2(x, z), water_level),
						terrain.get_level_vert(Vector2(x + 1, z + 1), water_level),
						terrain.get_level_vert(Vector2(x, z + 1), water_level)
					)
				11: # A - B - D
					draw_tri(
						surfTool,
						terrain.get_level_vert(Vector2(x, z), water_level),
						terrain.get_level_vert(Vector2(x + 1, z), water_level),
						terrain.get_level_vert(Vector2(x + 1, z + 1), water_level)
					)
				7: # A - B - C
					draw_tri(
						surfTool,
						terrain.get_level_vert(Vector2(x, z), water_level),
						terrain.get_level_vert(Vector2(x + 1, z), water_level),
						terrain.get_level_vert(Vector2(x, z + 1), water_level)
					)
	
func get_surface_occupancy_score(z : int, x : int, water_body_ind : int, terrain : BaseTerrain) -> int:
	var score : int = 0
	# Assuming all surface features will have the same water height
	score += 1 if terrain.water_grid.get_height(x    , z    ).water_body_ind == water_body_ind else 0
	score += 2 if terrain.water_grid.get_height(x + 1, z    ).water_body_ind == water_body_ind else 0
	score += 4 if terrain.water_grid.get_height(x    , z + 1).water_body_ind == water_body_ind else 0
	score += 8 if terrain.water_grid.get_height(x + 1, z + 1).water_body_ind == water_body_ind else 0
	return score

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

func generate_water_meshes(terrain: BaseTerrain) -> Array:
	# Create and draw the water surfaces
	var water_meshes := []
	
	# TODO: Need to determine which water surfaces are relevant and crop accordingly
	#       Alternatively, drop the whole chunking thing and just generate everything in one big lump, at least at this level
	
	var surf_ind := 0
	var surf_step := 1.0 / len(terrain.water_grid.water_surfaces)
	for surface in terrain.water_grid.water_surfaces:
		var mesh := Mesh.new()
		var waterSurface := SurfaceTool.new()
		
		waterSurface.begin(Mesh.PRIMITIVE_TRIANGLES)
		waterSurface.add_color(Color(0.0, surf_step * surf_ind, 1.0, 0.25))
		
		create_water_display_features(surface, waterSurface, terrain)

		waterSurface.generate_normals()
		#warning-ignore:return_value_discarded
		waterSurface.commit(mesh)
		surf_ind += 1
		water_meshes.append(mesh)
	
	return water_meshes