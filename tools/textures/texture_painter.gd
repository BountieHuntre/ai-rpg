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
	"snow", "frozen_heath", "frozen_dirt", "snow_rock", "frost_grass", "heather", "slate_snow",
	"red_earth", "dry_scrub", "red_dirt", "red_rock", "sand", "hide", "dry_grass", "cactus",
	"dead_grass", "dead_leaves", "mud", "slate", "dead_blades",
	"elf_grass", "moss_floor", "elf_path", "blue_rock", "elf_blades", "elf_leaves", "pale_bark", "elf_roof",
	"grass_blades", "flowers_yellow", "flowers_white", "flowers_blue", "ferns", "wheat",
	"leaves", "needles", "bark", "stone_wall", "roof_tiles", "planks", "thatch", "plaster",
	"gear_weave", "gear_quilted", "gear_stripes", "gear_leather", "gear_studded", "gear_tooled",
	"gear_chain", "gear_scale", "gear_plate", "gear_banded", "gear_wood", "gear_planks",
	"gear_wrap", "gear_brushed", "gear_hammered",
]
## Gear patterns laid under a character's colours (HumanoidModel's
## GEAR_PATTERNS, shaders/character.gdshader): grey, mid-grey leaving the colour
## as it is, darker and lighter shading it; 32 pixels, tiling.
const GEAR_KEYS := [
	"gear_weave", "gear_quilted", "gear_stripes", "gear_leather", "gear_studded", "gear_tooled",
	"gear_chain", "gear_scale", "gear_plate", "gear_banded", "gear_wood", "gear_planks",
	"gear_wrap", "gear_brushed", "gear_hammered",
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


# Snow lands (Frosthollow, Highpeak).

const SNOW := [Color("9aa6bd"), Color("b3bfd3"), Color("c9d3e2"), Color("dce3ee"), Color("eef2f8")]


## Snow: soft drifts rippled by the wind, blue in their hollows, with a
## glint here and there.
func _snow() -> Image:
	var size := 128
	var image := _image(size)
	var drift := _noise(size, 0.03)
	var ripple := _noise(size, 0.09)
	for y in size:
		for x in size:
			var wave := sin((x * 0.35 + y * 0.12) + ripple[y * size + x] * 6.0) * 0.08
			var v := 0.45 + (drift[y * size + x] - 0.5) * 0.9 + wave
			image.set_pixel(x, y, _pick(SNOW.slice(1), clampf(v, 0.0, 1.0), x, y))
	# Footprint-like dimples and blue shadows under small lumps.
	for i in 70:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		_put(image, x, y, SNOW[4])
		_put(image, x + 1, y, SNOW[3])
		_put(image, x, y + 1, SNOW[1])
		_put(image, x + 1, y + 1, SNOW[0])
	for i in 50:
		_put(image, _rng.randi_range(0, size - 1), _rng.randi_range(0, size - 1), Color("ffffff"))
	return image


const HEATH := [Color("4a4a32"), Color("5e5a3a"), Color("736c46"), Color("8a8156")]


## Thin snow over heath: dry grass and heather poking through in tufts.
func _frozen_heath() -> Image:
	var size := 128
	var image := _snow()
	var cover := _noise(size, 0.05)
	for i in 1100:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		if cover[y * size + x] < 0.4:
			continue
		var length := _rng.randi_range(2, 4)
		var lean := _rng.randi_range(-1, 1)
		_put(image, x, y + 1, SNOW[0])
		for step in length:
			var tip := float(step) / float(length - 1)
			var color: Color = HEATH[0] if tip < 0.3 else HEATH[1] if tip < 0.7 else HEATH[2] if tip < 0.95 else HEATH[3]
			_put(image, x + (lean if step == length - 1 else 0), y - step, color)
	# Heather sprigs, frosted purple.
	for i in 45:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		if cover[y * size + x] < 0.5:
			continue
		for offset in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, -1)]:
			_put(image, x + offset.x, y + offset.y, Color("8f7a9a"))
		_put(image, x + 1, y - 1, Color("b7a6c0"))
	return image


## A trodden path: packed snow and slush over mud, ruts and pebbles.
func _frozen_dirt() -> Image:
	var size := 128
	var image := _dirt()
	var slush := _noise(size, 0.06)
	for y in size:
		for x in size:
			var v := slush[y * size + x]
			if v > 0.52:
				var t := clampf((v - 0.52) * 4.0, 0.0, 1.0)
				image.set_pixel(x, y, _pick(SNOW.slice(0, 4), t * 0.9, x, y))
			elif v > 0.46:
				image.set_pixel(x, y, image.get_pixel(x, y).lerp(SNOW[0], 0.5))
	return image


