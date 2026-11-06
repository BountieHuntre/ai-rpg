class_name IconPainter
extends Node2D
## Paints the game's icons: square pictures in a painted style, each on its
## own shaded, speckled background with a bevelled edge and a dark vignette,
## as the game's spells and items show them. Everything is drawn in a 256 by
## 256 space (the bake renders it larger and shrinks it, which smooths the
## edges). A key is "design" or "design_variant": the design draws the
## picture and the variant picks its colors (a red potion, a mail chest, a
## Boon of Clarity). tools/icons/bake_icons.gd renders every key Icons uses
## into assets/icons/.

const S := 256.0
const C := Vector2(128, 128)
const OUT := Color(0.06, 0.05, 0.04)

## The key drawn next.
var key := "unknown"
var _rng := RandomNumberGenerator.new()


func _draw() -> void:
	_rng.seed = hash(key)
	var parts := key.split("_", true, 1)
	var design := parts[0]
	var variant := parts[1] if parts.size() > 1 else ""
	var method := "_d_" + design
	if has_method(method):
		call(method, variant)
	else:
		_d_unknown(variant)
	_finish()


# Colors.

## Background colors by mood: [center, edge].
const BG := {
	"red": [Color("7a2a20"), Color("1a0706")], "blue": [Color("2a4a7a"), Color("070c1a")],
	"green": [Color("2e5a2a"), Color("061006")], "gold": [Color("7a6224"), Color("150f04")],
	"purple": [Color("4a2a62"), Color("0c0612")], "grey": [Color("4a4a50"), Color("0c0c0e")],
	"brown": [Color("5a3e22"), Color("120a04")], "teal": [Color("1e5a5a"), Color("041212")],
	"orange": [Color("7a3a10"), Color("1a0802")], "dark": [Color("2a2430"), Color("060508")],
	"white": [Color("8a8a7a"), Color("1a1a16")], "sky": [Color("3a6a8a"), Color("08141c")],
}
const METALS := {
	"steel": [Color("e8edf2"), Color("9aa3ad"), Color("4b525a")],
	"iron": [Color("b8bcc2"), Color("70767e"), Color("34383e")],
	"bronze": [Color("f0c890"), Color("b07a40"), Color("5a3a18")],
	"gold": [Color("fff0a8"), Color("d8aa40"), Color("6a4a10")],
	"dark": [Color("8a8090"), Color("4a4250"), Color("1a161e")],
	"rust": [Color("c8a080"), Color("8a5a3a"), Color("3a2414")],
}
const CLOTHS := [Color("8a3a2a"), Color("3a5a8a"), Color("4a6a3a"), Color("6a4a7a"), Color("8a7a5a"), Color("5a5a5a"), Color("7a6a3a"), Color("2a4a4a")]
const GEMS := { "poor": Color("8a8a8a"), "common": Color("e8e8e8"), "uncommon": Color("3ad83a"), "rare": Color("3a8aff"), "epic": Color("b84aff") }


func _metal(name: String) -> Array:
	return METALS.get(name, METALS.steel)


func _cloth() -> Color:
	return CLOTHS[_rng.randi() % CLOTHS.size()]


# Drawing pieces.

func _bg(mood: String) -> void:
	var colors: Array = BG.get(mood, BG.grey)
	draw_rect(Rect2(0, 0, S, S), colors[1])
	var steps := 28
	for i in steps:
		var t := float(i) / steps
		draw_circle(Vector2(112, 100), lerpf(190.0, 8.0, t), (colors[1] as Color).lerp(colors[0], ease(t, 0.6)))
	for i in 900:
		var shade := _rng.randf()
		draw_rect(Rect2(_rng.randf() * S, _rng.randf() * S, 2, 2), Color(shade, shade, shade, 0.05))


## The bevelled edge and dark vignette every icon has.
func _finish() -> void:
	for i in 14:
		var r := 150.0 + i * 6.0
		draw_arc(C, r, 0, TAU, 64, Color(0, 0, 0, 0.06 + i * 0.02), 8.0)
	draw_rect(Rect2(0, 0, S, 5), Color(1, 0.95, 0.8, 0.22))
	draw_rect(Rect2(0, 0, 5, S), Color(1, 0.95, 0.8, 0.16))
	draw_rect(Rect2(0, S - 5, S, 5), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(S - 5, 0, 5, S), Color(0, 0, 0, 0.5))


func _at(origin: Vector2, angle := 0.0, scale := 1.0) -> void:
	draw_set_transform(origin, angle, Vector2.ONE * scale)


func _reset() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A polygon shaded along a direction (degrees, 90 = top to bottom) through
## the listed colors, with an outline.
func _fill(points: PackedVector2Array, colors: Array, angle := 90.0, outline := true, width := 4.0) -> void:
	var direction := Vector2.from_angle(deg_to_rad(angle))
	var low := INF
	var high := -INF
	for p in points:
		low = minf(low, p.dot(direction))
		high = maxf(high, p.dot(direction))
	var vertex_colors := PackedColorArray()
	for p in points:
		var t := (p.dot(direction) - low) / maxf(high - low, 0.001)
		vertex_colors.append(_gradient(colors, t))
	draw_polygon(points, vertex_colors)
	if outline:
		_outline(points, OUT, width)


func _gradient(colors: Array, t: float) -> Color:
	if colors.size() == 1:
		return colors[0]
	var scaled := clampf(t, 0, 1) * (colors.size() - 1)
	var i := mini(int(scaled), colors.size() - 2)
	return (colors[i] as Color).lerp(colors[i + 1], scaled - i)


func _outline(points: PackedVector2Array, color: Color, width := 4.0) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width, true)


func _pts(flat: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, flat.size(), 2):
		out.append(Vector2(flat[i], flat[i + 1]))
	return out


## A disc shaded from a light center to a dark rim.
func _ball(center: Vector2, radius: float, light: Color, dark: Color, outline := true) -> void:
	var steps := 16
	if outline:
		draw_circle(center, radius + 3, OUT)
	for i in steps:
		var t := float(i) / steps
		draw_circle(center + Vector2(-radius, -radius) * 0.25 * t, radius * (1.0 - t * 0.85), dark.lerp(light, t))


func _glow(center: Vector2, radius: float, color: Color, strength := 1.0) -> void:
	var steps := 18
	for i in steps:
		var t := float(i) / steps
		draw_circle(center, radius * (1.0 - t), Color(color.r, color.g, color.b, color.a * 0.09 * strength))


func _rays(center: Vector2, inner: float, outer: float, count: int, color: Color, width := 10.0, turn := 0.0) -> void:
	for i in count:
		var a := TAU * i / count + turn
		var dir := Vector2.from_angle(a)
		var side := dir.orthogonal() * width * 0.5
		draw_colored_polygon(PackedVector2Array([center + dir * inner + side, center + dir * outer, center + dir * inner - side]), color)


func _star(center: Vector2, outer: float, inner: float, points: int, color: Color, turn := -PI / 2) -> void:
	var shape := PackedVector2Array()
	for i in points * 2:
		var r := outer if i % 2 == 0 else inner
		shape.append(center + Vector2.from_angle(turn + PI * i / points) * r)
	draw_colored_polygon(shape, color)


## A teardrop: its point up, its round end at the bottom (flames, blood,
## water, poison).
func _drop(center: Vector2, size: float, colors: Array) -> void:
	var shape := PackedVector2Array()
	shape.append(center + Vector2(0, -size * 1.7))
	var round_center := center + Vector2(0, size * 0.2)
	for i in 21:
		var a := -0.45 + (PI + 0.9) * i / 20.0
		shape.append(round_center + Vector2(cos(a), sin(a)) * size)
	_fill(shape, colors, 120.0)


func _shine(at: Vector2, size: Vector2, angle := -0.6) -> void:
	_at(at, angle)
	draw_colored_polygon(_ellipse(Vector2.ZERO, size), Color(1, 1, 1, 0.45))
	_reset()


func _ellipse(center: Vector2, radii: Vector2, count := 24) -> PackedVector2Array:
	var shape := PackedVector2Array()
	for i in count:
		var a := TAU * i / count
		shape.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return shape


func _line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	draw_line(a, b, color, width, true)


## A blade from base to tip: steel shaded across its width, a fuller down the
## middle, outlined.
func _blade(base: Vector2, tip: Vector2, width: float, metal: Array, point := 0.18) -> void:
	var dir := (tip - base).normalized()
	var side := dir.orthogonal() * width * 0.5
	var length := base.distance_to(tip)
	var shoulder := tip - dir * length * point
	var shape := PackedVector2Array([base + side, shoulder + side, tip, shoulder - side, base - side])
	var angle := rad_to_deg(side.angle())
	_fill(shape, [metal[0], metal[1], metal[2]], angle)
	_line(base + dir * 6, shoulder, Color(0, 0, 0, 0.35), width * 0.18)
	_line(base + side * 0.6 + dir * 4, shoulder + side * 0.6, Color(1, 1, 1, 0.35), 3)


func _bar(a: Vector2, b: Vector2, width: float, colors: Array) -> void:
	var dir := (b - a).normalized()
	var side := dir.orthogonal() * width * 0.5
	_fill(PackedVector2Array([a + side, b + side, b - side, a - side]), colors, rad_to_deg(side.angle()))


