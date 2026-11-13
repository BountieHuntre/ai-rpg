class_name TexturePainter
extends RefCounted
## Paints the world's tiling pixel-art textures in code, a pixel at a time:
## ground (grass, forest floor, dirt, cobbles, rock), plants (grass blades,
## flowers, leaves, needles, bark) and building faces (stone blocks, roof
## tiles, planks). Ground and building textures tile seamlessly (everything
## wraps); plant cards have clear backgrounds. Colors are in sRGB, near the
## game's flat palette so zones look the same from afar. Baked to PNGs by
## tools/textures/bake_textures.gd.

const KEYS := [
	"grass", "forest_floor", "dirt", "cobbles", "rock",
	"grass_blades", "flowers_yellow", "flowers_white", "flowers_blue", "ferns", "wheat",
	"leaves", "needles", "bark", "stone_wall", "roof_tiles", "planks", "thatch", "plaster",
]

var _rng := RandomNumberGenerator.new()


static func paint(key: String) -> Image:
	var painter := TexturePainter.new()
	painter._rng.seed = hash(key)
	return painter.call("_" + key)


# Helpers.

func _image(size: int, clear := false) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0) if clear else Color.BLACK)
	return image


## Seamless noise, 0 to 1, as rows of floats.
func _noise(size: int, frequency: float, octaves := 3, kind := FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> PackedFloat32Array:
	var noise := FastNoiseLite.new()
	noise.seed = _rng.randi()
	noise.noise_type = kind
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	var image := noise.get_seamless_image(size, size, false, false, 0.15, true)
	var values := PackedFloat32Array()
	values.resize(size * size)
	for y in size:
		for x in size:
			values[y * size + x] = image.get_pixel(x, y).r
	return values


func _put(image: Image, x: int, y: int, color: Color) -> void:
	var size := image.get_width()
	image.set_pixel(posmod(x, size), posmod(y, size), color)


func _at(image: Image, x: int, y: int) -> Color:
	var size := image.get_width()
	return image.get_pixel(posmod(x, size), posmod(y, size))


## A color from a palette by a value 0 to 1, with a little ordered dither
## so bands break into pixels.
const BAYER := [0.0, 0.5, 0.75, 0.25]


func _pick(palette: Array, value: float, x: int, y: int) -> Color:
	var dither: float = BAYER[(x % 2) + (y % 2) * 2] - 0.375
	var index := clampi(floori(value * palette.size() + dither * 0.6), 0, palette.size() - 1)
	return palette[index]


## Base ground: patches of the palette from noise.
func _base(size: int, palette: Array, frequency: float, contrast := 1.0) -> Image:
	var image := _image(size)
	var values := _noise(size, frequency)
	for y in size:
		for x in size:
			var v := clampf(0.5 + (values[y * size + x] - 0.5) * contrast, 0.0, 1.0)
			image.set_pixel(x, y, _pick(palette, v, x, y))
	return image


func _shade(color: Color, amount: float) -> Color:
	return color.lightened(amount) if amount > 0.0 else color.darkened(-amount)


# Ground.

const GRASS := [Color("3c5a26"), Color("476a2c"), Color("527733"), Color("5d843a"), Color("6a9142")]


func _grass() -> Image:
	var size := 128
	var image := _base(size, GRASS.slice(0, 4), 0.035, 1.6)
	# Blades: short upright strokes, dark at the root, light at the tip.
	for i in 900:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		var length := _rng.randi_range(2, 4)
		var lean := _rng.randi_range(-1, 1)
		_put(image, x, y + 1, GRASS[0])
		for step in length:
			var tip := float(step) / float(length - 1)
			var color: Color = GRASS[2] if tip < 0.5 else GRASS[3] if tip < 0.9 else GRASS[4]
			_put(image, x + (lean if step == length - 1 else 0), y - step, color)
	# A few clover leaves and specks of seed heads.
	for i in 40:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		for offset in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]:
			_put(image, x + offset.x, y + offset.y, Color("5f8a3a"))
		_put(image, x + 1, y + 1, GRASS[0])
	for i in 30:
		_put(image, _rng.randi_range(0, size - 1), _rng.randi_range(0, size - 1), Color("b8b878"))
	return image


const FOREST := [Color("2a3f1c"), Color("324a20"), Color("3d5626"), Color("4a622c")]
const LITTER := [Color("5a4426"), Color("6e5230"), Color("7f5f33"), Color("8a6a3a")]