## Grey rock with snow lying on its ledges and frost in its cracks.
func _snow_rock() -> Image:
	var size := 128
	var image := _image(size)
	var warp := _noise(size, 0.05)
	var grain := _noise(size, 0.12)
	var palette := [Color("3c3d42"), Color("4f5057"), Color("63646c"), Color("7a7b84"), Color("92939c")]
	for y in size:
		for x in size:
			var band := fposmod((y + warp[y * size + x] * 18.0) / 11.0, 1.0)
			var v := 0.2 + grain[y * size + x] * 0.6
			var color: Color
			if band > 0.84 and grain[y * size + x] > 0.3:
				color = _pick(SNOW.slice(2), grain[y * size + x], x, y)
			else:
				if band < 0.14:
					v -= 0.4
				elif band < 0.22:
					v -= 0.15
				elif band > 0.76:
					v += 0.3
				color = _pick(palette, clampf(v, 0.0, 1.0), x, y)
			image.set_pixel(x, y, color)
	for i in 14:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		for step in _rng.randi_range(6, 16):
			x += _rng.randi_range(-1, 1)
			y += 1
			_put(image, x, y, Color("2f3036"))
			_put(image, x - 1, y, SNOW[2])
	return image


## Dry, pale grass standing out of the snow.
func _frost_grass() -> Image:
	var size := 64
	var image := _image(size, true)
	for i in 20:
		var root_x := _rng.randf_range(4, size - 5)
		var height := _rng.randf_range(size * 0.4, size * 0.9)
		var bend := _rng.randf_range(-14.0, 14.0)
		var light := _rng.randf_range(-0.08, 0.1)
		var steps := int(height)
		for step in steps:
			var t := float(step) / steps
			var x := root_x + bend * t * t
			var y := size - 1 - step
			var color: Color = HEATH[0] if t < 0.25 else HEATH[1] if t < 0.55 else HEATH[2] if t < 0.85 else Color("c8c6b8")
			color = _shade(color, light)
			var width := 2 if t < 0.5 else 1
			for w in width:
				var px := int(x) + w
				if px >= 0 and px < size:
					image.set_pixel(px, y, color if w == 0 else color.darkened(0.12))
	return image


## Low heather, frosted: a mound of twiggy stems with pale purple bells.
func _heather() -> Image:
	var size := 64
	var image := _image(size, true)
	for i in 34:
		var root_x := _rng.randf_range(10, size - 11)
		var height := _rng.randf_range(size * 0.25, size * 0.55)
		var bend := _rng.randf_range(-10.0, 10.0)
		var steps := int(height)
		for step in steps:
			var t := float(step) / steps
			var x := int(root_x + bend * t)
			var y := size - 1 - step
			if x < 0 or x >= size:
				continue
			image.set_pixel(x, y, Color("4a3e3a") if t < 0.5 else Color("5d4f52"))
			if t > 0.45 and _rng.randf() < 0.55:
				var bell := Color("9b82a8") if _rng.randf() < 0.6 else Color("c7b8d2")
				for dx in [-1, 1]:
					if x + dx >= 0 and x + dx < size:
						image.set_pixel(x + dx, y, bell)
	return image


## Slates in staggered rows, blue-grey, with snow lying along the rows.
func _slate_snow() -> Image:
	var size := 64
	var image := _image(size)
	var palette := [Color("3d4250"), Color("464c5b"), Color("505768"), Color("383c48")]
	var drift := _noise(size, 0.08)
	var row_height := 8
	for row in size / row_height:
		var offset := (row % 2) * 5
		for tile in size / 10 + 1:
			var color: Color = palette[_rng.randi_range(0, palette.size() - 1)]
			for dy in row_height:
				for dx in 10:
					var x := tile * 10 + dx + offset
					var y := row * row_height + dy
					var c := color
					if dy >= row_height - 2:
						c = color.darkened(0.35)
					elif dx == 0:
						c = color.darkened(0.25)
					elif dy == 0:
						c = color.lightened(0.1)
					# Snow along each row's top, deeper where the drift is.
					var deep := drift[posmod(y, size) * size + posmod(x, size)]
					if deep > 0.5 and dy < int((deep - 0.5) * 9.0) + 1 and dy < row_height - 3:
						c = _pick(SNOW.slice(2), deep, x, y)
					_put(image, x, y, c)
	return image