## A wrapped grip from a to b.
func _grip(a: Vector2, b: Vector2, width: float) -> void:
	_bar(a, b, width, [Color("8a5a2a"), Color("4a2a10"), Color("2a1606")])
	var dir := (b - a).normalized()
	var side := dir.orthogonal() * width * 0.5
	var length := a.distance_to(b)
	var count := int(length / 9.0)
	for i in count:
		var p := a + dir * (i + 0.5) * length / count
		_line(p - side, p + side + dir * 5, Color(0, 0, 0, 0.45), 2.5)


func _gem(center: Vector2, radius: float, color: Color) -> void:
	_ball(center, radius, color.lightened(0.6), color.darkened(0.5))
	draw_circle(center + Vector2(-radius, -radius) * 0.35, radius * 0.28, Color(1, 1, 1, 0.8))


# Designs: weapons.

func _d_sword(v: String) -> void:
	_bg("red" if v != "poor" else "grey")
	var metal := _metal("rust" if v == "poor" else "steel")
	_blade(Vector2(86, 170), Vector2(212, 44), 26, metal)
	_bar(Vector2(58, 152), Vector2(104, 198), 14, _metal("gold" if v in ["rare", "epic"] else "bronze"))
	_grip(Vector2(80, 176), Vector2(46, 210), 13)
	_gem(Vector2(40, 216), 11, GEMS.get(v, Color("c0303a")))


func _d_greatsword(v: String) -> void:
	_bg("red" if v != "poor" else "grey")
	var metal := _metal("rust" if v == "poor" else "steel")
	_blade(Vector2(78, 178), Vector2(226, 30), 34, metal, 0.12)
	_fill(_pts([44, 160, 60, 144, 112, 196, 96, 212]), _metal("dark"), 45)
	_grip(Vector2(70, 186), Vector2(30, 226), 15)
	_gem(Vector2(28, 228), 10, GEMS.get(v, Color("c0303a")))


func _axe_head(at: Vector2, size: float, metal: Array) -> void:
	_at(at, 0.0, size)
	_fill(_pts([0, -10, 34, -46, 52, -20, 56, 18, 40, 46, 0, 12]), metal, 0.0)
	_line(Vector2(40, -40), Vector2(54, 16), Color(1, 1, 1, 0.5), 4)
	_reset()


func _d_axe(v: String) -> void:
	_bg("orange" if v != "poor" else "grey")
	_bar(Vector2(70, 214), Vector2(170, 58), 16, [Color("9a6a3a"), Color("5a3a1a"), Color("2a180a")])
	_axe_head(Vector2(150, 76), 1.4, _metal("rust" if v == "poor" else "steel"))
	_grip(Vector2(84, 192), Vector2(66, 220), 16)


func _d_greataxe(v: String) -> void:
	_bg("orange" if v != "poor" else "grey")
	_bar(Vector2(52, 228), Vector2(176, 38), 18, [Color("9a6a3a"), Color("5a3a1a"), Color("2a180a")])
	_axe_head(Vector2(158, 62), 1.7, _metal("rust" if v == "poor" else "steel"))
	_at(Vector2(150, 74), PI, 1.3)
	_fill(_pts([0, -10, 34, -46, 52, -20, 56, 18, 40, 46, 0, 12]), _metal("steel"), 0.0)
	_reset()


func _d_mace(v: String) -> void:
	_bg("brown" if v != "poor" else "grey")
	_bar(Vector2(70, 214), Vector2(150, 96), 16, [Color("9a6a3a"), Color("5a3a1a"), Color("2a180a")])
	var head := Vector2(162, 80)
	var metal := _metal("rust" if v == "poor" else "iron")
	for i in 6:
		var dir := Vector2.from_angle(TAU * i / 6 + 0.3)
		_fill(PackedVector2Array([head + dir.orthogonal() * 10, head + dir * 56, head - dir.orthogonal() * 10]), metal, rad_to_deg(dir.angle()) + 90)
	_ball(head, 34, metal[0], metal[2])


func _d_maul(v: String) -> void:
	_bg("brown" if v != "poor" else "grey")
	_bar(Vector2(56, 226), Vector2(150, 92), 18, [Color("9a6a3a"), Color("5a3a1a"), Color("2a180a")])
	_at(Vector2(160, 76), -0.95)
	_fill(_pts([-56, -34, 56, -34, 62, 34, -62, 34]), _metal("rust" if v == "poor" else "iron"), 90)
	draw_rect(Rect2(-56, -6, 112, 12), Color(0, 0, 0, 0.3))
	_reset()


func _d_dagger(v: String) -> void:
	_bg("dark" if v != "poor" else "grey")
	_blade(Vector2(104, 152), Vector2(196, 60), 24, _metal("rust" if v == "poor" else "steel"), 0.3)
	_bar(Vector2(82, 136), Vector2(120, 174), 12, _metal("bronze"))
	_grip(Vector2(98, 158), Vector2(68, 190), 12)
	_gem(Vector2(62, 196), 9, GEMS.get(v, Color("3a8ad8")))


func _d_staff(v: String) -> void:
	_bg("purple" if v != "poor" else "brown")
	_bar(Vector2(52, 230), Vector2(178, 58), 15, [Color("a07a4a"), Color("6a4a22"), Color("34200c")])
	for i in 3:
		var p := Vector2(178, 58).lerp(Vector2(52, 230), 0.25 + i * 0.22)
		_line(p + Vector2(-10, -8), p + Vector2(10, 8), Color("2a180a"), 5)
	_glow(Vector2(186, 48), 70, Color(GEMS.get(v, Color("8a6aff"))), 1.4)
	_gem(Vector2(186, 48), 20, GEMS.get(v, Color("8a6aff")))


func _d_polearm(v: String) -> void:
	_bg("grey")
	_bar(Vector2(40, 236), Vector2(174, 70), 13, [Color("9a6a3a"), Color("5a3a1a"), Color("2a180a")])
	_blade(Vector2(166, 80), Vector2(226, 22), 26, _metal("rust" if v == "poor" else "steel"), 0.4)
	_axe_head(Vector2(158, 92), 0.9, _metal("steel"))


func _d_bow(v: String) -> void:
	_bg("green" if v != "poor" else "grey")
	var limb := PackedVector2Array()
	for i in 21:
		var t := float(i) / 20.0
		limb.append(Vector2(60, 200).lerp(Vector2(200, 56), t) + Vector2(-1, -1).normalized() * sin(t * PI) * 58)
	draw_polyline(limb, OUT, 20, true)
	draw_polyline(limb, Color("8a5a2a"), 13, true)
	draw_polyline(limb, Color("c08a4a"), 5, true)
	_line(Vector2(60, 200), Vector2(200, 56), Color("e8e0c8"), 3)
	_grip(Vector2(104, 112), Vector2(120, 96), 18)


func _d_crossbow(v: String) -> void:
	_bg("brown")
	_bar(Vector2(64, 200), Vector2(184, 80), 22, [Color("9a6a3a"), Color("5a3a1a"), Color("2a180a")])
	var limb := PackedVector2Array()
	for i in 17:
		var t := float(i) / 16.0
		limb.append(Vector2(110, 54).lerp(Vector2(210, 154), t) + Vector2(1, -1).normalized() * sin(t * PI) * 28)
	draw_polyline(limb, OUT, 16, true)
	draw_polyline(limb, Color("70767e"), 9, true)
	_line(Vector2(110, 54), Vector2(210, 154), Color("e8e0c8"), 3)


func _d_gun(v: String) -> void:
	_bg("brown")
	_fill(_pts([40, 170, 90, 120, 120, 150, 70, 206]), [Color("9a6a3a"), Color("4a2a10")], 45)
	_bar(Vector2(96, 140), Vector2(222, 58), 20, _metal("iron"))
	draw_circle(Vector2(118, 150), 12, Color("4a4250"))


func _d_wand(v: String) -> void:
	_bg("purple")
	_bar(Vector2(70, 196), Vector2(180, 78), 12, [Color("e8d8b8"), Color("a08a60"), Color("4a3a20")])
	_glow(Vector2(182, 74), 60, Color("c08aff"), 1.5)
	_star(Vector2(182, 74), 26, 10, 4, Color("fff0ff"))


# Designs: armor.

func _material_colors(v: String) -> Array:
	if v.begins_with("cloth"):
		var c := _cloth()
		return [c.lightened(0.35), c, c.darkened(0.55)]
	if v.begins_with("leather"):
		return [Color("b0804a"), Color("6a4422"), Color("2a1a0a")]
	if v.begins_with("mail"):
		return _metal("iron")
	if v.begins_with("plate"):
		return _metal("steel")
	return _metal("bronze")


func _mood(v: String) -> String:
	if v.begins_with("cloth"):
		return "purple"
	if v.begins_with("leather"):
		return "brown"
	if v.begins_with("mail"):
		return "teal"
	if v.begins_with("plate"):
		return "blue"
	return "grey"


