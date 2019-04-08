extends Node

class_name WaterHeight

const BED_ROCK_PRECISION = 128.0 # Making water heights a little more discrete

var water_height   : float
var water_body_ind : int
var levelled       : bool
var base_height    : BaseHeight
var closed         : bool

func _init(bh : BaseHeight):
	base_height = bh
	levelled = false

func calc_start_water_height(min_sea_level):
	# Water should be the min water height higher
	water_height = floor(max(min_sea_level, base_height.height) * BED_ROCK_PRECISION) / BED_ROCK_PRECISION

class Sorter:
	static func y_sort(a : WaterHeight, b : WaterHeight) -> bool:
		return BaseHeight.y_sort(a.base_height, b.base_height)
	
func place_height_in_list(list : Array):
	var h_ind := list.bsearch_custom(self, Sorter, "y_sort")
	list.insert(h_ind, self)
	closed = true