# Red lands (Emberhollow, the Redsand Coast).

const RED_EARTH := [Color("8a4a2c"), Color("9a5532"), Color("a8613a"), Color("b46d43"), Color("c27c4f")]


## Red earth: baked, cracked, with pebbles and a little grit.
func _red_earth() -> Image:
	var size := 128
	var image := _base(size, RED_EARTH.slice(0, 4), 0.045, 1.5)
	for i in 120:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		var stone := Color("b79a7c") if _rng.randf() < 0.5 else Color("8c6a52")
		_put(image, x, y, stone.lightened(0.15))
		_put(image, x + 1, y, stone)
		_put(image, x, y + 1, Color("5e3220"))
	# Cracks in the baked crust.
	for i in 16:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		for step in _rng.randi_range(4, 10):
			x += _rng.randi_range(-1, 1)
			y += _rng.randi_range(0, 1)
			_put(image, x, y, Color("6a361f"))
	for i in 500:
		_put(image, _rng.randi_range(0, size - 1), _rng.randi_range(0, size - 1), RED_EARTH[4])
	return image


const SCRUB := [Color("6e5a2a"), Color("8a7434"), Color("a48c42"), Color("bba250")]


## Red earth with dry grass in tufts.
func _dry_scrub() -> Image:
	var size := 128
	var image := _red_earth()
	var cover := _noise(size, 0.05)
	for i in 1300:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		if cover[y * size + x] < 0.35:
			continue
		var length := _rng.randi_range(2, 4)
		var lean := _rng.randi_range(-1, 1)
		_put(image, x, y + 1, Color("6a361f"))
		for step in length:
			var tip := float(step) / float(length - 1)
			var color: Color = SCRUB[0] if tip < 0.3 else SCRUB[1] if tip < 0.7 else SCRUB[2] if tip < 0.95 else SCRUB[3]
			_put(image, x + (lean if step == length - 1 else 0), y - step, color)
	return image


const RED_DIRT := [Color("7a4a30"), Color("8a5838"), Color("966442"), Color("a3704c"), Color("b07e58")]


## A trodden red road: packed earth, ruts and pebbles.
func _red_dirt() -> Image:
	var size := 128
	var image := _base(size, RED_DIRT.slice(0, 4), 0.05, 1.4)
	for i in 160:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		var stone := Color("a8907a") if _rng.randf() < 0.6 else Color("80695a")
		var wide := _rng.randi_range(1, 3)
		for dx in wide:
			_put(image, x + dx, y, stone.lightened(0.15))
			_put(image, x + dx, y + 1, stone)
			_put(image, x + dx, y + 2, Color("553321"))
	for i in 12:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		for step in _rng.randi_range(5, 12):
			x += _rng.randi_range(-1, 1)
			y += 1
			_put(image, x, y, Color("5a3624"))
	for i in 400:
		_put(image, _rng.randi_range(0, size - 1), _rng.randi_range(0, size - 1), RED_DIRT[4])
	return image


## Red sandstone in bent strata, with dark cracks.
func _red_rock() -> Image:
	var size := 128
	var image := _image(size)
	var warp := _noise(size, 0.05)
	var grain := _noise(size, 0.12)
	var palette := [Color("5a2a1c"), Color("723824"), Color("8a462c"), Color("a25836"), Color("b86c44")]
	for y in size:
		for x in size:
			var band := fposmod((y + warp[y * size + x] * 18.0) / 9.0, 1.0)
			var v := 0.2 + grain[y * size + x] * 0.6
			if band < 0.14:
				v -= 0.4
			elif band < 0.22:
				v -= 0.15
			elif band > 0.78:
				v += 0.3
			image.set_pixel(x, y, _pick(palette, clampf(v, 0.0, 1.0), x, y))
	for i in 14:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		for step in _rng.randi_range(6, 16):
			x += _rng.randi_range(-1, 1)
			y += 1
			_put(image, x, y, Color("41200f"))
			_put(image, x - 1, y, palette[4])
	return image


const SAND := [Color("c49a64"), Color("d0a870"), Color("dab57c"), Color("e4c28a"), Color("eecf9a")]