## Rings for mail, rivets for plate, stitching for leather and cloth.
func _texture(points: PackedVector2Array, v: String, area: Rect2) -> void:
	if v.begins_with("mail"):
		for y in range(int(area.position.y), int(area.end.y), 9):
			for x in range(int(area.position.x), int(area.end.x), 10):
				if Geometry2D.is_point_in_polygon(Vector2(x + 5, y + 4), points):
					draw_arc(Vector2(x + (5 if (y / 9) % 2 == 0 else 0), y + 4), 4, 0, TAU, 8, Color(0, 0, 0, 0.35), 1.5)
	elif v.begins_with("plate"):
		_line(Vector2(area.get_center().x, area.position.y + 8), Vector2(area.get_center().x, area.end.y - 8), Color(1, 1, 1, 0.3), 4)
	elif v.begins_with("leather") or v.begins_with("cloth"):
		var inset := area.grow(-12)
		for i in range(0, 12):
			var x := inset.position.x + inset.size.x * i / 12.0
			draw_rect(Rect2(x, inset.position.y, 4, 2), Color(1, 0.9, 0.7, 0.25))


func _trim(v: String) -> Array:
	return _metal("gold") if v.ends_with("rare") or v.ends_with("epic") else _metal("bronze")


func _d_helm(v: String) -> void:
	_bg(_mood(v))
	var shape := _pts([60, 200, 60, 110, 90, 60, 128, 46, 166, 60, 196, 110, 196, 200, 160, 200, 160, 140, 96, 140, 96, 200])
	if v.begins_with("cloth"):
		shape = _pts([56, 180, 70, 100, 128, 42, 186, 100, 200, 180, 128, 196])
	_fill(shape, _material_colors(v), 20)
	_texture(shape, v, Rect2(56, 42, 144, 160))
	if not v.begins_with("cloth"):
		draw_rect(Rect2(96, 118, 64, 12), Color(0.02, 0.02, 0.03))
		_bar(Vector2(128, 50), Vector2(128, 130), 10, _trim(v))


func _d_shoulders(v: String) -> void:
	_bg(_mood(v))
	for side in [-1, 1]:
		var shape := PackedVector2Array()
		for i in 13:
			var a := PI + PI * i / 12.0
			shape.append(Vector2(128 + side * 56, 132) + Vector2(cos(a) * 52, sin(a) * 60))
		shape.append(Vector2(128 + side * 56 + 52, 168))
		shape.append(Vector2(128 + side * 56 - 52, 168))
		_fill(shape, _material_colors(v), 60)
		_texture(shape, v, Rect2(128 + side * 56 - 52, 72, 104, 96))
		_bar(Vector2(128 + side * 56 - 50, 160), Vector2(128 + side * 56 + 50, 160), 10, _trim(v))


func _d_chest(v: String) -> void:
	_bg(_mood(v))
	var shape := _pts([70, 52, 104, 40, 128, 62, 152, 40, 186, 52, 222, 96, 196, 120, 186, 104, 186, 218, 70, 218, 70, 104, 60, 120, 34, 96])
	if v.begins_with("cloth"):
		shape = _pts([80, 46, 128, 66, 176, 46, 214, 110, 192, 122, 196, 226, 60, 226, 64, 122, 42, 110])
	_fill(shape, _material_colors(v), 30)
	_texture(shape, v, Rect2(40, 40, 180, 186))
	_bar(Vector2(72, 196), Vector2(184, 196), 12, _trim(v) if not v.begins_with("cloth") else [Color("4a3a2a"), Color("2a1a0a")])


func _d_gloves(v: String) -> void:
	_bg(_mood(v))
	var shape := _pts([86, 216, 80, 130, 70, 92, 90, 86, 100, 116, 100, 56, 118, 52, 122, 110, 128, 48, 146, 46, 148, 110, 156, 56, 174, 60, 172, 120, 180, 76, 196, 84, 186, 160, 170, 216])
	_fill(shape, _material_colors(v), 20)
	_texture(shape, v, Rect2(70, 46, 126, 170))
	_bar(Vector2(84, 200), Vector2(172, 200), 18, _trim(v) if not v.begins_with("cloth") else _material_colors(v))


func _d_boots(v: String) -> void:
	_bg(_mood(v))
	var shape := _pts([88, 40, 160, 40, 158, 160, 214, 186, 214, 220, 84, 220, 90, 140])
	_fill(shape, _material_colors(v), 30)
	_texture(shape, v, Rect2(84, 40, 130, 180))
	_bar(Vector2(86, 58), Vector2(162, 58), 16, _trim(v) if not v.begins_with("cloth") else _material_colors(v))
	_line(Vector2(86, 210), Vector2(212, 210), OUT, 8)


func _d_legs(v: String) -> void:
	_bg(_mood(v))
	var shape := _pts([70, 40, 186, 40, 196, 220, 146, 220, 128, 100, 110, 220, 60, 220])
	_fill(shape, _material_colors(v), 20)
	_texture(shape, v, Rect2(60, 40, 136, 180))
	_bar(Vector2(70, 50), Vector2(186, 50), 16, _trim(v) if not v.begins_with("cloth") else [Color("4a3a2a"), Color("2a1a0a")])


func _d_belt(v: String) -> void:
	_bg(_mood(v))
	_fill(_pts([24, 110, 232, 104, 232, 152, 24, 158]), _material_colors(v) if not v.begins_with("mail") else [Color("8a5a2a"), Color("3a2410")], 90)
	_fill(_pts([100, 92, 156, 90, 160, 168, 98, 170]), _trim(v), 30)
	draw_rect(Rect2(114, 106, 30, 46), _material_colors(v)[1])


func _d_bracers(v: String) -> void:
	_bg(_mood(v))
	for i in 2:
		var x := 70.0 + i * 70.0
		var shape := _pts([x, 50, x + 54, 46, x + 64, 210, x - 6, 214])
		_fill(shape, _material_colors(v), 0)
		_texture(shape, v, Rect2(x - 6, 46, 70, 168))
		_bar(Vector2(x - 2, 74), Vector2(x + 58, 72), 10, _trim(v))
		_bar(Vector2(x - 4, 190), Vector2(x + 62, 188), 10, _trim(v))


func _d_cloak(v: String) -> void:
	_bg("dark")
	var c := _cloth()
	var shape := _pts([96, 40, 160, 40, 176, 60, 220, 220, 180, 210, 150, 226, 116, 210, 76, 226, 36, 220, 80, 60])
	_fill(shape, [c.lightened(0.3), c, c.darkened(0.6)], 0)
	for x in [104, 128, 152]:
		_line(Vector2(x, 70), Vector2(x + (x - 128) * 0.8, 214), Color(0, 0, 0, 0.3), 5)
	_gem(Vector2(128, 50), 12, Color("d8aa40"))


func _d_shield(v: String) -> void:
	_bg("blue")
	var shape := PackedVector2Array()
	shape.append(Vector2(52, 50))
	shape.append(Vector2(204, 50))
	for i in 13:
		var t := float(i) / 12.0
		shape.append(Vector2(204, 50).lerp(Vector2(128, 226), t) + Vector2(sin(t * PI) * 18, 0))
	for i in 13:
		var t := float(i) / 12.0
		shape.append(Vector2(128, 226).lerp(Vector2(52, 50), t) - Vector2(sin(t * PI) * 18, 0))
	var field := [Color("c8402a"), Color("8a1a14"), Color("3a0a08")]
	if v.begins_with("poor") or v == "wood":
		field = [Color("a07a4a"), Color("6a4a22"), Color("34200c")]
	_fill(shape, field, 45, false)
	_outline(shape, _trim(v)[1], 12)
	_outline(shape, OUT, 4)
	_bar(Vector2(128, 62), Vector2(128, 206), 14, _trim(v))
	_bar(Vector2(70, 110), Vector2(186, 110), 14, _trim(v))
	_shine(Vector2(92, 90), Vector2(20, 44))


func _d_ring(v: String) -> void:
	_bg("purple")
	draw_arc(Vector2(128, 150), 58, 0, TAU, 48, OUT, 30)
	for i in 4:
		draw_arc(Vector2(128, 150), 58, 0, TAU, 48, _gradient(_metal("gold"), float(i) / 3.0), 22 - i * 5)
	_gem(Vector2(128, 88), 26, GEMS.get(v, Color("3a8aff")))


func _d_amulet(v: String) -> void:
	_bg("purple")
	var chain := PackedVector2Array()
	for i in 21:
		var a := PI * i / 20.0
		chain.append(Vector2(128 + cos(a) * 76, 110 - sin(a) * 70))
	draw_polyline(chain, Color("d8aa40"), 6, true)
	_fill(_pts([128, 120, 176, 156, 128, 226, 80, 156]), _metal("gold"), 30)
	_gem(Vector2(128, 166), 22, GEMS.get(v, Color("c0303a")))


func _d_trinket(v: String) -> void:
	_bg("gold")
	_ball(C, 64, Color("fff0a8"), Color("6a4a10"))
	_star(C, 40, 16, 6, Color(1, 1, 1, 0.6))


func _d_orb(v: String) -> void:
	_bg("purple")
	_glow(C, 110, Color("b88aff"), 1.2)
	_ball(C, 58, Color("e0c8ff"), Color("3a1a6a"))
	_shine(Vector2(108, 104), Vector2(14, 26))


func _d_shirt(v: String) -> void:
	_d_chest("cloth")


# Designs: consumables and goods.

