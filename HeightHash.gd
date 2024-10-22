extends Object

class_name HeightHash

# This is designed as a height map generation tool
# Internally it can use many techniques, but ultimately 
# should return a simple height per coordinate call

var amp_hash
var island_limiter

class ContinentalDome:
	var r
	func _init(radius : float):
		# Radius is in chunks
		r = radius

	func getHash(x : float, z : float) -> float:
		var y = 0.0
		var lxz = Vector2(x, z).length()
		if lxz > r:
			return y
		y = cos(PI * lxz / r) + 1.0

		return y / 2.0

func _init(shelf_limit : float, rseed : int = 0):
	seed(rseed)
	#warning-ignore:return_value_discarded
	randi() # Discard first rand as value tends to be low
	island_limiter = ContinentalDome.new(shelf_limit)
	amp_hash = FastNoiseLite.new()
	amp_hash.seed = randi()
	amp_hash.fractal_octaves = 4
	amp_hash.period = 7.0
	amp_hash.persistence = 0.8

func getHash(x : float, y : float) -> float:
	var new_height = island_limiter.getHash(x, y)
	var amp = amp_hash.get_noise_2d(x, y)
	new_height = new_height + amp
	return new_height