## Beach sand: wind ripples, shells and dark grains.
func _sand() -> Image:
	var size := 128
	var image := _image(size)
	var ripple := _noise(size, 0.08)
	var drift := _noise(size, 0.03)
	for y in size:
		for x in size:
			var wave := sin(y * 0.7 + ripple[y * size + x] * 5.0) * 0.12
			var v := 0.45 + (drift[y * size + x] - 0.5) * 0.7 + wave
			image.set_pixel(x, y, _pick(SAND, clampf(v, 0.0, 1.0), x, y))
	for i in 25:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		_put(image, x, y, Color("f6eee0"))
		_put(image, x + 1, y, Color("e0d2bc"))
	for i in 300:
		_put(image, _rng.randi_range(0, size - 1), _rng.randi_range(0, size - 1), Color("a07a4c"))
	return image


const HIDE := [Color("8a6440"), Color("9a7248"), Color("a87f52"), Color("b48c5e")]


## Stitched hides: uneven panels with darker seams and stitch marks.
func _hide() -> Image:
	var size := 64
	var image := _base(size, HIDE, 0.07, 1.3)
	# Seams across and down, wavering, stitched.
	for seam in 3:
		var y := seam * 21 + _rng.randi_range(2, 8)
		for x in size:
			y += _rng.randi_range(-1, 1) if _rng.randf() < 0.2 else 0
			_put(image, x, y, Color("5a3e24"))
			if x % 4 == 0:
				_put(image, x, y - 1, Color("d8c39a"))
				_put(image, x, y + 1, Color("d8c39a"))
	for seam in 2:
		var x := seam * 32 + _rng.randi_range(4, 20)
		for y in size:
			x += _rng.randi_range(-1, 1) if _rng.randf() < 0.15 else 0
			_put(image, x, y, Color("5a3e24"))
	for i in 120:
		_put(image, _rng.randi_range(0, size - 1), _rng.randi_range(0, size - 1), Color("6e4c2c"))
	return image


## Dry, straw-yellow grass in a tuft.
func _dry_grass() -> Image:
	var size := 64
	var image := _image(size, true)
	for i in 22:
		var root_x := _rng.randf_range(4, size - 5)
		var height := _rng.randf_range(size * 0.35, size * 0.85)
		var bend := _rng.randf_range(-16.0, 16.0)
		var light := _rng.randf_range(-0.08, 0.1)
		var steps := int(height)
		for step in steps:
			var t := float(step) / steps
			var x := root_x + bend * t * t
			var y := size - 1 - step
			var color: Color = SCRUB[0] if t < 0.25 else SCRUB[1] if t < 0.55 else SCRUB[2] if t < 0.85 else SCRUB[3]
			color = _shade(color, light)
			var width := 2 if t < 0.5 else 1
			for w in width:
				var px := int(x) + w
				if px >= 0 and px < size:
					image.set_pixel(px, y, color if w == 0 else color.darkened(0.12))
	return image


## A cactus's skin: ribs running up it, lit on one side, with pale spines.
func _cactus() -> Image:
	var size := 32
	var image := _image(size)
	var palette := [Color("2c4a24"), Color("3a5e2c"), Color("4a7034"), Color("5c823e")]
	for y in size:
		for x in size:
			var rib := fposmod(x, 8.0) / 8.0
			var v := 0.25 + sin(rib * PI) * 0.65
			image.set_pixel(x, y, _pick(palette, clampf(v, 0.0, 1.0), x, y))
	for i in 40:
		var x := _rng.randi_range(0, size / 8 - 1) * 8 + 4
		var y := _rng.randi_range(0, size - 1)
		_put(image, x, y, Color("e6dcb4"))
		_put(image, x + 1, y - 1, Color("c8bc94"))
	return image


# The dead lands (Gravesend, the Duskmoor Glades).

const DEAD := [Color("3e3e2c"), Color("4a4832"), Color("56523a"), Color("625c42"), Color("706a4e")]