func _d_potion(v: String) -> void:
	var colors := { "red": [Color("ff7a6a"), Color("c8202a"), Color("4a0a0a")], "blue": [Color("8ac8ff"), Color("2a5ad8"), Color("0a1a4a")], "green": [Color("aef07a"), Color("3aa82a"), Color("0e4a0e")], "purple": [Color("e0a0ff"), Color("8a3ad8"), Color("2a0a4a")] }
	var liquid: Array = colors.get(v, colors.red)
	_bg({ "red": "red", "blue": "blue", "green": "green", "purple": "purple" }.get(v, "red"))
	_fill(_pts([112, 30, 144, 30, 144, 58, 112, 58]), [Color("a07a4a"), Color("5a3a1a")], 0)
	_fill(_pts([108, 58, 148, 58, 146, 96, 110, 96]), [Color(0.85, 0.92, 0.95, 0.5), Color(0.6, 0.7, 0.75, 0.5)], 0)
	draw_circle(Vector2(128, 160), 72, OUT)
	draw_circle(Vector2(128, 160), 68, Color(0.75, 0.85, 0.9, 0.35))
	var surface := 130.0
	var body := PackedVector2Array()
	for i in 33:
		var a := -0.25 * PI + 1.5 * PI * i / 32.0
		var p := Vector2(128, 160) + Vector2.from_angle(a + PI / 2) * 64
		body.append(Vector2(p.x, maxf(p.y, surface)) if p.y < surface else p)
	_fill(body, liquid, 90, false)
	for i in 6:
		draw_circle(Vector2(96 + i * 13, 180 + (i % 2) * 18), 4, Color(1, 1, 1, 0.35))
	_shine(Vector2(98, 140), Vector2(12, 30))


func _d_bread(v: String) -> void:
	_bg("brown")
	_fill(_ellipse(Vector2(128, 140), Vector2(92, 58)), [Color("f6c878"), Color("c07a30"), Color("6a3a10")], 90)
	for i in 4:
		_line(Vector2(76 + i * 32, 104), Vector2(100 + i * 32, 140), Color(1, 0.92, 0.7, 0.8), 7)


func _d_meat(v: String) -> void:
	_bg("red")
	_bar(Vector2(60, 196), Vector2(110, 146), 22, [Color("f4ecd8"), Color("c8bca0"), Color("6a6250")])
	draw_circle(Vector2(54, 202), 16, Color("f4ecd8"))
	var raw := v == "raw"
	_ball(Vector2(150, 108), 70, Color("e88a6a") if raw else Color("d08a4a"), Color("6a1a14") if raw else Color("4a2008"))
	if not raw:
		for i in 3:
			_line(Vector2(112 + i * 26, 80), Vector2(132 + i * 26, 130), Color(0.3, 0.12, 0.04, 0.6), 6)


func _d_cheese(v: String) -> void:
	_bg("gold")
	_fill(_pts([40, 170, 196, 90, 220, 120, 220, 190, 40, 210]), [Color("fff0a0"), Color("e8c040"), Color("8a6a10")], 60)
	for p in [Vector2(110, 168), Vector2(170, 150), Vector2(150, 184), Vector2(196, 130)]:
		draw_circle(p, 10, Color("b08a20"))


func _d_fruit(v: String) -> void:
	_bg("green" if v == "melon" else "red")
	var colors := [Color("ff8a6a"), Color("c8202a"), Color("4a0a0a")]
	if v == "melon":
		colors = [Color("c8f08a"), Color("4a9a2a"), Color("143a0a")]
	elif v == "pumpkin":
		colors = [Color("ffc06a"), Color("e07a10"), Color("5a2a04")]
	_ball(Vector2(128, 140), 72, colors[0], colors[2])
	_bar(Vector2(128, 72), Vector2(138, 40), 10, [Color("7a5a2a"), Color("3a2a10")])
	_fill(_pts([140, 58, 186, 40, 170, 70]), [Color("7ad84a"), Color("2a6a14")], 90)
	_shine(Vector2(98, 112), Vector2(14, 26))


func _d_fish(v: String) -> void:
	_bg("sky")
	_fill(_pts([36, 128, 80, 82, 160, 76, 206, 128, 160, 180, 80, 174]), [Color("c8e0f0"), Color("6a8aa8"), Color("2a3a4a")], 90)
	_fill(_pts([200, 128, 238, 88, 238, 168]), [Color("8aa8c0"), Color("3a4a5a")], 90)
	draw_circle(Vector2(70, 116), 9, Color.WHITE)
	draw_circle(Vector2(70, 116), 5, OUT)


func _d_mushroom(v: String) -> void:
	_bg("green")
	_fill(_pts([110, 130, 146, 130, 152, 220, 104, 220]), [Color("f4ecd8"), Color("b8ac90")], 0)
	var cap := PackedVector2Array()
	for i in 25:
		var a := PI + PI * i / 24.0
		cap.append(Vector2(128, 136) + Vector2(cos(a) * 90, sin(a) * 76))
	_fill(cap, [Color("ff6a5a"), Color("b81a14"), Color("4a0806")] if v != "brown" else [Color("d8a070"), Color("8a5a2a"), Color("3a2410")], 90)
	if v != "brown":
		for p in [Vector2(98, 100), Vector2(140, 84), Vector2(170, 112), Vector2(120, 120)]:
			draw_circle(p, 10, Color("f8f0e0"))


func _d_flask(v: String) -> void:
	var liquid: Color = { "water": Color("7ab8f0"), "milk": Color("f4f4ec"), "juice": Color("f0a030"), "berry": Color("8a2a6a") }.get(v, Color("7ab8f0"))
	_bg("sky")
	_fill(_pts([84, 70, 172, 70, 192, 120, 192, 214, 64, 214, 64, 120]), [Color("c8a070"), Color("7a5a30"), Color("3a2410")], 0)
	_fill(_pts([110, 34, 146, 34, 150, 72, 106, 72]), [Color("8a6a3a"), Color("4a3418")], 0)
	draw_rect(Rect2(76, 130, 104, 50), liquid.darkened(0.2))
	draw_rect(Rect2(76, 130, 104, 10), liquid.lightened(0.3))


func _d_scroll(v: String) -> void:
	var seal: Color = { "strength": Color("c8302a"), "agility": Color("e0a020"), "intellect": Color("3a6ad8"), "spirit": Color("8ad8f0"), "stamina": Color("4a9a2a"), "protection": Color("a8a8a8") }.get(v, Color("9a1a14"))
	_bg("brown")
	_at(C, -0.35)
	_fill(_pts([-56, -74, 56, -74, 56, 74, -56, 74]), [Color("f6e8c0"), Color("dcc48c"), Color("a88a50")], 90)
	for y in [-74.0, 74.0]:
		_fill(_ellipse(Vector2(0, y), Vector2(64, 16)), [Color("c0904a"), Color("6a4a20")], 90)
	for i in 6:
		_line(Vector2(-36, -42 + i * 16), Vector2(36, -42 + i * 16), Color(0.3, 0.2, 0.1, 0.55), 3)
	_ball(Vector2(28, 50), 18, seal.lightened(0.3), seal.darkened(0.5))
	_reset()


func _d_paper(v: String) -> void:
	_bg("brown")
	_at(C, 0.15)
	_fill(_pts([-70, -86, 66, -92, 72, 88, -64, 92]), [Color("f6ecd0"), Color("d8c494"), Color("a08a58")], 120)
	for i in 8:
		_line(Vector2(-48, -60 + i * 16), Vector2(48 - (i % 3) * 14, -62 + i * 16), Color(0.25, 0.18, 0.1, 0.6), 3)
	if v == "sealed":
		_ball(Vector2(36, 62), 16, Color("e8503a"), Color("5a0a06"))
	_reset()


func _d_book(v: String) -> void:
	_bg("brown")
	_fill(_pts([56, 50, 192, 40, 206, 206, 66, 216]), [Color("a8402a"), Color("6a1a10"), Color("2a0a06")], 30)
	_fill(_pts([62, 56, 78, 54, 86, 210, 70, 212]), _metal("gold"), 0)
	_fill(_pts([196, 46, 206, 204, 196, 206, 188, 48]), [Color("f6ecd0"), Color("c8b488")], 0)
	_star(Vector2(138, 126), 34, 14, 4, Color("e8c060"))


func _d_bag(v: String) -> void:
	var c: Color = { "red": Color("a83a2a"), "blue": Color("3a5aa8"), "green": Color("4a8a3a"), "white": Color("d8d0c0"), "black": Color("3a3438"), "brown": Color("8a5a2a") }.get(v, Color("8a5a2a"))
	_bg("brown")
	var shape := PackedVector2Array()
	for i in 25:
		var a := -0.1 * PI + 1.2 * PI * i / 24.0
		shape.append(Vector2(128, 150) + Vector2(cos(a) * 82, sin(a) * 70))
	shape.append(Vector2(156, 70))
	shape.append(Vector2(100, 70))
	_fill(shape, [c.lightened(0.35), c, c.darkened(0.6)], 60)
	_bar(Vector2(96, 84), Vector2(160, 84), 12, [Color("e0c070"), Color("8a6a20")])
	_fill(_pts([100, 70, 156, 70, 170, 40, 86, 40]), [c.lightened(0.2), c.darkened(0.4)], 90)


