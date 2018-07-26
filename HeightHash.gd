extends Object

# This is designed as a height map generation tool
# Internally it can use many techniques, but ultimately 
# should return a simple height per coordinate call

var Perlin = load("res://PerlinRef.gd")

var variation_hash
var island_limiter

var hashes
var base_height
var start_amp
var amp_multiplier

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

func _init(shelf_limit):
	island_limiter = ContinentalDome.new(shelf_limit)
	variation_hash = Perlin.new(16.0, 16.0, 16.0, 1.0)
	hashes = [
		Perlin.new(1.0, 1.0, 1.0, 1.0),
		Perlin.new(0.25, 0.25, 0.25, 1.0),
		Perlin.new(0.0625, 0.0625, 0.0625, 1.0),
		# Perlin.new(0.03125, 0.03125, 1.0, 1.0),
		# Perlin.new(0.0078125, 0.0078125, 1.0, 1.0),
	]

	base_height = 1
	start_amp = 0.25
	amp_multiplier = 0.125

func getHash(x, y):
	var new_height = base_height
	var amp = start_amp
	for p in hashes:
		new_height += p.getHash(x, y) * amp
		amp *= amp_multiplier
	return new_height * (variation_hash.getHash(x, y) + 1.0) * island_limiter.getHash(x, y)