func _forest_floor() -> Image:
	var size := 128
	var image := _base(size, FOREST, 0.04, 1.5)
	var litter := _noise(size, 0.06)
	# Fallen leaves where the litter noise is high, moss elsewhere.
	for i in 1400:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		if litter[y * size + x] < 0.45:
			continue
		var color: Color = LITTER[_rng.randi_range(0, LITTER.size() - 1)]
		_put(image, x, y, color)
		_put(image, x + 1, y, color.darkened(0.15))
		if _rng.randf() < 0.5:
			_put(image, x, y + 1, color.darkened(0.25))
	# Twigs.
	for i in 18:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		var dx := 1 if _rng.randf() < 0.5 else -1
		for step in _rng.randi_range(4, 7):
			_put(image, x + step * dx, y + step / 2, Color("3a2814"))
			_put(image, x + step * dx, y + step / 2 - 1, Color("6b5030"))
	# Moss tufts.
	for i in 300:
		_put(image, _rng.randi_range(0, size - 1), _rng.randi_range(0, size - 1), Color("55702f"))
	return image


const DIRT := [Color("6b5235"), Color("7a5e3d"), Color("876946"), Color("94754f"), Color("a0815a")]


func _dirt() -> Image:
	var size := 128
	var image := _base(size, DIRT.slice(0, 4), 0.05, 1.6)
	# Pebbles: lit on top, shaded below.
	for i in 140:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		var stone := Color("9c917f") if _rng.randf() < 0.6 else Color("84796a")
		var wide := _rng.randi_range(1, 3)
		for dx in wide:
			_put(image, x + dx, y, stone.lightened(0.15))
			_put(image, x + dx, y + 1, stone)
			_put(image, x + dx, y + 2, Color("4e3c27"))
	# Ruts and cracks.
	for i in 12:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		for step in _rng.randi_range(5, 12):
			x += _rng.randi_range(-1, 1)
			y += 1
			_put(image, x, y, Color("553f28"))
	for i in 400:
		_put(image, _rng.randi_range(0, size - 1), _rng.randi_range(0, size - 1), DIRT[4])
	return image


## Voronoi stones: [cells across, mortar width, palette, mortar color].
func _stones(size: int, cells: int, mortar: float, palette: Array, mortar_color: Color, jitter := 0.8) -> Image:
	var image := _image(size)
	var points := []
	var colors := []
	for cy in cells:
		for cx in cells:
			points.append(Vector2(cx + 0.5 + _rng.randf_range(-0.5, 0.5) * jitter, cy + 0.5 + _rng.randf_range(-0.5, 0.5) * jitter))
			colors.append(palette[_rng.randi_range(0, palette.size() - 1)])
	var cell := float(size) / cells
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5) / cell
			var best := INF
			var second := INF
			var best_index := 0
			var best_point := Vector2.ZERO
			for oy in [-1, 0, 1]:
				for ox in [-1, 0, 1]:
					var gx: int = int(floor(p.x)) + ox
					var gy: int = int(floor(p.y)) + oy
					var index := posmod(gy, cells) * cells + posmod(gx, cells)
					var q: Vector2 = points[index] + Vector2(floor(float(gx) / cells) * cells, floor(float(gy) / cells) * cells)
					var d := p.distance_to(q)
					if d < best:
						second = best
						best = d
						best_index = index
						best_point = q
					elif d < second:
						second = d
			var edge := second - best
			if edge < mortar:
				image.set_pixel(x, y, mortar_color)
				continue
			var color: Color = colors[best_index]
			# Lit from the top left: lighter there, darker toward the bottom right.
			var lean := (p - best_point).dot(Vector2(0.7, 0.7))
			if edge < mortar + 0.08:
				color = color.darkened(0.2) if lean > 0.0 else color.lightened(0.15)
			image.set_pixel(x, y, color)
	return image


func _cobbles() -> Image:
	var image := _stones(128, 10, 0.07, [Color("8a8478"), Color("958f82"), Color("a09a8c"), Color("7f796e"), Color("9b9180")], Color("4f4a40"))
	for i in 300:
		var x := _rng.randi_range(0, 127)
		var y := _rng.randi_range(0, 127)
		var under := _at(image, x, y)
		if under != Color("4f4a40"):
			_put(image, x, y, under.darkened(0.08))
	return image


const ROCK := [Color("3f3c38"), Color("524e48"), Color("666159"), Color("7c766c"), Color("948d82")]