func _d_quiver(v: String) -> void:
	_bg("brown")
	_at(C, 0.4)
	_fill(_pts([-34, -60, 34, -60, 30, 100, -30, 100]), [Color("a0703a"), Color("5a3a1a"), Color("2a180a")], 0)
	for i in 4:
		var x := -22 + i * 14
		_line(Vector2(x, -60), Vector2(x, -104), Color("c8b088"), 5)
		_fill(_pts([x - 7, -104, x + 7, -104, x, -122]), [Color("e8e0d0"), Color("8a8070")], 90)
	_reset()


func _d_cloth(v: String) -> void:
	_bg("brown")
	var c := Color("d8ccb0") if v == "linen" else Color("b8a080")
	for i in 3:
		var y := 170.0 - i * 40.0
		_fill(_pts([44, y, 196, y - 10, 214, y + 22, 62, y + 32]), [c.lightened(0.2), c, c.darkened(0.45)], 90)
	_bar(Vector2(120, 60), Vector2(128, 210), 8, [Color("8a6a3a"), Color("4a3418")])


func _d_ore(v: String) -> void:
	var vein: Color = { "copper": Color("e08a4a"), "iron": Color("b8bcc8"), "tin": Color("d8d8c8") }.get(v, Color("e08a4a"))
	_bg("grey")
	var shape := _pts([46, 170, 70, 96, 128, 60, 190, 84, 214, 156, 170, 210, 90, 214])
	_fill(shape, [Color("7a7268"), Color("4a443c"), Color("1e1a16")], 60)
	for i in 7:
		var p := Vector2(80 + _rng.randf() * 100, 90 + _rng.randf() * 100)
		_ball(p, 8 + _rng.randf() * 8, vein.lightened(0.4), vein.darkened(0.3), false)


func _d_stone(v: String) -> void:
	_bg("grey")
	var light := Color("f0f0ea") if v == "salt" else Color("a8a098")
	_fill(_pts([50, 170, 66, 104, 120, 70, 192, 90, 212, 160, 162, 206, 84, 206]), [light, light.darkened(0.4), light.darkened(0.75)], 60)
	_line(Vector2(96, 110), Vector2(150, 150), Color(0, 0, 0, 0.3), 4)


func _d_gem(v: String) -> void:
	var c: Color = { "malachite": Color("2ab86a"), "tigerseye": Color("d89a2a"), "shadowgem": Color("6a3a9a"), "pearl": Color("f0ecf8") }.get(v, Color("3a8aff"))
	_bg("dark")
	_glow(C, 110, c, 1.2)
	if v == "pearl":
		_ball(C, 50, Color.WHITE, Color("a8a0b8"))
		return
	var shape := _pts([128, 46, 196, 110, 128, 214, 60, 110])
	_fill(shape, [c.lightened(0.6), c, c.darkened(0.6)], 45)
	_line(Vector2(60, 110), Vector2(196, 110), Color(1, 1, 1, 0.4), 3)
	_line(Vector2(128, 46), Vector2(128, 214), Color(0, 0, 0, 0.25), 3)


func _d_herb(v: String) -> void:
	var flower: Color = { "blossom": Color("f0a0d8"), "thistle": Color("b07ae0"), "sage": Color("d0e0c0"), "bruise": Color("8a6ab8"), "kelp": Color("6ad8c8") }.get(v, Color("f0e060"))
	_bg("green" if v != "kelp" else "teal")
	for i in 5:
		var top := Vector2(70 + i * 28, 70 + (i % 2) * 24)
		_line(Vector2(128, 220), top, Color("3a7a2a") if v != "kelp" else Color("2a8a6a"), 7)
		_fill(_ellipse(top + Vector2(8, 26), Vector2(10, 22)), [Color("8ad86a"), Color("2a6a1a")], 90)
		if v != "kelp":
			_star(top, 18, 8, 5, flower)
			draw_circle(top, 6, Color("f8e070"))


func _d_tooth(v: String) -> void:
	_bg("grey")
	if v == "claw" or v == "paw":
		for i in 3:
			_at(Vector2(84 + i * 44, 150), -0.4 + i * 0.4)
			_fill(_pts([-14, 40, 14, 40, 6, -40, 0, -64, -6, -40]), [Color("f4ecd8"), Color("b8ac90"), Color("4a4438")], 0)
			_reset()
		if v == "paw":
			_ball(Vector2(128, 196), 40, Color("8a6a4a"), Color("2a1a0a"))
		return
	var tusk := v == "tusk"
	_at(C, 0.6 if tusk else 0.2)
	if tusk:
		_fill(_pts([-20, 80, 20, 80, 18, 0, 0, -90, -10, -60, -18, 0]), [Color("fffaf0"), Color("d8ccb0"), Color("6a6250")], 0)
	else:
		_fill(_pts([-34, 60, 34, 60, 30, -20, 0, -86, -30, -20]), [Color("fffaf0"), Color("d8ccb0"), Color("6a6250")], 0)
		if v == "gold":
			_fill(_pts([-30, -20, 30, -20, 0, -86]), _metal("gold"), 0)
	_reset()


func _d_eye(v: String) -> void:
	_bg("teal")
	_ball(C, 70, Color("f0f4f0"), Color("8a9a8a"))
	_ball(C + Vector2(12, 4), 32, Color("8ad8a0"), Color("1a4a2a"), false)
	draw_circle(C + Vector2(14, 6), 14, OUT)
	_shine(Vector2(100, 100), Vector2(12, 20))


func _d_fin(v: String) -> void:
	_bg("teal")
	var shape := _pts([50, 200, 90, 60, 150, 40, 216, 80, 190, 140, 210, 200])
	_fill(shape, [Color("8ad8c0"), Color("2a8a7a"), Color("0a3a34")], 30)
	for i in 6:
		_line(Vector2(80 + i * 20, 196), Vector2(110 + i * 18, 70), Color(0, 0, 0, 0.3), 4)
	if v == "torn":
		draw_colored_polygon(_pts([160, 200, 210, 200, 190, 150]), BG.teal[1])


func _d_limb(v: String) -> void:
	_bg("dark")
	var joints := [Vector2(40, 210), Vector2(110, 140), Vector2(160, 160), Vector2(220, 50)]
	for i in 3:
		_bar(joints[i], joints[i + 1], 18 - i * 3, [Color("6a5a4a"), Color("2a221a"), Color("0a0806")])
	for j in joints:
		draw_circle(j, 10, Color("1a1410"))


func _d_web(v: String) -> void:
	_bg("dark")
	for i in 8:
		_line(C, C + Vector2.from_angle(TAU * i / 8.0) * 120, Color(0.9, 0.9, 0.95, 0.7), 3)
	for r in [30.0, 60.0, 90.0]:
		var ring := PackedVector2Array()
		for i in 9:
			ring.append(C + Vector2.from_angle(TAU * i / 8.0) * r)
		draw_polyline(ring, Color(0.9, 0.9, 0.95, 0.6), 2, true)


func _d_egg(v: String) -> void:
	_bg("brown")
	_fill(_ellipse(Vector2(128, 136), Vector2(58, 78)), [Color("fff8ec"), Color("e0d0b0"), Color("8a7a5a")], 120)
	_shine(Vector2(108, 100), Vector2(10, 24))


func _d_pelt(v: String) -> void:
	_bg("brown")
	var shape := _pts([60, 60, 100, 80, 156, 76, 196, 56, 190, 110, 212, 190, 160, 170, 128, 214, 96, 170, 44, 190, 66, 110])
	_fill(shape, [Color("a07a50"), Color("5a3e22"), Color("2a1a0a")], 60)
	for i in 30:
		var p := Vector2(80 + _rng.randf() * 100, 90 + _rng.randf() * 100)
		_line(p, p + Vector2(4, 10), Color(0, 0, 0, 0.25), 2)


func _d_shell(v: String) -> void:
	_bg("sky")
	var shape := PackedVector2Array()
	shape.append(Vector2(128, 206))
	for i in 13:
		var a := PI + PI * i / 12.0
		shape.append(Vector2(128, 140) + Vector2(cos(a) * 84, sin(a) * 84))
	_fill(shape, [Color("fff0e8"), Color("e8b8a8"), Color("8a5a4a")], 90)
	for i in 7:
		_line(Vector2(128, 200), Vector2(128, 140) + Vector2.from_angle(PI + PI * (i + 0.5) / 7.0) * 80, Color(0.5, 0.3, 0.25, 0.5), 4)


func _d_candle(v: String) -> void:
	_bg("dark")
	_glow(Vector2(128, 64), 100, Color("ffb84a"), 1.3)
	_fill(_pts([96, 90, 160, 90, 164, 220, 92, 220]), [Color("fff4d8"), Color("e0d0a8"), Color("8a7a58")], 0)
	_drop(Vector2(128, 68), 14, [Color("fffbe0"), Color("ffc040"), Color("e06010")])


func _d_coin(v: String) -> void:
	_bg("gold")
	_ball(C, 70, Color("fff0a8"), Color("6a4a10"))
	draw_arc(C, 54, 0, TAU, 40, Color(0.4, 0.28, 0.06, 0.7), 4)
	_star(C, 30, 12, 5, Color(0.45, 0.3, 0.06, 0.8))


func _d_pouch(v: String) -> void:
	_d_bag("brown")
	for i in 5:
		draw_circle(Vector2(100 + i * 14, 66 - (i % 2) * 8), 8, Color("f0d050") if v == "gold" else Color("8ad0f0"))


