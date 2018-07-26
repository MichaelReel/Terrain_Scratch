# Lifted from: http://mrl.nyu.edu/~perlin/noise/

var p
var min_hash
var max_hash
var dx
var dy
var dz

func _init(width = 1, height = 1, depth = 1, zoom = 1):
	self.p = []
	self.min_hash = 0.0
	self.max_hash = 0.0
	self.dx = float(zoom) / width
	self.dy = float(zoom) / height
	self.dz = float(zoom) / depth
	var permutation = self.getPermutation()
	for i in range(512):
	    self.p.append(permutation[i % permutation.size()])

func getPermutation():
	return [
		151,160,137, 91, 90, 15,131, 13,201, 95, 96, 53,194,233,  7,225,
		140, 36,103, 30, 69,142,  8, 99, 37,240, 21, 10, 23,190,  6,148,
		247,120,234, 75,  0, 26,197, 62, 94,252,219,203,117, 35, 11, 32,
		 57,177, 33, 88,237,149, 56, 87,174, 20,125,136,171,168, 68,175,
		 74,165, 71,134,139, 48, 27,166, 77,146,158,231, 83,111,229,122,
		 60,211,133,230,220,105, 92, 41, 55, 46,245, 40,244,102,143, 54,
		 65, 25, 63,161,  1,216, 80, 73,209, 76,132,187,208, 89, 18,169,
		200,196,135,130,116,188,159, 86,164,100,109,198,173,186,  3, 64,
		 52,217,226,250,124,123,  5,202, 38,147,118,126,255, 82, 85,212,
		207,206, 59,227, 47, 16, 58, 17,182,189, 28, 42,223,183,170,213,
		119,248,152,  2, 44,154,163, 70,221,153,101,155,167, 43,172,  9,
		129, 22, 39,253, 19, 98,108,110, 79,113,224,232,178,185,112,104,
		218,246, 97,228,251, 34,242,193,238,210,144, 12,191,179,162,241,
		 81, 51,145,235,249, 14,239,107, 49,192,214, 31,181,199,106,157,
		184, 84,204,176,115,121, 50, 45,127,  4,150,254,138,236,205, 93,
		222,114, 67, 29, 24, 72,243,141,128,195, 78, 66,215, 61,156,180,
	]

func getFloatHash(x, y, z = 0):
	var X = int(floor(x)) & 255             # FIND UNIT CUBE THAT
	var Y = int(floor(y)) & 255             # CONTAINS POINT.
	var Z = int(floor(z)) & 255
	x -= floor(x)                           # FIND RELATIVE X,Y,Z
	y -= floor(y)                           # OF POINT IN CUBE.
	z -= floor(z)
	var u = fade(x)                         # COMPUTE FADE CURVES
	var v = fade(y)                         # FOR EACH OF X,Y,Z.
	var w = fade(z) 
	var A  = self.p[X]+Y                    # HASH COORDINATES OF
	var AA = self.p[A]+Z                    # THE 8 CUBE CORNERS,
	var AB = self.p[A+1]+Z
	var B  = self.p[X+1]+Y
	var BA = self.p[B]+Z
	var BB = self.p[B+1]+Z

	return lerp(lerp(lerp(grad(self.p[AA  ], x  , y  , z   ),         # AND ADD
						  grad(self.p[BA  ], x-1, y  , z   ), u),     # BLENDED
					 lerp(grad(self.p[AB  ], x  , y-1, z   ),         # RESULTS
						  grad(self.p[BB  ], x-1, y-1, z   ), u), v), # FROM  8
				lerp(lerp(grad(self.p[AA+1], x  , y  , z-1 ),         # CORNERS
						  grad(self.p[BA+1], x-1, y  , z-1 ), u),     # OF CUBE
					 lerp(grad(self.p[AB+1], x  , y-1, z-1 ),
						  grad(self.p[BB+1], x-1, y-1, z-1 ), u), v), w);

func getHash(x, y, z = 0):
	return float(self.getFloatHash(x * self.dx, y * self.dy, z * self.dz))
	
func getOctaveHash(x, y, z = 0, n = 1):
	var total = 0
	var scale = 1
	for i in range(n):
		total += getHash(x * scale, y * scale, z * scale) * (1.0 / float(scale))
		scale << 1
	
	return total

func fade(t):
	return t * t * t * (t * (t * 6 - 15) + 10)

func grad(hsh, x, y, z):
	var h = hsh & 15;                      # CONVERT LO 4 BITS OF HASH CODE
	var u = x if h<8 else y                # INTO 12 GRADIENT DIRECTIONS.
	var v = y if h<4 else x if h==12 or h==14 else z
	return (u if h & 1 == 0 else -u) + (v if h & 2 == 0 else -v)