func _rock() -> Image:
	var size := 128
	var image := _image(size)
	var warp := _noise(size, 0.05)
	var grain := _noise(size, 0.12)
	# Strata: bands across, bent by noise.
	for y in size:
		for x in size:
			var band := fposmod((y + warp[y * size + x] * 18.0) / 11.0, 1.0)
			var v := 0.2 + grain[y * size + x] * 0.6
			if band < 0.14:
				v -= 0.4
			elif band < 0.22:
				v -= 0.15
			elif band > 0.8:
				v += 0.3
			image.set_pixel(x, y, _pick(ROCK, clampf(v, 0.0, 1.0), x, y))
	# Cracks down the face, with a lit edge.
	for i in 14:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		for step in _rng.randi_range(6, 16):
			x += _rng.randi_range(-1, 1)
			y += 1
			_put(image, x, y, Color("3d3a35"))
			_put(image, x - 1, y, ROCK[4])
	# Lichen.
	for i in 60:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		var lichen := Color("8a8a5a") if _rng.randf() < 0.5 else Color("6f7a4a")
		_put(image, x, y, lichen)
		_put(image, x + 1, y, lichen.darkened(0.1))
	return image


# Plants: clear backgrounds.

func _grass_blades() -> Image:
	var size := 64
	var image := _image(size, true)
	for i in 26:
		var root_x := _rng.randf_range(4, size - 5)
		var height := _rng.randf_range(size * 0.45, size * 0.97)
		var bend := _rng.randf_range(-12.0, 12.0)
		var light := _rng.randf_range(-0.08, 0.1)
		var steps := int(height)
		for step in steps:
			var t := float(step) / steps
			var x := root_x + bend * t * t
			var y := size - 1 - step
			var color: Color = GRASS[1] if t < 0.3 else GRASS[2] if t < 0.6 else GRASS[3] if t < 0.85 else GRASS[4]
			color = _shade(color, light)
			var width := 2 if t < 0.55 else 1
			for w in width:
				var px := int(x) + w
				if px >= 0 and px < size:
					image.set_pixel(px, y, color if w == 0 else color.darkened(0.12))
	return image