func _d_logs(v: String) -> void:
	_bg("brown")
	for i in 3:
		var y := 170.0 - (i % 2) * 44.0
		var x := 84.0 + i * 44.0
		_bar(Vector2(x - 60, y + 10), Vector2(x + 50, y - 50), 36, [Color("b08048"), Color("6a4422"), Color("2a1a0a")])
		_ball(Vector2(x + 50, y - 50), 18, Color("e0c088"), Color("8a6030"))
	_bar(Vector2(120, 210), Vector2(150, 60), 8, [Color("d8c090"), Color("8a7040")])


func _d_pie(v: String) -> void:
	_bg("brown")
	_fill(_ellipse(Vector2(128, 150), Vector2(96, 56)), [Color("8a5a2a"), Color("4a2a10")], 90)
	_fill(_ellipse(Vector2(128, 130), Vector2(92, 48)), [Color("f6cc80"), Color("c07a30"), Color("7a4a14")], 90)
	for i in 5:
		_line(Vector2(70 + i * 28, 104), Vector2(60 + i * 30, 160), Color(0.5, 0.25, 0.06, 0.6), 5)


func _d_bottle(v: String) -> void:
	var c := Color("e8a0d8") if v == "perfume" else Color("8ad8a0")
	_bg("purple")
	_fill(_pts([110, 40, 146, 40, 146, 80, 110, 80]), _metal("gold"), 0)
	_fill(_pts([90, 80, 166, 80, 186, 150, 166, 220, 90, 220, 70, 150]), [c.lightened(0.4), c, c.darkened(0.5)], 30)
	_shine(Vector2(100, 130), Vector2(10, 30))


func _d_medallion(v: String) -> void:
	_bg("blue")
	_line(Vector2(80, 30), Vector2(110, 100), Color("6a6a70"), 6)
	_line(Vector2(176, 30), Vector2(146, 100), Color("6a6a70"), 6)
	_ball(Vector2(128, 140), 60, Color("e8ecf0"), Color("4a525a"))
	_fill(_pts([128, 104, 156, 140, 128, 176, 100, 140]), [Color("3a5aa8"), Color("1a2a5a")], 45)


func _d_collar(v: String) -> void:
	_bg("brown")
	draw_arc(C, 70, 0, TAU, 48, OUT, 36)
	draw_arc(C, 70, 0, TAU, 48, Color("6a4422"), 28)
	for i in 10:
		draw_circle(C + Vector2.from_angle(TAU * i / 10.0) * 70, 7, Color("e0b858"))


func _d_bandana(v: String) -> void:
	_bg("red")
	var c := Color("b8302a")
	_fill(_pts([40, 80, 216, 80, 128, 220]), [c.lightened(0.3), c, c.darkened(0.6)], 90)
	for i in 6:
		draw_circle(Vector2(80 + i * 20, 110 + (i % 2) * 20), 5, Color(1, 1, 1, 0.5))


func _d_token(v: String) -> void:
	_bg("blue")
	_ball(C, 66, Color("c8d0d8"), Color("3a424a"))
	_d_shield_mark()


func _d_shield_mark() -> void:
	_fill(_pts([100, 96, 156, 96, 156, 140, 128, 170, 100, 140]), [Color("3a5aa8"), Color("1a2a5a")], 90)


func _d_heart(v: String) -> void:
	_bg("red")
	var shape := PackedVector2Array()
	for i in 41:
		var t := TAU * i / 40.0
		shape.append(C + Vector2(16 * pow(sin(t), 3), -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))) * 5.5)
	_fill(shape, [Color("ff8a8a"), Color("c8202a"), Color("4a0606")], 60)


func _d_unknown(v: String) -> void:
	_d_bag("brown")


# Designs: spells. Most are a picture over a glow in their school's color.

func _school(v: String, fallback := "gold") -> Array:
	var colors := {
		"red": [Color("ffd0b0"), Color("e04a2a"), "red"], "gold": [Color("fff4c0"), Color("e8b840"), "gold"],
		"blue": [Color("d0e8ff"), Color("4a8ae0"), "blue"], "green": [Color("e0ffc0"), Color("5ac03a"), "green"],
		"purple": [Color("f0d0ff"), Color("9a4ae0"), "purple"], "white": [Color("ffffff"), Color("c8c8d8"), "white"],
		"cyan": [Color("e0ffff"), Color("4ad0e0"), "teal"], "orange": [Color("ffe0b0"), Color("f08a20"), "orange"],
		"grey": [Color("e0e0e8"), Color("8a8a98"), "grey"], "dark": [Color("c8a8e0"), Color("4a2a6a"), "dark"],
	}
	return colors.get(v, colors[fallback])


## A sword slashing, with a bright arc: strikes.
func _d_strike(v: String) -> void:
	var c: Array = _school(v, "red")
	_bg(c[2])
	draw_arc(Vector2(110, 150), 92, -2.6, -0.6, 32, Color(c[0], 0.85), 16)
	draw_arc(Vector2(110, 150), 76, -2.4, -0.8, 32, Color(c[1], 0.6), 8)
	_blade(Vector2(70, 200), Vector2(206, 50), 26, _metal("steel"))
	_bar(Vector2(46, 182), Vector2(92, 226), 12, _metal("bronze"))


func _d_heavy(v: String) -> void:
	var c: Array = _school(v, "red")
	_bg(c[2])
	_glow(Vector2(170, 90), 90, c[0], 1.5)
	_rays(Vector2(170, 90), 20, 100, 9, Color(c[0], 0.6), 12, 0.3)
	_bar(Vector2(50, 220), Vector2(160, 100), 16, [Color("9a6a3a"), Color("5a3a1a"), Color("2a180a")])
	_axe_head(Vector2(146, 88), 1.5, _metal("steel"))


func _d_charge(v: String) -> void:
	_bg("orange")
	for i in 5:
		_line(Vector2(20, 80 + i * 26), Vector2(110 - i * 8, 80 + i * 26), Color(1, 0.85, 0.5, 0.7 - i * 0.1), 8)
	_d_boots_only(Vector2(150, 130))


func _d_boots_only(at: Vector2) -> void:
	_at(at, 0.0, 0.8)
	var shape := _pts([-40, -90, 32, -90, 30, 30, 86, 56, 86, 90, -44, 90, -38, 10])
	_fill(shape, [Color("b0804a"), Color("6a4422"), Color("2a1a0a")], 30)
	_reset()


func _d_stance(v: String) -> void:
	match v:
		"bastion":
			_bg("blue")
			_glow(C, 120, Color("8ab8ff"))
			_d_shield_shape(Vector2(128, 132), 1.0)
		"fury":
			_bg("red")
			_glow(C, 120, Color("ff6a3a"), 1.6)
			_bar(Vector2(60, 214), Vector2(170, 60), 16, [Color("9a6a3a"), Color("5a3a1a")])
			_axe_head(Vector2(150, 80), 1.4, _metal("dark"))
		_:
			_bg("red")
			_glow(C, 120, Color("ffb070"))
			_blade(Vector2(60, 200), Vector2(196, 60), 22, _metal("steel"))
			_blade(Vector2(196, 200), Vector2(60, 60), 22, _metal("steel"))


func _d_shield_shape(center: Vector2, scale: float) -> void:
	_at(center, 0.0, scale)
	var shape := _pts([-66, -74, 66, -74, 70, 0, 0, 86, -70, 0])
	_fill(shape, [Color("c8402a"), Color("8a1a14"), Color("3a0a08")], 45, false)
	_outline(shape, Color("d8aa40"), 12)
	_outline(shape, OUT, 4)
	_bar(Vector2(0, -64), Vector2(0, 70), 12, _metal("gold"))
	_bar(Vector2(-54, -16), Vector2(54, -16), 12, _metal("gold"))
	_reset()


func _d_shout(v: String) -> void:
	var c: Array = _school(v, "red")
	_bg(c[2])
	for i in 4:
		draw_arc(Vector2(110, 128), 50 + i * 28, -0.7, 0.7, 24, Color(c[0], 0.75 - i * 0.15), 9)
	_fill(_pts([30, 100, 90, 110, 140, 70, 150, 186, 90, 146, 30, 156]), [Color("f0e0b0"), Color("a88a50"), Color("4a3a1a")], 0)
	_bar(Vector2(60, 106), Vector2(60, 150), 8, _metal("bronze"))


func _d_bleed(v: String) -> void:
	_bg("red")
	_blade(Vector2(56, 196), Vector2(196, 56), 22, _metal("steel"))
	for p in [Vector2(150, 140), Vector2(180, 176), Vector2(126, 182)]:
		_drop(p, 13, [Color("ff6a5a"), Color("b8100a"), Color("400404")])


func _d_cyclone(v: String) -> void:
	_bg("red")
	for i in 3:
		draw_arc(C, 40 + i * 30, i * 2.0, i * 2.0 + 4.0, 32, Color(1, 0.85, 0.7, 0.75 - i * 0.18), 12)
	for i in 3:
		var a := TAU * i / 3.0
		_blade(C + Vector2.from_angle(a) * 20, C + Vector2.from_angle(a + 0.6) * 104, 18, _metal("steel"))


