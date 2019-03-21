extends Object

# This is designed as a height map generation tool
# Internally it can use many techniques, but ultimately 
# should return a simple height per coordinate call

var amp_hash
var island_limiter

class ContinentalDome:
	var r
	func _init(radius):
		# Radius is in chunks
		r = radius

	func getHash(x, z):
		var y = 0.0
		var lxz = Vector2(x, z).length()
		if lxz > r:
			return y
		y = cos(PI * lxz / r) + 1.0

		return y / 2.0

func _init(shelf_limit, rseed = 0):
	seed(rseed)
	randi() # Discard first rand as value tends to be low
	island_limiter = ContinentalDome.new(shelf_limit)
	amp_hash = OpenSimplexNoise.new()
	amp_hash.seed = randi()
	amp_hash.octaves = 4
	amp_hash.period = 7.0
	amp_hash.persistence = 0.8

func getHash(x, y):
	var new_height = island_limiter.getHash(x, y)
	var amp = amp_hash.get_noise_2d(x, y)
	new_height = new_height + amp
	return new_height