## Dead grass: grey-olive and brown, flattened, with bare patches.
func _dead_grass() -> Image:
	var size := 128
	var image := _base(size, DEAD.slice(0, 4), 0.04, 1.5)
	var bare := _noise(size, 0.06)
	for i in 900:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		if bare[y * size + x] < 0.3:
			continue
		var length := _rng.randi_range(2, 4)
		var lean := _rng.randi_range(-1, 1)
		_put(image, x, y + 1, DEAD[0].darkened(0.2))
		for step in length:
			var tip := float(step) / float(length - 1)
			var color: Color = DEAD[1] if tip < 0.4 else DEAD[3] if tip < 0.9 else DEAD[4]
			_put(image, x + (lean if step == length - 1 else 0), y - step, color)
	for i in 300:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		if bare[y * size + x] < 0.3:
			_put(image, x, y, Color("4a3f30"))
	return image


const LITTER_DEAD := [Color("2e271e"), Color("3a3024"), Color("4a3c2a"), Color("5a4830"), Color("6a5636")]


## Dead leaves and twigs on dark soil, under the dead trees.
func _dead_leaves() -> Image:
	var size := 128
	var image := _base(size, LITTER_DEAD.slice(0, 3), 0.05, 1.4)
	for i in 1100:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		var leaf: Color = LITTER_DEAD[_rng.randi_range(2, 4)]
		_put(image, x, y, leaf)
		_put(image, x + 1, y, leaf.darkened(0.15))
		if _rng.randf() < 0.5:
			_put(image, x, y + 1, leaf.darkened(0.3))
	for i in 18:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		var dx := 1 if _rng.randf() < 0.5 else -1
		for step in _rng.randi_range(3, 7):
			_put(image, x + step * dx, y + step / 2, Color("5e5040"))
	return image


## Wet black-brown mud with puddles catching the sky.
func _mud() -> Image:
	var size := 128
	var image := _base(size, [Color("2a241c"), Color("332b22"), Color("3d3428"), Color("483d30")], 0.05, 1.5)
	var wet := _noise(size, 0.07)
	for y in size:
		for x in size:
			var v := wet[y * size + x]
			if v > 0.68:
				image.set_pixel(x, y, Color("5a6066") if v > 0.74 else Color("3e4246"))
	for i in 200:
		_put(image, _rng.randi_range(0, size - 1), _rng.randi_range(0, size - 1), Color("524636"))
	return image


## Plain blue-grey slates in staggered rows.
func _slate() -> Image:
	var size := 64
	var image := _image(size)
	var palette := [Color("3d4250"), Color("464c5b"), Color("505768"), Color("383c48")]
	var row_height := 8
	for row in size / row_height:
		var offset := (row % 2) * 5
		for tile in size / 10 + 1:
			var color: Color = palette[_rng.randi_range(0, palette.size() - 1)]
			for dy in row_height:
				for dx in 10:
					var c := color
					if dy >= row_height - 2:
						c = color.darkened(0.35)
					elif dx == 0:
						c = color.darkened(0.25)
					elif dy == 0:
						c = color.lightened(0.1)
					_put(image, tile * 10 + dx + offset, row * row_height + dy, c)
	return image


## Dead grass in a tuft: grey-olive blades, brown at the tips.
func _dead_blades() -> Image:
	var size := 64
	var image := _image(size, true)
	for i in 22:
		var root_x := _rng.randf_range(4, size - 5)
		var height := _rng.randf_range(size * 0.35, size * 0.85)
		var bend := _rng.randf_range(-18.0, 18.0)
		var light := _rng.randf_range(-0.08, 0.08)
		var steps := int(height)
		for step in steps:
			var t := float(step) / steps
			var x := root_x + bend * t * t
			var y := size - 1 - step
			var color: Color = DEAD[1] if t < 0.3 else DEAD[2] if t < 0.6 else DEAD[3] if t < 0.85 else Color("7a6648")
			color = _shade(color, light)
			var width := 2 if t < 0.5 else 1
			for w in width:
				var px := int(x) + w
				if px >= 0 and px < size:
					image.set_pixel(px, y, color if w == 0 else color.darkened(0.12))
	return image


# The elven woods (Mossglen, Eldergrove Isle).

const ELF_GRASS := [Color("1f3a36"), Color("27463f"), Color("2e5248"), Color("365e53"), Color("3f6a5e")]


