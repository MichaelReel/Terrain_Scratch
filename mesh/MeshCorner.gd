extends Node

class_name MeshCorner

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
