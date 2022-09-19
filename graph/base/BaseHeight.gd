extends Node

class_name BaseHeight

var height : float
var grid_x : int
var grid_z : int

func _init(x : int, z : int):
	grid_x = x
	grid_z = z

func set_height(y : float):
	height = y

static func y_sort(a : BaseHeight, b : BaseHeight) -> bool:
	if a.height > b.height:
		return true
	elif a.height == b.height:
		if a.grid_z < b.grid_z:
			return true
		elif a.grid_z == b.grid_z:
			if a.grid_x < b.grid_x:
				return true
	return false