## Dusky blue-green grass under the moon, with pale flecks.
func _elf_grass() -> Image:
	var size := 128
	var image := _base(size, ELF_GRASS.slice(0, 4), 0.035, 1.5)
	for i in 900:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		var length := _rng.randi_range(2, 4)
		var lean := _rng.randi_range(-1, 1)
		_put(image, x, y + 1, ELF_GRASS[0])
		for step in length:
			var tip := float(step) / float(length - 1)
			var color: Color = ELF_GRASS[2] if tip < 0.5 else ELF_GRASS[3] if tip < 0.9 else ELF_GRASS[4]
			_put(image, x + (lean if step == length - 1 else 0), y - step, color)
	for i in 30:
		_put(image, _rng.randi_range(0, size - 1), _rng.randi_range(0, size - 1), Color("a8c4d8"))
	return image


## Deep moss over the forest floor, cushioned, with tiny pale sprigs.
func _moss_floor() -> Image:
	var size := 128
	var image := _base(size, [Color("1c3324"), Color("234029"), Color("2b4d30"), Color("345a37")], 0.06, 1.6)
	var lumps := _noise(size, 0.12)
	for y in size:
		for x in size:
			if lumps[y * size + x] > 0.62:
				image.set_pixel(x, y, Color("3e6a40") if lumps[y * size + x] > 0.7 else Color("37603b"))
	for i in 160:
		_put(image, _rng.randi_range(0, size - 1), _rng.randi_range(0, size - 1), Color("6f9a6a"))
	return image


## A soft earth path, lavender-grey, with fallen violet leaves.
func _elf_path() -> Image:
	var size := 128
	var image := _base(size, [Color("4a4048"), Color("554a52"), Color("61555c"), Color("6c6068")], 0.05, 1.4)
	for i in 120:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		var leaf := Color("7a5a8a") if _rng.randf() < 0.6 else Color("4f8a80")
		_put(image, x, y, leaf)
		_put(image, x + 1, y, leaf.darkened(0.2))
	for i in 90:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		_put(image, x, y, Color("8c8290"))
		_put(image, x, y + 1, Color("3a3238"))
	return image


## Cool blue-grey stone in strata, with moss in the cracks.
func _blue_rock() -> Image:
	var size := 128
	var image := _image(size)
	var warp := _noise(size, 0.05)
	var grain := _noise(size, 0.12)
	var palette := [Color("2e3040"), Color("3c3f52"), Color("4b4e63"), Color("5d6076"), Color("727590")]
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
			image.set_pixel(x, y, _pick(palette, clampf(v, 0.0, 1.0), x, y))
	for i in 14:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		for step in _rng.randi_range(6, 16):
			x += _rng.randi_range(-1, 1)
			y += 1
			_put(image, x, y, Color("22232e"))
			_put(image, x - 1, y, Color("3e6a50"))
	return image


## Blue-green grass in a tuft, for the elven woods.
func _elf_blades() -> Image:
	var size := 64
	var image := _image(size, true)
	for i in 24:
		var root_x := _rng.randf_range(4, size - 5)
		var height := _rng.randf_range(size * 0.4, size * 0.95)
		var bend := _rng.randf_range(-12.0, 12.0)
		var light := _rng.randf_range(-0.08, 0.1)
		var steps := int(height)
		for step in steps:
			var t := float(step) / steps
			var x := root_x + bend * t * t
			var y := size - 1 - step
			var color: Color = ELF_GRASS[1] if t < 0.3 else ELF_GRASS[2] if t < 0.6 else ELF_GRASS[3] if t < 0.85 else ELF_GRASS[4]
			color = _shade(color, light)
			var width := 2 if t < 0.55 else 1
			for w in width:
				var px := int(x) + w
				if px >= 0 and px < size:
					image.set_pixel(px, y, color if w == 0 else color.darkened(0.12))
	return image


## The elven trees' leaves: teal and blue-green with violet among them.
func _elf_leaves() -> Image:
	var image := _leaves()
	var palette := [Color("173430"), Color("1f4540"), Color("2a5a52"), Color("357063"), Color("4a8a7a")]
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var v := clampf((c.get_luminance() - 0.12) * 2.6, 0.0, 1.0)
			var color: Color = _pick(palette, v, x, y)
			if (x * 7 + y * 13) % 23 == 0:
				color = Color("6a4a86")
			image.set_pixel(x, y, color)
	return image


## Silver-grey bark, smooth, with dark marks across it.
func _pale_bark() -> Image:
	var size := 64
	var image := _base(size, [Color("8a8590"), Color("98939e"), Color("a6a1ac"), Color("b4afba")], 0.08, 1.2)
	for i in 40:
		var x := _rng.randi_range(0, size - 1)
		var y := _rng.randi_range(0, size - 1)
		for step in _rng.randi_range(2, 6):
			_put(image, x + step, y, Color("5a5560"))
	for i in 60:
		_put(image, _rng.randi_range(0, size - 1), _rng.randi_range(0, size - 1), Color("6c8078"))
	return image