func _d_slam(v: String) -> void:
	_bg("brown")
	_glow(Vector2(128, 200), 120, Color("ffc070"), 1.3)
	for i in 7:
		var a := PI + PI * (i + 0.5) / 7.0
		_line(Vector2(128, 200), Vector2(128, 200) + Vector2.from_angle(a) * (90 + (i % 2) * 30), Color(0.1, 0.06, 0.02), 7)
	_rays(Vector2(128, 200), 30, 140, 7, Color(1, 0.8, 0.4, 0.4), 18, PI + 0.2)


func _d_bash(v: String) -> void:
	_bg("blue" if v != "red" else "red")
	_rays(Vector2(180, 90), 18, 90, 10, Color(1, 0.95, 0.7, 0.55), 14)
	_d_shield_shape(Vector2(116, 140), 0.95)


func _d_taunt(v: String) -> void:
	_bg("red")
	_glow(C, 110, Color("ffa070"))
	_fill(_pts([80, 210, 76, 120, 100, 70, 160, 64, 186, 110, 180, 210]), [Color("e8b890"), Color("b07850"), Color("5a3418")], 30)
	for i in 4:
		_line(Vector2(104 + i * 20, 70), Vector2(104 + i * 20, 120), Color(0.35, 0.2, 0.1, 0.7), 4)


func _d_parry(v: String) -> void:
	_bg("grey" if v != "red" else "red")
	_glow(C, 60, Color("fff0b0"), 2.0)
	_star(C, 54, 16, 8, Color(1, 0.95, 0.7, 0.9))
	_blade(Vector2(40, 210), Vector2(170, 80), 20, _metal("steel"))
	_blade(Vector2(216, 210), Vector2(86, 80), 20, _metal("steel"))


func _d_hilt(v: String) -> void:
	_bg("grey")
	for i in 3:
		_star(Vector2(70 + i * 56, 60 + (i % 2) * 20), 18, 7, 5, Color("ffe060"))
	_bar(Vector2(60, 140), Vector2(196, 140), 18, _metal("bronze"))
	_grip(Vector2(128, 150), Vector2(128, 210), 18)
	_ball(Vector2(128, 216), 16, Color("f0d070"), Color("6a4a10"))


func _d_execute(v: String) -> void:
	_bg("dark")
	_d_skull(Vector2(128, 140), 1.0, Color("c070ff"))
	_blade(Vector2(56, 220), Vector2(210, 40), 18, _metal("steel"))


func _d_skull(at: Vector2, scale: float, eyes: Color) -> void:
	_at(at, 0.0, scale)
	var shape := PackedVector2Array()
	for i in 25:
		var a := PI + PI * i / 24.0
		shape.append(Vector2(cos(a) * 60, sin(a) * 60 - 10))
	shape.append(Vector2(60, 20))
	shape.append(Vector2(36, 40))
	shape.append(Vector2(30, 66))
	shape.append(Vector2(-30, 66))
	shape.append(Vector2(-36, 40))
	shape.append(Vector2(-60, 20))
	_fill(shape, [Color("f4eedc"), Color("bdb39a"), Color("5a5240")], 45)
	for x in [-24.0, 24.0]:
		draw_colored_polygon(_ellipse(Vector2(x, 4), Vector2(16, 18)), Color("120818"))
		draw_circle(Vector2(x, 6), 5, eyes)
	draw_colored_polygon(_pts([0, 26, -8, 42, 8, 42]), Color("120818"))
	_reset()


func _d_rage(v: String) -> void:
	_bg("red")
	_glow(C, 120, Color("ff4a1a"), 1.8)
	for i in 7:
		var x := 50.0 + i * 26.0
		_drop(Vector2(x, 170 - (i % 3) * 24), 22 - (i % 2) * 6, [Color("fff0a0"), Color("ff7a1a"), Color("8a1004")])


func _d_disarm(v: String) -> void:
	_bg("grey")
	_blade(Vector2(150, 150), Vector2(220, 40), 18, _metal("steel"))
	_fill(_pts([40, 210, 46, 140, 74, 112, 120, 120, 132, 150, 100, 160, 96, 214]), [Color("e8b890"), Color("b07850"), Color("5a3418")], 30)
	for i in 3:
		draw_arc(Vector2(150, 130), 30 + i * 14, 0.3, 1.6, 12, Color(1, 1, 1, 0.5), 4)


func _d_dual(v: String) -> void:
	_bg("dark")
	_blade(Vector2(60, 210), Vector2(150, 70), 18, _metal("steel"), 0.3)
	_blade(Vector2(196, 210), Vector2(106, 70), 18, _metal("steel"), 0.3)


func _d_hobble(v: String) -> void:
	_bg("grey")
	_d_boots_only(Vector2(120, 130))
	for i in 7:
		draw_arc(Vector2(70 + i * 20, 200), 10, 0, TAU, 10, Color("8a8a90"), 5)


## Templar presences: a ring of light round a mark.
func _d_presence(v: String) -> void:
	var c: Array = _school({ "bulwark": "gold", "thorned": "green", "focused": "blue", "gloomward": "purple", "frostward": "cyan", "emberward": "red" }.get(v, "gold"))
	_bg(c[2])
	_glow(C, 120, c[1], 1.4)
	draw_arc(C, 74, 0, TAU, 48, Color(c[0], 0.9), 12)
	draw_arc(C, 92, 0, TAU, 48, Color(c[1], 0.6), 6)
	_star(C, 44, 18, 8 if v != "thorned" else 12, c[0])


## Templar boons: raised hands under a glow.
func _d_boon(v: String) -> void:
	var c: Array = _school({ "strength": "red", "clarity": "blue", "shelter": "gold", "unfettering": "green", "quietude": "grey", "radiance": "gold", "refuge": "white", "martyr": "red", "sovereigns": "purple" }.get(v, "gold"))
	_bg(c[2])
	_glow(Vector2(128, 90), 120, c[0], 1.5)
	_rays(Vector2(128, 90), 16, 110, 12, Color(c[0], 0.35), 14)
	for side in [-1, 1]:
		_at(Vector2(128 + side * 34, 170), side * 0.25)
		_fill(_pts([-20, 60, -22, -20, -16, -60, -6, -64, 0, -30, 6, -68, 14, -64, 18, -20, 22, 60]), [Color("f0d0b0"), Color("c0906a"), Color("6a4428")], 0)
		_reset()


## Templar oaths: a wax seal on a ribbon.
func _d_oath(v: String) -> void:
	var c: Array = _school({ "valor": "red", "vanguard": "gold", "binding": "grey", "mending": "green", "dominion": "purple", "insight": "blue" }.get(v, "gold"))
	_bg(c[2])
	_fill(_pts([96, 160, 128, 170, 108, 236, 90, 222]), [Color(c[1]), Color(c[1]).darkened(0.5)], 0)
	_fill(_pts([160, 160, 128, 170, 148, 236, 166, 222]), [Color(c[1]), Color(c[1]).darkened(0.5)], 0)
	var seal := PackedVector2Array()
	for i in 24:
		var r := 70.0 + (6.0 if i % 2 == 0 else 0.0)
		seal.append(Vector2(128, 116) + Vector2.from_angle(TAU * i / 24.0) * r)
	_fill(seal, [Color(c[1]).lightened(0.3), Color(c[1]), Color(c[1]).darkened(0.6)], 60)
	draw_arc(Vector2(128, 116), 46, 0, TAU, 32, Color(0, 0, 0, 0.35), 5)
	_star(Vector2(128, 116), 30, 12, 4, Color(c[0], 0.9))


func _d_verdict(v: String) -> void:
	_bg("gold")
	_glow(Vector2(150, 90), 110, Color("fff0b0"), 1.6)
	_bar(Vector2(60, 214), Vector2(150, 110), 14, [Color("9a6a3a"), Color("5a3a1a")])
	_at(Vector2(160, 92), -0.85)
	_fill(_pts([-50, -28, 50, -28, 50, 28, -50, 28]), _metal("gold"), 90)
	_reset()


func _d_gavel(v: String) -> void:
	_bg("gold")
	for i in 3:
		_star(Vector2(60 + i * 60, 52 + (i % 2) * 24), 16, 6, 5, Color("fff4c0"))
	_bar(Vector2(60, 214), Vector2(150, 120), 14, [Color("9a6a3a"), Color("5a3a1a")])
	_at(Vector2(158, 110), -0.8)
	_fill(_pts([-46, -26, 46, -26, 46, 26, -46, 26]), _metal("steel"), 90)
	_reset()


func _d_heal(v: String) -> void:
	var c: Array = _school(v, "gold")
	_bg(c[2])
	_glow(C, 120, c[0], 1.8)
	_rays(C, 30, 120, 16, Color(c[0], 0.3), 12)
	draw_rect(Rect2(112, 64, 32, 128), c[0])
	draw_rect(Rect2(64, 112, 128, 32), c[0])
	_outline(_pts([112, 64, 144, 64, 144, 112, 192, 112, 192, 144, 144, 144, 144, 192, 112, 192, 112, 144, 64, 144, 64, 112, 112, 112]), Color(c[1]).darkened(0.4), 4)


