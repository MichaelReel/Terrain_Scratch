extends Node

class_name MeshCorner

var pos : Vector3

func _init():
	pos = Vector3()

func set_xz(x : float, z : float):
	pos.x = x
	pos.z = z

func set_y(y : float):
	pos.y = y