## Leaf-shaped shingles, pale, to be tinted violet or teal.
func _elf_roof() -> Image:
	var size := 64
	var image := _image(size)
	var row_height := 8
	for row in size / row_height:
		var offset := (row % 2) * 4
		for tile in size / 8 + 1:
			var v := _rng.randf_range(0.82, 1.0)
			for dy in row_height:
				for dx in 8:
					var curve := absf(dx - 3.5) / 3.5
					var c := Color(v, v, v)
					if dy >= row_height - 1 - int(curve * 3.0):
						c = c.darkened(0.4)
					elif dx == 0:
						c = c.darkened(0.2)
					elif dy < 2:
						c = c.lightened(0.1)
					_put(image, tile * 8 + dx + offset, row * row_height + dy, c)
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


# Gear patterns: values round 0.5 (the colour as it is), written as grey.

const GEAR := 32


func _gear(fill := 0.5) -> Image:
	var image := _image(GEAR)
	image.fill(Color(fill, fill, fill))
	return image


func _g(image: Image, x: int, y: int, value: float) -> void:
	_put(image, x, y, Color(value, value, value))


## Mid-grey with a little noise, for leather and metal.
func _grain(amount: float, frequency: float) -> Image:
	var image := _gear()
	var values := _noise(GEAR, frequency)
	for y in GEAR:
		for x in GEAR:
			_g(image, x, y, 0.5 + (values[y * GEAR + x] - 0.5) * amount)
	return image


## Cloth: over-and-under threads, two pixels each.
func _gear_weave() -> Image:
	var image := _gear()
	for y in GEAR:
		for x in GEAR:
			var over := ((x / 2) + (y / 2)) % 2 == 0
			var edge := (x % 2 == 1) if over else (y % 2 == 1)
			_g(image, x, y, (0.56 if over else 0.46) - (0.05 if edge else 0.0) + _rng.randf_range(-0.02, 0.02))
	return image


## Quilted: padded diamonds with stitched seams.
func _gear_quilted() -> Image:
	var image := _gear_weave()
	for y in GEAR:
		for x in GEAR:
			var a := posmod(x + y, 16)
			var b := posmod(x - y, 16)
			var d := mini(mini(a, 16 - a), mini(b, 16 - b))
			var v := _at(image, x, y).r + 0.02 * d - 0.05
			if a == 0 or b == 0:
				v = 0.36 if (x % 2 == 0) else 0.43
			_g(image, x, y, v)
	return image


## Cloth with woven bands.
func _gear_stripes() -> Image:
	var image := _gear_weave()
	for y in GEAR:
		var band := posmod(y, 16)
		for x in GEAR:
			var v := _at(image, x, y).r
			if band < 3:
				v -= 0.14
			elif band == 3 or band == 15:
				v += 0.1
			_g(image, x, y, v)
	return image


## Leather: soft grain and a stitched seam.
func _gear_leather() -> Image:
	var image := _grain(0.5, 0.14)
	for x in GEAR:
		_g(image, x, 22, 0.24)
		_g(image, x, 23, 0.62)
		if x % 4 < 2:
			_g(image, x, 19, 0.72)
			_g(image, x, 26, 0.72)
	return image


## Studded leather: rows of rivets.
func _gear_studded() -> Image:
	var image := _grain(0.4, 0.14)
	for row in 4:
		for col in 4:
			var cx := col * 8 + (4 if row % 2 == 1 else 0) + 2
			var cy := row * 8 + 3
			_g(image, cx, cy, 0.85)
			_g(image, cx + 1, cy, 0.7)
			_g(image, cx, cy + 1, 0.7)
			_g(image, cx + 1, cy + 1, 0.4)
			_g(image, cx + 2, cy + 1, 0.3)
			_g(image, cx + 1, cy + 2, 0.3)
	return image


## Tooled leather: panels with stitched borders and a pressed line.
func _gear_tooled() -> Image:
	var image := _grain(0.4, 0.12)
	for i in GEAR:
		_g(image, i, 0, 0.3)
		_g(image, 0, i, 0.3)
		if i % 3 == 1:
			_g(image, i, 2, 0.68)
			_g(image, 2, i, 0.68)
	for i in range(6, 26):
		_g(image, i, 16 + int(4.0 * sin(i * 0.5)), 0.38)
	return image