func _d_renew(v: String) -> void:
	_bg("green")
	_glow(C, 110, Color("d0ffb0"), 1.4)
	for i in 3:
		draw_arc(C, 40 + i * 24, i * 2.1, i * 2.1 + 4.2, 32, Color(0.85, 1, 0.7, 0.8 - i * 0.15), 10)
	_fill(_ellipse(C, Vector2(18, 36)), [Color("c8ff9a"), Color("3a9a2a")], 90)


func _d_cleanse(v: String) -> void:
	_bg("sky")
	_glow(C, 110, Color("c8f0ff"), 1.5)
	_drop(Vector2(128, 150), 46, [Color("f0faff"), Color("6ac0f0"), Color("1a4a7a")])
	_shine(Vector2(110, 140), Vector2(8, 20))


func _d_revive(v: String) -> void:
	_bg("gold")
	_glow(Vector2(128, 210), 160, Color("fff4c0"), 2.0)
	_rays(Vector2(128, 210), 40, 200, 11, Color(1, 0.95, 0.75, 0.35), 18, PI + 0.15)
	_fill(_pts([116, 70, 140, 70, 140, 110, 172, 110, 172, 132, 140, 132, 140, 200, 116, 200, 116, 132, 84, 132, 84, 110, 116, 110]), [Color("ffffff"), Color("f0d880")], 90)


func _d_aegis(v: String) -> void:
	_bg("gold")
	_glow(C, 120, Color("fff0b0"), 2.0)
	_d_shield_shape(C + Vector2(0, 6), 0.9)
	_glow(C, 70, Color("ffffff"), 0.8)


func _d_ground(v: String) -> void:
	_bg("gold")
	_fill(_ellipse(Vector2(128, 176), Vector2(110, 40)), [Color("fff4c0"), Color("d8a840"), Color("6a4a10")], 90)
	_rays(Vector2(128, 176), 20, 160, 12, Color(1, 0.95, 0.7, 0.3), 16, PI + 0.13)
	_star(Vector2(128, 176), 34, 12, 4, Color.WHITE)


func _d_banish(v: String) -> void:
	_bg("gold")
	_d_skull(Vector2(128, 140), 0.9, Color("ffe080"))
	_rays(C, 70, 128, 14, Color(1, 0.95, 0.7, 0.55), 12)


func _d_zeal(v: String) -> void:
	_bg("orange")
	_glow(C, 120, Color("ffd070"), 1.6)
	for i in 5:
		_drop(Vector2(80 + i * 24, 120 + (i % 2) * 20), 18, [Color("fff8c0"), Color("ffb030"), Color("a04a04")])
	_blade(Vector2(70, 220), Vector2(196, 50), 22, _metal("gold"))


func _d_bolt(v: String) -> void:
	var c: Array = _school(v, "gold")
	_bg(c[2])
	for i in 5:
		draw_circle(Vector2(60 - i * 6, 196 + i * 6), 30 - i * 5, Color(c[1], 0.25))
	_glow(Vector2(140, 116), 110, c[1], 1.8)
	_ball(Vector2(140, 116), 46, c[0], c[1], false)
	draw_circle(Vector2(140, 116), 22, Color(1, 1, 1, 0.85))


func _d_fire(v: String) -> void:
	_bg("orange")
	_glow(Vector2(140, 116), 120, Color("ff8a20"), 1.8)
	for i in 5:
		_fill(_ellipse(Vector2(84 - i * 14, 172 + i * 14), Vector2(22 - i * 3, 10 - i)), [Color(1, 0.6, 0.2, 0.5)], 0, false)
	_ball(Vector2(140, 116), 52, Color("fff8d0"), Color("e04a0a"), false)
	for i in 3:
		draw_arc(Vector2(140, 116), 24 + i * 12, i, i + 2.4, 20, Color(1, 0.95, 0.6, 0.7), 5)


func _d_frost(v: String) -> void:
	_bg("sky")
	_glow(C, 120, Color("c8f0ff"), 1.5)
	for i in 6:
		var a := TAU * i / 6.0
		var tip := C + Vector2.from_angle(a) * 96
		_line(C, tip, Color("f0faff"), 10)
		for s in [-1, 1]:
			_line(C + Vector2.from_angle(a) * 56, C + Vector2.from_angle(a) * 56 + Vector2.from_angle(a + s * 0.8) * 30, Color("f0faff"), 7)
	draw_circle(C, 16, Color.WHITE)


func _d_shadow(v: String) -> void:
	_bg("purple")
	for i in 7:
		var curve := PackedVector2Array()
		for t in 16:
			var f := float(t) / 15.0
			curve.append(Vector2(30 + i * 30 + sin(f * 6 + i) * 18, 240 - f * 210))
		draw_polyline(curve, Color(0.7, 0.4, 0.95, 0.25 + i * 0.05), 8, true)
	_d_skull(Vector2(128, 128), 0.85, Color("c070ff"))


func _d_mind(v: String) -> void:
	_bg("purple" if v != "calm" else "blue")
	_glow(C, 120, Color("d090ff") if v != "calm" else Color("90c0ff"), 1.5)
	var eye := PackedVector2Array()
	for i in 17:
		eye.append(Vector2(40 + i * 11, 128 - sin(PI * i / 16.0) * 56))
	for i in range(15, 0, -1):
		eye.append(Vector2(40 + i * 11, 128 + sin(PI * i / 16.0) * 56))
	_fill(eye, [Color("f8f0ff"), Color("c8b0e0")], 90)
	_ball(C, 34, Color("e0a0ff"), Color("4a1a7a"), false)
	draw_circle(C, 14, OUT)


func _d_ward(v: String) -> void:
	var c: Array = _school({ "shadow": "purple", "dread": "dark", "umbral": "purple" }.get(v, "white"))
	_bg(c[2] if v != "" else "blue")
	_glow(C, 110, c[0], 1.2)
	draw_arc(C, 84, 0, TAU, 48, Color(c[0], 0.9), 10)
	draw_arc(C, 66, -2.4, -1.2, 16, Color(1, 1, 1, 0.8), 8)
	_d_shield_shape(C, 0.55)


func _d_flame(v: String) -> void:
	var c: Array = _school(v, "orange")
	_bg(c[2])
	_glow(Vector2(128, 120), 110, c[1], 1.8)
	_drop(Vector2(128, 150), 52, [Color("fffbe0"), c[0], c[1]])
	_drop(Vector2(128, 166), 26, [Color.WHITE, Color("fff0a0")])


func _d_fear(v: String) -> void:
	_bg("dark")
	for i in 4:
		draw_arc(Vector2(128, 140), 70 + i * 20, -2.6, -0.5, 24, Color(0.75, 0.5, 0.95, 0.6 - i * 0.12), 8)
	_d_skull(Vector2(128, 140), 0.8, Color("ff6a6a"))


func _d_hex(v: String) -> void:
	_bg("purple")
	_glow(C, 110, Color("b06aff"), 1.4)
	_star(C, 80, 30, 5, Color(0.5, 0.15, 0.7, 0.9), -PI / 2 + PI)
	draw_arc(C, 86, 0, TAU, 40, Color("d0a0ff"), 6)


func _d_stars(v: String) -> void:
	_bg("dark")
	for i in 6:
		var p := Vector2(40 + i * 34, 50 + (i * 37) % 120)
		_line(p - Vector2(30, 30), p, Color(0.9, 0.85, 1, 0.5), 6)
		_star(p, 20, 8, 5, Color("fff4c0"))


func _d_burn(v: String) -> void:
	_bg("blue")
	_glow(C, 120, Color("6ab0ff"), 1.8)
	_drop(Vector2(128, 150), 52, [Color("f0faff"), Color("6ab0ff"), Color("1a2a8a")])


func _d_feather(v: String) -> void:
	_bg("sky")
	_at(C, -0.6)
	_fill(_ellipse(Vector2.ZERO, Vector2(34, 96)), [Color("ffffff"), Color("c8d8e8"), Color("6a7a8a")], 0)
	_line(Vector2(0, -96), Vector2(0, 110), Color("8a7a6a"), 5)
	_reset()


func _d_font(v: String) -> void:
	_bg("gold")
	_fill(_pts([70, 200, 186, 200, 168, 236, 88, 236]), _metal("steel"), 90)
	_glow(Vector2(128, 120), 110, Color("fff4c0"), 1.8)
	_bar(Vector2(128, 200), Vector2(128, 70), 14, [Color("fffbe0"), Color("ffe080")])
	for s in [-1, 1]:
		draw_arc(Vector2(128 + s * 40, 80), 40, PI if s < 0 else 0, PI * 1.5 if s < 0 else -PI * 0.5, 16, Color(1, 0.95, 0.75, 0.8), 8)


func _d_poison(v: String) -> void:
	_bg("green")
	_drop(Vector2(128, 150), 50, [Color("e0ffa0"), Color("6ac02a"), Color("1a4a06")])
	_d_skull(Vector2(128, 160), 0.35, Color("1a4a06"))


func _d_stun(v: String) -> void:
	_bg("grey")
	for i in 5:
		_star(C + Vector2.from_angle(TAU * i / 5.0) * 70, 22, 9, 5, Color("ffe060"))
	_ball(C, 30, Color("f0e0c0"), Color("8a6a4a"))


func _d_attack(v: String) -> void:
	_d_sword("")


func _d_passive(v: String) -> void:
	_bg("grey")
	_d_book("")
