extends Node

class_name MeshQuad

var v1_x : int
var v1_z : int
var v2_x : int
var v2_z : int

func _init(vert1_x : int, vert1_z : int, vert2_x : int, vert2_z : int):
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

func A(grid : Array):
	return grid[v1_z][v1_x]
	
func B(grid : Array):
	return grid[v1_z][v2_x]
	
func C(grid : Array):
	return grid[v2_z][v1_x]

func D(grid : Array):
	return grid[v2_z][v2_x]