## Chain mail: rows of rings, each row offset.
func _gear_chain() -> Image:
	var image := _gear(0.3)
	for row in 8:
		for col in 8:
			var cx := col * 4 + (2 if row % 2 == 1 else 0)
			var cy := row * 4
			for p in [[1, 0, 0.78], [2, 0, 0.7], [0, 1, 0.72], [3, 1, 0.55], [0, 2, 0.6], [3, 2, 0.45], [1, 3, 0.48], [2, 3, 0.42]]:
				_g(image, cx + p[0], cy + p[1], p[2])
	return image


## Scale mail: overlapping rounded scales, lit at the top.
func _gear_scale() -> Image:
	var image := _gear()
	for y in GEAR:
		for x in GEAR:
			var row := y / 6
			var cx := posmod(x + (4 if row % 2 == 1 else 0), 8)
			var cy := posmod(y, 6)
			var d := absi(cx - 4)
			var v := 0.62 - cy * 0.04 - d * 0.02
			if cy == 5 - d / 2 or d == 4:
				v = 0.28
			_g(image, x, y, v)
	return image


## Plate: broad smooth panels, a seam with rivets, a soft highlight.
func _gear_plate() -> Image:
	var image := _grain(0.08, 0.05)
	for y in GEAR:
		for x in GEAR:
			var v := _at(image, x, y).r + 0.08 * cos(x * TAU / GEAR)
			_g(image, x, y, v)
	for x in GEAR:
		_g(image, x, 0, 0.25)
		_g(image, x, 1, 0.68)
	for x in [4, 12, 20, 28]:
		_g(image, x, 4, 0.85)
		_g(image, x + 1, 5, 0.3)
	return image


## Banded plate: overlapping horizontal lames.
func _gear_banded() -> Image:
	var image := _grain(0.06, 0.05)
	for y in GEAR:
		var band := posmod(y, 8)
		for x in GEAR:
			var v := _at(image, x, y).r + 0.12 - band * 0.03
			if band == 7:
				v = 0.22
			elif band == 0:
				v = 0.75
			_g(image, x, y, v)
	for x in [3, 19]:
		for row in 4:
			_g(image, x, row * 8 + 3, 0.85)
	return image


## Wood: grain running along (V).
func _gear_wood() -> Image:
	var image := _gear()
	var values := _noise(GEAR, 0.08)
	for y in GEAR:
		for x in GEAR:
			var w := fposmod(x * 0.45 + values[y * GEAR + x] * 5.0, 2.0)
			_g(image, x, y, 0.52 - (0.12 if w < 0.4 else 0.0) + _rng.randf_range(-0.02, 0.02))
	_g(image, 9, 14, 0.25)
	_g(image, 10, 14, 0.3)
	_g(image, 9, 15, 0.3)
	return image


## Planks: boards across, nailed.
func _gear_planks() -> Image:
	var image := _gear_wood()
	for x in GEAR:
		for y in GEAR:
			if x % 11 == 10:
				_g(image, x, y, 0.22)
	for x in [3, 14, 25]:
		_g(image, x, 6, 0.8)
		_g(image, x, 25, 0.8)
	return image


## A grip's wrapping: diagonal bands.
func _gear_wrap() -> Image:
	var image := _gear()
	for y in GEAR:
		for x in GEAR:
			var band := posmod(x + y, 8)
			_g(image, x, y, 0.62 - band * 0.035 if band < 7 else 0.25)
	return image


## Brushed metal: fine streaks along (V).
func _gear_brushed() -> Image:
	var image := _gear()
	for x in GEAR:
		var streak := _rng.randf_range(-0.07, 0.07)
		for y in GEAR:
			_g(image, x, y, 0.52 + streak + _rng.randf_range(-0.02, 0.02))
	return image


## Hammered metal: dimples.
func _gear_hammered() -> Image:
	var image := _grain(0.06, 0.06)
	for i in 14:
		var cx := _rng.randi_range(0, GEAR - 1)
		var cy := _rng.randi_range(0, GEAR - 1)
		_g(image, cx, cy, 0.36)
		_g(image, cx + 1, cy, 0.42)
		_g(image, cx - 1, cy - 1, 0.66)
	return image