func _flowers(petal: Color, centre: Color) -> Image:
	var size := 64
	var image := _grass_blades()
	# Thin the grass under the flowers a little, then stems and blossoms.
	for i in 6:
		var x := _rng.randi_range(8, size - 9)
		var top := _rng.randi_range(6, 26)
		for y in range(top, size):
			image.set_pixel(x, y, GRASS[1] if y > top + 3 else GRASS[2])
		var flower := _shade(petal, _rng.randf_range(-0.1, 0.1))
		for offset in [Vector2i(0, -2), Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
			image.set_pixel(x + offset.x, top + offset.y, flower)
		for offset in [Vector2i(-2, -1), Vector2i(2, -1), Vector2i(-1, 2), Vector2i(1, 2)]:
			image.set_pixel(x + offset.x, top + offset.y, flower.darkened(0.15))
		image.set_pixel(x, top, centre)
	return image


func _flowers_yellow() -> Image:
	return _flowers(Color("f2d03a"), Color("b8701c"))


func _flowers_white() -> Image:
	return _flowers(Color("f2f0e6"), Color("e8c23a"))


func _flowers_blue() -> Image:
	return _flowers(Color("7d7ff0"), Color("f0e070"))


const FERN := [Color("2c4a1f"), Color("3a6026"), Color("4a7530"), Color("5c8a3a")]


## Ferns: fronds arching out from the middle, leaflets either side.
func _ferns() -> Image:
	var size := 64
	var image := _image(size, true)
	for i in 9:
		var lean := _rng.randf_range(-1.0, 1.0)
		var reach := _rng.randf_range(0.6, 1.0)
		var root := Vector2(size / 2.0 + _rng.randf_range(-4, 4), size - 1)
		var steps := 34
		for step in steps:
			var t := float(step) / steps
			# Up, then out and over: an arch.
			var spine := root + Vector2(lean * 26.0 * reach * t, -(size - 8) * reach * sin(t * PI * 0.62))
			var shade: Color = FERN[1] if t < 0.4 else FERN[2]
			_set_clear(image, spine, FERN[0])
			if step > 3 and step % 2 == 0:
				var leaflet := (1.0 - t) * 7.0 + 1.5
				var across := Vector2(1.0, lean * 0.4).normalized()
				for k in int(leaflet):
					var droop := Vector2(0, k * 0.35)
					_set_clear(image, spine + across * (k + 1) + droop, shade if k < leaflet - 2 else FERN[3])
					_set_clear(image, spine - across * (k + 1) + droop, shade.darkened(0.12) if k < leaflet - 2 else FERN[2])
	return image


func _set_clear(image: Image, at: Vector2, color: Color) -> void:
	var x := int(at.x)
	var y := int(at.y)
	if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
		image.set_pixel(x, y, color)


const WHEAT := [Color("8a6a28"), Color("a8863a"), Color("c4a24c"), Color("d8b860"), Color("e6cc78")]


## Wheat: straight golden stalks, each with a grainy ear at the top.
func _wheat() -> Image:
	var size := 64
	var image := _image(size, true)
	for i in 16:
		var x := _rng.randi_range(3, size - 4)
		var top := _rng.randi_range(4, 18)
		var lean := _rng.randf_range(-3.0, 3.0)
		var length := size - top
		for step in length:
			var t := float(step) / length
			var px := int(x + lean * t)
			var y := size - 1 - step
			image.set_pixel(px, y, WHEAT[1] if t < 0.5 else WHEAT[2])
		# The ear: a column of grains two wide, with whiskers.
		var ear_x := int(x + lean)
		for dy in 7:
			var y := top + dy
			image.set_pixel(ear_x, y, WHEAT[3] if dy % 2 == 0 else WHEAT[2])
			if ear_x + 1 < size:
				image.set_pixel(ear_x + 1, y, WHEAT[4] if dy % 2 == 1 else WHEAT[1])
		_set_clear(image, Vector2(ear_x - 1, top - 2), WHEAT[3])
		_set_clear(image, Vector2(ear_x + 2, top - 1), WHEAT[3])
		_set_clear(image, Vector2(ear_x, top - 3), WHEAT[4])
	return image


const LEAVES := [Color("2d4a1e"), Color("3a5c24"), Color("486f2b"), Color("588234"), Color("6a963e")]


## Foliage: small overlapping leaves, lit from above, with dark gaps.
func _leaves() -> Image:
	var size := 64
	var image := _base(size, LEAVES.slice(0, 2), 0.1, 1.2)
	for i in 420:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		var color: Color = LEAVES[_rng.randi_range(1, 4)]
		# A leaf: a 3 by 2 blob, lighter on top.
		_put(image, x, y, color.lightened(0.1))
		_put(image, x + 1, y, color.lightened(0.1))
		_put(image, x - 1, y + 1, color)
		_put(image, x, y + 1, color)
		_put(image, x + 1, y + 1, color)
		_put(image, x, y + 2, color.darkened(0.25))
	return image


const NEEDLES := [Color("1f3a26"), Color("27472d"), Color("2f5434"), Color("3a633c"), Color("47714a")]


func _needles() -> Image:
	var size := 64
	var image := _base(size, NEEDLES.slice(0, 2), 0.1, 1.2)
	# Drooping sprays: short diagonal strokes either way from a twig.
	for i in 160:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		var color: Color = NEEDLES[_rng.randi_range(2, 4)]
		for step in 4:
			_put(image, x - step, y + step / 2, color)
			_put(image, x + step, y + step / 2, color.darkened(0.08))
		_put(image, x, y - 1, color.lightened(0.12))
	return image


const BARK := [Color("3a2818"), Color("47321e"), Color("543c24"), Color("62472b")]


func _bark() -> Image:
	var size := 64
	var image := _image(size)
	var warp := _noise(size, 0.08)
	for y in size:
		for x in size:
			# Furrows running up the trunk.
			var furrow := fposmod((x + warp[y * size + x] * 10.0) / 6.0, 1.0)
			var v := 0.35 + warp[y * size + x] * 0.4
			if furrow < 0.2:
				v -= 0.35
			elif furrow > 0.75:
				v += 0.25
			image.set_pixel(x, y, _pick(BARK, clampf(v, 0.0, 1.0), x, y))
	for i in 40:
		_put(image, _rng.randi_range(0, size - 1), _rng.randi_range(0, size - 1), Color("5a6a3a"))
	return image


# Buildings.

const STONE := [Color("8f8a80"), Color("9a958a"), Color("a6a094"), Color("8a8378"), Color("b0aa9c")]


## Dressed stone blocks in courses, each its own shade, with lit top edges.
func _stone_wall() -> Image:
	var size := 128
	var image := _image(size)
	var mortar := Color("5c574d")
	var course := 16
	var rows := size / course
	for row in rows:
		var offset := (row % 2) * 12 + _rng.randi_range(-2, 2)
		var x := 0
		var widths := []
		while x < size:
			var width := _rng.randi_range(16, 28)
			if size - x < 34:
				width = size - x
			widths.append(width)
			x += width
		var left := offset
		for width: int in widths:
			var color: Color = STONE[_rng.randi_range(0, STONE.size() - 1)]
			for dy in course:
				for dx in width:
					var px := left + dx
					var py := row * course + dy
					var c := color
					if dy == 0 or dx == 0:
						c = mortar
					elif dy == 1:
						c = color.lightened(0.15)
					elif dy == course - 1 or dx == width - 1:
						c = color.darkened(0.18)
					elif _rng.randf() < 0.06:
						c = color.darkened(0.08)
					_put(image, px, py, c)
			left += width
	return image


func _roof_tiles() -> Image:
	var size := 64
	var image := _image(size)
	var palette := [Color("7a3022"), Color("8a3826"), Color("94402a"), Color("6e2a1e")]
	var row_height := 8
	for row in size / row_height:
		var offset := (row % 2) * 4
		for tile in size / 8:
			var color: Color = palette[_rng.randi_range(0, palette.size() - 1)]
			for dy in row_height:
				for dx in 8:
					var c := color
					# Rounded tile bottoms throw a shadow on the row below.
					var curve := absf(dx - 3.5) / 3.5
					if dy >= row_height - 2 + int(curve * 1.5):
						c = color.darkened(0.35)
					elif dx == 0:
						c = color.darkened(0.2)
					elif dy == 0:
						c = color.lightened(0.12)
					_put(image, tile * 8 + dx + offset, row * row_height + dy, c)
	return image


const THATCH := [Color("8a6a2e"), Color("a07f3a"), Color("b39146"), Color("c4a356"), Color("6e5224")]


## Thatch: rows of straw bundles, each strand a short streak down the row,
## the row's lower edge in shadow.
func _thatch() -> Image:
	var size := 64
	var image := _base(size, THATCH.slice(0, 3), 0.12, 1.3)
	var row_height := 8
	for row in size / row_height:
		for i in 90:
			var x := _rng.randi_range(0, size - 1)
			var y := row * row_height + _rng.randi_range(0, row_height - 3)
			var color: Color = THATCH[_rng.randi_range(1, 3)]
			for step in _rng.randi_range(2, 4):
				_put(image, x, y + step, color if step < 2 else color.darkened(0.1))
		for x in size:
			_put(image, x, row * row_height + row_height - 1, THATCH[4])
			if _rng.randf() < 0.5:
				_put(image, x, row * row_height + row_height - 2, THATCH[0])
	return image


const PLASTER := [Color("cfc5ad"), Color("d8cfb8"), Color("e0d8c2"), Color("c6bba2")]


## Limewashed plaster: pale and a little uneven, with a few cracks and
## patches worn through to the wattle.
func _plaster() -> Image:
	var size := 64
	var image := _base(size, PLASTER, 0.07, 1.2)
	for i in 5:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		for step in _rng.randi_range(4, 9):
			x += _rng.randi_range(-1, 1)
			y += 1
			_put(image, x, y, Color("a39880"))
	for i in 3:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		for dy in 3:
			for dx in _rng.randi_range(3, 5):
				_put(image, x + dx, y + dy, Color("9a8462") if (dx + dy) % 2 == 0 else Color("8a7556"))
	return image


func _planks() -> Image:
	var size := 64
	var image := _image(size)
	var palette := [Color("6a4a2c"), Color("775434"), Color("825d3a"), Color("5f4228")]
	var grain := _noise(size, 0.15)
	var board := 8
	for row in size / board:
		var color: Color = palette[_rng.randi_range(0, palette.size() - 1)]
		var seam := _rng.randi_range(0, size - 1)
		for dy in board:
			for x in size:
				var y := row * board + dy
				var c := color
				var g := grain[y * size + x]
				if fposmod(x * 0.3 + g * 6.0, 2.0) < 0.35:
					c = color.darkened(0.12)
				if dy == board - 1 or x == seam:
					c = Color("35241a")
				elif dy == 0:
					c = color.lightened(0.1)
				image.set_pixel(x, y, c)
		# Nails at the seam.
		_put(image, seam + 2, row * board + 2, Color("2a2420"))
		_put(image, seam + 2, row * board + 5, Color("2a2420"))
	return image
