class_name Buildings
extends RefCounted
## The human zones' buildings, made of a BuildingKit's parts: houses with a
## stone plinth, timber framing, framed windows with sills and shutters, a
## door with its frame and step, a chimney, and a roof with overhanging
## eaves, thickness and a ridge; a chapel with buttresses and a belfry
## tower; battlemented walls and towers; wells, open sheds, barns and
## watchtowers. Each takes its base (the middle of its footprint, on the
## ground), its size and its facing as the old boxes did, so footprints and
## collision stay where they were.
##
## A look is a Dictionary: "wall", "roof", "trim" (beams, frames, doors),
## "stone" (plinths, chimneys), "thatch" (a thick, rounded roof),
## "timber" (framing over the walls), "shutter".

const GLASS := Color(0.09, 0.1, 0.13)
const SHUTTER := Color(0.25, 0.33, 0.26)
const DARK := Color(0.05, 0.045, 0.045)


static func _look(look: Dictionary, key: String, fallback: Variant) -> Variant:
	return look.get(key, fallback)


## The local frame for a building at `base` facing `yaw`, turned so its
## ridge (its longer side) runs along x: returns [frame, length, span,
## swapped].
static func _frame(base: Vector3, size: Vector3, yaw: float) -> Array:
	var swapped := size.z > size.x
	var turn := yaw + (PI / 2.0 if swapped else 0.0)
	var length := size.z if swapped else size.x
	var span := size.x if swapped else size.z
	return [Transform3D(Basis(Vector3.UP, turn), base), length, span, swapped]


## A point or direction in the building's own unturned terms (+z front)
## in the ridge frame, which is a quarter turn round when `swapped`.
static func _turned(point: Vector3, swapped: bool) -> Vector3:
	return Vector3(-point.z, point.y, point.x) if swapped else point


## Where a door goes: the middle of its foot on the wall facing `side`
## (+z front, in the building's unturned terms), `offset` yards along it;
## returns [point, outward direction] in the ridge frame.
static func _door_place(size: Vector3, side: Vector2, offset: float, swapped: bool) -> Array:
	var out := Vector3(side.x, 0, side.y)
	var across := Vector3(absf(side.y), 0, absf(side.x))
	var at := Vector3(side.x * size.x / 2.0, 0, side.y * size.z / 2.0) + across * offset
	return [_turned(at, swapped), _turned(out, swapped)]


## A house: walls `size` (x, height, z) standing on `base`, facing `yaw`,
## its door on `door_side` (+z front by default; Vector2.ZERO for none) at
## `door_offset` yards along that wall. `storeys` 2 gives a jettied band and
## a second row of windows.
static func house(kit: BuildingKit, base: Vector3, size: Vector3, yaw: float, look: Dictionary,
		door_side := Vector2(0, 1), door_offset := 0.0, storeys := 1, chimney := true) -> void:
	var made := _frame(base, size, yaw)
	kit.frame = made[0]
	var length: float = made[1]
	var span: float = made[2]
	var height := size.y
	var wall: Color = look.wall
	var trim: Color = _look(look, "trim", Color(0.3, 0.2, 0.13))
	var stone: Color = _look(look, "stone", Color(0.45, 0.43, 0.41))
	kit.block(Vector3.ZERO, Vector3(length, height, span), wall, 0.0, true)
	kit.block(Vector3(0, -0.1, 0), Vector3(length + 0.3, 0.55, span + 0.3), stone)
	if _look(look, "timber", false):
		_timber(kit, length, span, height, storeys, trim)
	var door := [] if door_side == Vector2.ZERO else _door_place(size, door_side, door_offset, made[3])
	_windows(kit, length, span, height, storeys, door, trim, look)
	if not door.is_empty():
		_door(kit, door[0], door[1], trim, stone)
	var thatch: bool = _look(look, "thatch", false)
	var rise := span * (0.55 if thatch else 0.45)
	roof(kit, height, length, span, rise, look.roof, wall, thatch, trim)
	if chimney:
		var x := length / 2.0 - 0.9
		kit.block(Vector3(x, 0, -span * 0.18), Vector3(0.9, height + rise * 0.8 + 1.0, 0.9), stone)
		kit.block(Vector3(x, height + rise * 0.8 + 1.0, -span * 0.18), Vector3(1.15, 0.22, 1.15), stone)
	kit.frame = Transform3D.IDENTITY


## A gable roof on walls `height` tall: its ridge along x, `length` long,
## spanning `span` along z, rising `rise`; gable ends filled with `gable`.
static func roof(kit: BuildingKit, height: float, length: float, span: float, rise: float, color: Color, gable: Color, thatch := false, trim := Color(0.3, 0.2, 0.13)) -> void:
	var overhang := 0.75 if thatch else 0.5
	var thick := 0.5 if thatch else 0.22
	var ridge := Vector3(0, height + rise, 0)
	for side: float in [-1.0, 1.0]:
		var eave := Vector3(0, height - overhang * rise / (span / 2.0), side * (span / 2.0 + overhang))
		var along := (ridge - eave).normalized()
		var normal := along.cross(Vector3.RIGHT)
		if normal.y < 0.0:
			normal = -normal
		var slab := (ridge - eave).length() + (0.15 if thatch else 0.05)
		var center := (ridge + eave) / 2.0 + normal * thick / 2.0
		kit.box(center, Vector3(length + overhang * 2.0, thick, slab), color, Basis(Vector3.RIGHT, normal, along))
	# Gable ends, with a beam along their foot.
	for end: float in [-1.0, 1.0]:
		var outer := kit.frame
		kit.frame = outer * Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(end * (length / 2.0 - 0.05), height, 0))
		kit.wedge(Vector3.ZERO, span, rise, 0.2, gable)
		kit.frame = outer
		kit.box(Vector3(end * (length / 2.0 + 0.02), height + 0.1, 0), Vector3(0.25, 0.25, span + 0.1), trim)
	if thatch:
		kit.beam(Vector3(-length / 2.0 - overhang, height + rise + thick * 0.55, 0), Vector3(length / 2.0 + overhang, height + rise + thick * 0.55, 0), thick * 1.3, color.darkened(0.12))
	else:
		kit.beam(Vector3(-length / 2.0 - overhang, height + rise + thick, 0), Vector3(length / 2.0 + overhang, height + rise + thick, 0), 0.3, color.darkened(0.25))


## Dark timber over the walls: corner posts, sill, top plate, studs and
## braces (and a band between storeys).
static func _timber(kit: BuildingKit, length: float, span: float, height: float, storeys: int, trim: Color) -> void:
	var out := 0.06
	for x: float in [-length / 2.0, length / 2.0]:
		for z: float in [-span / 2.0, span / 2.0]:
			kit.block(Vector3(x, 0.3, z), Vector3(0.34, height - 0.3, 0.34), trim)
	var levels := [0.45, height - 0.15]
	if storeys > 1:
		levels.append(height / 2.0)
	for y: float in levels:
		for z: float in [-1.0, 1.0]:
			kit.box(Vector3(0, y, z * (span / 2.0 + out)), Vector3(length + 0.1, 0.24, 0.14), trim)
		for x: float in [-1.0, 1.0]:
			kit.box(Vector3(x * (length / 2.0 + out), y, 0), Vector3(0.14, 0.24, span + 0.1), trim)
	# Studs and braces on the long walls.
	var bays := maxi(int(length / 2.4), 2)
	for z: float in [-1.0, 1.0]:
		var face := z * (span / 2.0 + out)
		for i in range(1, bays):
			var x := -length / 2.0 + length * i / bays
			kit.box(Vector3(x, height / 2.0, face), Vector3(0.2, height - 0.4, 0.12), trim)
		for end: float in [-1.0, 1.0]:
			var corner := end * length / 2.0
			kit.beam(Vector3(corner - end * 0.2, 0.55, face), Vector3(corner - end * minf(1.6, length / bays), minf(height - 0.3, height / storeys), face), 0.16, trim)
	# Studs on the ends.
	for x: float in [-1.0, 1.0]:
		kit.box(Vector3(x * (length / 2.0 + out), height / 2.0, 0), Vector3(0.12, height - 0.4, 0.2), trim)


## Windows along the long walls (and one each end): a dark pane in a frame,
## a sill, and shutters; left out where the door is.
static func _windows(kit: BuildingKit, length: float, span: float, height: float, storeys: int, door: Array, trim: Color, look: Dictionary) -> void:
	var shutter: Color = _look(look, "shutter", SHUTTER)
	var rows: Array[float] = []
	rows.assign([height * 0.5] if storeys == 1 else [height * 0.27, height * 0.73])
	var count := maxi(int(length / 3.2), 1)
	for z: float in [-1.0, 1.0]:
		for i in count:
			var x := -length / 2.0 + length * (i + 0.5) / count
			var at := Vector3(x, 0, z * span / 2.0)
			for y: float in rows:
				if not door.is_empty() and at.distance_to(door[0]) < 1.5 and y < 2.6:
					continue
				_window(kit, at + Vector3.UP * y, Vector3(0, 0, z), trim, shutter)
	for x: float in [-1.0, 1.0]:
		var at := Vector3(x * length / 2.0, 0, 0)
		if not door.is_empty() and at.distance_to(door[0]) < 1.5:
			continue
		_window(kit, at + Vector3.UP * rows[0], Vector3(x, 0, 0), trim, shutter)


static func _window(kit: BuildingKit, at: Vector3, out: Vector3, trim: Color, shutter: Color) -> void:
	var across := Vector3(out.z, 0, -out.x).abs()
	var w := 0.85
	var h := 1.0
	kit.box(at + out * 0.03, across * w + Vector3.UP * h + out.abs() * 0.06, GLASS)
	kit.box(at + out * 0.06, across * 0.08 + Vector3.UP * h + out.abs() * 0.05, trim)
	kit.box(at + out * 0.06 + Vector3.UP * (h / 2.0), across * (w + 0.2) + Vector3.UP * 0.12 + out.abs() * 0.1, trim)
	kit.box(at + out * 0.1 - Vector3.UP * (h / 2.0 + 0.04), across * (w + 0.35) + Vector3.UP * 0.12 + out.abs() * 0.25, trim)
	for side: float in [-1.0, 1.0]:
		kit.box(at + out * 0.06 + across * side * (w / 2.0 + 0.24), across * 0.44 + Vector3.UP * h + out.abs() * 0.06, shutter)


## A door on a wall with its frame, lintel and a step: `at` the middle of
## its foot, `out` the way it faces.
static func _door(kit: BuildingKit, at: Vector3, out: Vector3, trim: Color, stone: Color) -> void:
	var across := Vector3(out.z, 0, out.x).abs()
	kit.block(at + out * 0.05 + Vector3.UP * 0.35, across * 1.25 + Vector3.UP * 2.1 + out.abs() * 0.1, trim.darkened(0.25))
	for s: float in [-1.0, 1.0]:
		kit.block(at + out * 0.1 + across * s * 0.72 + Vector3.UP * 0.35, across * 0.2 + Vector3.UP * 2.25 + out.abs() * 0.16, trim)
	kit.block(at + out * 0.1 + Vector3.UP * 2.5, across * 1.75 + Vector3.UP * 0.25 + out.abs() * 0.2, trim)
	kit.block(at + out * 0.4 - Vector3.UP * 0.1, across * 1.7 + Vector3.UP * 0.3 + out.abs() * 0.7, stone)


## A chapel: a stone nave with tall windows, buttresses and an arched door
## on `door_side`, a steep roof, and its bell tower (`tower_at`, from the
## base, `tower_size` across and `tower_height` tall) with a spire.
static func chapel(kit: BuildingKit, base: Vector3, size: Vector3, yaw: float, look: Dictionary, door_side: Vector2,
		tower_at: Vector2, tower_size: float, tower_height: float) -> void:
	var made := _frame(base, size, yaw)
	kit.frame = made[0]
	var length: float = made[1]
	var span: float = made[2]
	var height := size.y
	var wall: Color = look.wall
	var trim: Color = _look(look, "trim", Color(0.3, 0.2, 0.13))
	var stone: Color = _look(look, "stone", Color(0.45, 0.43, 0.41))
	kit.block(Vector3.ZERO, Vector3(length, height, span), wall, 0.0, true)
	kit.block(Vector3(0, -0.1, 0), Vector3(length + 0.5, 0.7, span + 0.5), stone)
	# A course under the eaves.
	kit.block(Vector3(0, height - 0.35, 0), Vector3(length + 0.25, 0.3, span + 0.25), stone)
	var bays := maxi(int(length / 3.0), 2)
	var placed := _door_place(size, door_side, 0.0, made[3])
	var face: Vector3 = placed[0]
	var out: Vector3 = placed[1]
	for z: float in [-1.0, 1.0]:
		for i in bays + 1:
			var x := -length / 2.0 + length * i / bays
			# Buttresses, stepped.
			kit.block(Vector3(x, 0, z * (span / 2.0 + 0.35)), Vector3(0.7, height * 0.75, 0.7), stone)
			kit.block(Vector3(x, height * 0.75, z * (span / 2.0 + 0.2)), Vector3(0.6, height * 0.15, 0.4), stone)
		for i in bays:
			var x := -length / 2.0 + length * (i + 0.5) / bays
			if Vector3(x, 0, z * span / 2.0).distance_to(face) < 1.6:
				continue
			_lancet(kit, Vector3(x, height * 0.3, z * span / 2.0), Vector3(0, 0, z), height * 0.45, stone)
	# The end windows: a round one high in each gable end.
	for x: float in [-1.0, 1.0]:
		if Vector3(x * length / 2.0, 0, 0).distance_to(face) > 1.6:
			_lancet(kit, Vector3(x * length / 2.0, height * 0.3, 0), Vector3(x, 0, 0), height * 0.5, stone)
	# The arched door.
	var across := Vector3(out.z, 0, out.x).abs()
	kit.block(face + out * 0.05, across * 1.6 + Vector3.UP * 2.6 + out.abs() * 0.12, trim.darkened(0.2))
	var outer := kit.frame
	kit.frame = outer * Transform3D(Basis(Vector3.UP, atan2(out.x, out.z)), face + out * 0.08 + Vector3.UP * 2.6)
	kit.wedge(Vector3.ZERO, 1.6, 0.9, 0.12, trim.darkened(0.2))
	kit.wedge(Vector3(0, -0.05, 0.05), 2.2, 1.2, 0.2, stone)
	kit.frame = outer
	for s: float in [-1.0, 1.0]:
		kit.block(face + out * 0.15 + across * s * 1.0, across * 0.35 + Vector3.UP * 2.7 + out.abs() * 0.3, stone)
	kit.block(face + out * 0.5 - Vector3.UP * 0.1, across * 2.4 + Vector3.UP * 0.3 + out.abs() * 1.0, stone)
	roof(kit, height, length, span, span * 0.7, look.roof, wall, false, trim)
	kit.frame = Transform3D.IDENTITY
	if tower_size > 0.0:
		bell_tower(kit, base + Basis(Vector3.UP, yaw) * Vector3(tower_at.x, 0, tower_at.y), tower_size, tower_height, look)


## A tall narrow window with a pointed top and a stone surround.
static func _lancet(kit: BuildingKit, at: Vector3, out: Vector3, height: float, stone: Color) -> void:
	var across := Vector3(out.z, 0, -out.x).abs()
	kit.block(at + out * 0.03, across * 0.7 + Vector3.UP * height + out.abs() * 0.06, GLASS)
	kit.block(at + out * 0.05 - Vector3.UP * 0.12, across * 1.0 + Vector3.UP * 0.12 + out.abs() * 0.2, stone)
	var outer := kit.frame
	kit.frame = outer * Transform3D(Basis(Vector3.UP, atan2(out.x, out.z)), at + out * 0.04 + Vector3.UP * height)
	kit.wedge(Vector3.ZERO, 0.7, 0.45, 0.06, GLASS)
	kit.wedge(Vector3(0, 0, 0.03), 1.0, 0.65, 0.08, stone)
	kit.frame = outer


## A square stone bell tower `size` across and `height` tall: string
## courses, belfry openings near the top, a parapet and a spire.
static func bell_tower(kit: BuildingKit, base: Vector3, size: float, height: float, look: Dictionary) -> void:
	kit.frame = Transform3D(Basis(), base)
	var wall: Color = look.wall
	var stone: Color = _look(look, "stone", Color(0.45, 0.43, 0.41))
	kit.block(Vector3.ZERO, Vector3(size, height, size), wall, 0.0, true)
	kit.block(Vector3(0, -0.1, 0), Vector3(size + 0.6, 0.8, size + 0.6), stone)
	for y: float in [height * 0.4, height * 0.75]:
		kit.block(Vector3(0, y, 0), Vector3(size + 0.25, 0.3, size + 0.25), stone)
	for side: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var across := Vector3(side.z, 0, side.x).abs()
		var face := side * size / 2.0
		kit.block(face + side * 0.03 + Vector3.UP * (height * 0.8), across * 0.8 + Vector3.UP * 1.5 + side.abs() * 0.08, DARK)
		var outer := kit.frame
		kit.frame = outer * Transform3D(Basis(Vector3.UP, atan2(side.x, side.z)), face + side * 0.04 + Vector3.UP * (height * 0.8 + 1.5))
		kit.wedge(Vector3.ZERO, 0.8, 0.45, 0.08, DARK)
		kit.frame = outer
		kit.block(face + side * 0.03 + Vector3.UP * (height * 0.45), across * 0.25 + Vector3.UP * 1.0 + side.abs() * 0.08, DARK)
	battlements(kit, Vector3(0, height, 0), size + 0.3, size + 0.3, stone)
	# The spire: a four-sided cone, turned square to the walls.
	var outer := kit.frame
	kit.frame = outer * Transform3D(Basis(Vector3.UP, PI / 4.0), Vector3(0, height, 0))
	kit.cylinder(Vector3.ZERO, size * 0.62, size * 1.6, look.roof, 4, 0.0)
	kit.frame = outer
	kit.beam(Vector3(0, height + size * 1.6 - 0.1, 0), Vector3(0, height + size * 1.6 + 1.0, 0), 0.12, stone)
	kit.beam(Vector3(-0.3, height + size * 1.6 + 0.65, 0), Vector3(0.3, height + size * 1.6 + 0.65, 0), 0.1, stone)
	kit.frame = Transform3D.IDENTITY


## Merlons round the top of a block `width` by `depth`, with a coping
## course under them.
static func battlements(kit: BuildingKit, top: Vector3, width: float, depth: float, color: Color) -> void:
	kit.box(top + Vector3(0, -0.15, 0), Vector3(width + 0.1, 0.3, depth + 0.1), color)
	var step := 1.2
	for side: float in [-1.0, 1.0]:
		var count := maxi(int(width / step), 2)
		for i in count + 1:
			if i % 2 == 0:
				kit.block(top + Vector3(-width / 2.0 + width * i / count, 0, side * (depth / 2.0 - 0.18)), Vector3(0.6, 0.75, 0.36), color)
		count = maxi(int(depth / step), 2)
		for i in count + 1:
			if i % 2 == 0:
				kit.block(top + Vector3(side * (width / 2.0 - 0.18), 0, -depth / 2.0 + depth * i / count), Vector3(0.36, 0.75, 0.6), color)


## A curtain wall: a block on a battered plinth, with a coping course and
## merlons along its top.
static func wall(kit: BuildingKit, base: Vector3, size: Vector3, color: Color, plinth: Color) -> void:
	kit.frame = Transform3D(Basis(), base)
	kit.block(Vector3.ZERO, size, color, 0.0, true)
	kit.block(Vector3(0, -0.2, 0), Vector3(size.x + 0.5, 0.9, size.z + 0.5), plinth)
	battlements(kit, Vector3(0, size.y, 0), size.x, size.z, plinth)
	kit.frame = Transform3D.IDENTITY


## A square tower on a wall: battlements, arrow slits, and a low pyramid
## roof (or none).
static func tower(kit: BuildingKit, base: Vector3, size: Vector3, color: Color, trim: Color, roof_color: Variant = null) -> void:
	kit.frame = Transform3D(Basis(), base)
	kit.block(Vector3.ZERO, size, color, 0.0, true)
	kit.block(Vector3(0, -0.2, 0), Vector3(size.x + 0.7, 1.1, size.z + 0.7), trim)
	kit.block(Vector3(0, size.y - 0.6, 0), Vector3(size.x + 0.35, 0.35, size.z + 0.35), trim)
	for side: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var across := Vector3(side.z, 0, side.x).abs()
		var face := side * (size.x if side.x != 0.0 else size.z) / 2.0
		kit.block(face + side * 0.03 + Vector3.UP * (size.y * 0.55), across * 0.2 + Vector3.UP * 1.1 + side.abs() * 0.08, DARK)
	battlements(kit, Vector3(0, size.y, 0), size.x + 0.35, size.z + 0.35, trim)
	if roof_color != null:
		var outer := kit.frame
		kit.frame = outer * Transform3D(Basis(Vector3.UP, PI / 4.0), Vector3(0, size.y, 0))
		kit.cylinder(Vector3.ZERO, size.x * 0.6, size.x * 0.75, roof_color, 4, 0.0)
		kit.frame = outer
	kit.frame = Transform3D.IDENTITY


## A well: a round stone kerb with dark water, two posts, a windlass with a
## bucket, and a little gable roof.
static func well(kit: BuildingKit, base: Vector3, stone: Color, wood: Color, roof_color: Color, thatch := false) -> void:
	kit.frame = Transform3D(Basis(), base)
	kit.cylinder(Vector3.ZERO, 1.2, 1.0, stone, 12, -1.0, true)
	kit.cylinder(Vector3(0, 0.05, 0), 0.95, 0.97, Color(0.08, 0.12, 0.14), 12)
	kit.cylinder(Vector3(0, 0.95, 0), 1.3, 0.15, stone.darkened(0.1), 12)
	for side: float in [-1.0, 1.0]:
		kit.block(Vector3(side * 1.0, 0.9, 0), Vector3(0.2, 1.75, 0.2), wood)
	kit.beam(Vector3(-1.1, 1.75, 0), Vector3(1.1, 1.75, 0), 0.16, wood)
	kit.cylinder(Vector3(0.1, 1.15, 0), 0.22, 0.35, wood.darkened(0.2), 8)
	kit.beam(Vector3(0.1, 1.5, 0), Vector3(0.1, 1.75, 0), 0.03, DARK)
	roof(kit, 2.6, 2.4, 1.8, 0.75, roof_color, wood, thatch, wood)
	kit.frame = Transform3D.IDENTITY


## An open shed on four posts with braces under a gable roof (the smithy).
static func shed(kit: BuildingKit, base: Vector3, size: Vector3, yaw: float, wood: Color, roof_color: Color) -> void:
	var made := _frame(base, size, yaw)
	kit.frame = made[0]
	var length: float = made[1]
	var span: float = made[2]
	var height := size.y
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			var post := Vector3(x * (length / 2.0 - 0.25), 0, z * (span / 2.0 - 0.25))
			kit.block(post, Vector3(0.5, height, 0.5), wood, 0.0, true)
			kit.beam(post + Vector3(0, height - 1.2, 0), post + Vector3(-x * 1.0, height - 0.15, 0), 0.18, wood)
			kit.block(post - Vector3(0, 0.1, 0), Vector3(0.75, 0.3, 0.75), Color(0.45, 0.43, 0.41))
	for z: float in [-1.0, 1.0]:
		kit.box(Vector3(0, height - 0.1, z * (span / 2.0 - 0.25)), Vector3(length, 0.3, 0.3), wood)
	roof(kit, height, length, span, span * 0.35, roof_color, wood, false, wood)
	kit.frame = Transform3D.IDENTITY


## A barn of planks: big double doors on a gable end (`door_end` +1 or -1
## along its length), a loft hatch above, braced doors, a plinth.
static func barn(kit: BuildingKit, base: Vector3, size: Vector3, yaw: float, wood: Color, trim: Color, roof_color: Color, door_end := 1.0) -> void:
	var made := _frame(base, size, yaw)
	kit.frame = made[0]
	var length: float = made[1]
	var span: float = made[2]
	var height := size.y
	kit.block(Vector3.ZERO, Vector3(length, height, span), wood, 0.0, true)
	kit.block(Vector3(0, -0.1, 0), Vector3(length + 0.3, 0.45, span + 0.3), Color(0.45, 0.43, 0.41))
	for x: float in [-length / 2.0, length / 2.0]:
		for z: float in [-span / 2.0, span / 2.0]:
			kit.block(Vector3(x, 0.3, z), Vector3(0.38, height - 0.3, 0.38), trim)
	for z: float in [-1.0, 1.0]:
		kit.box(Vector3(0, height - 0.15, z * (span / 2.0 + 0.05)), Vector3(length + 0.1, 0.26, 0.14), trim)
	var face := door_end * (length / 2.0 + 0.06)
	for s: float in [-1.0, 1.0]:
		var leaf := Vector3(face, 1.6, s * 1.05)
		kit.box(leaf, Vector3(0.1, 3.2, 2.0), trim.darkened(0.15))
		kit.beam(Vector3(face + door_end * 0.04, 0.2, s * 0.15), Vector3(face + door_end * 0.04, 3.0, s * 1.95), 0.16, trim)
		kit.beam(Vector3(face + door_end * 0.04, 0.2, s * 1.95), Vector3(face + door_end * 0.04, 3.0, s * 0.15), 0.16, trim)
	kit.box(Vector3(face, 3.3, 0), Vector3(0.18, 0.25, 4.4), trim)
	kit.box(Vector3(face, height + 0.6, 0), Vector3(0.1, 1.1, 1.2), DARK)
	roof(kit, height, length, span, span * 0.5, roof_color, wood, false, trim)
	kit.frame = Transform3D.IDENTITY


## A wooden watchtower on four braced posts: a plank platform with a rail,
## a ladder and a pointed roof.
static func watchtower(kit: BuildingKit, base: Vector3, height: float, width: float, wood: Color, trim: Color, roof_color: Color) -> void:
	kit.frame = Transform3D(Basis(), base)
	var half := width / 2.0 - 0.3
	var corners := [Vector3(-half, 0, -half), Vector3(half, 0, -half), Vector3(half, 0, half), Vector3(-half, 0, half)]
	for corner: Vector3 in corners:
		kit.block(corner, Vector3(0.4, height + 2.4, 0.4), trim, 0.0, true)
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		kit.beam(a + Vector3.UP * 0.4, b + Vector3.UP * (height - 0.3), 0.15, trim)
		kit.beam(b + Vector3.UP * 0.4, a + Vector3.UP * (height - 0.3), 0.15, trim)
		kit.beam(a + Vector3.UP * (height + 1.0), b + Vector3.UP * (height + 1.0), 0.14, trim)
	kit.block(Vector3(0, height - 0.15, 0), Vector3(width, 0.3, width), wood, 0.0, true)
	# The ladder up the south side.
	for s: float in [-1.0, 1.0]:
		kit.beam(Vector3(s * 0.35, 0, half + 0.7), Vector3(s * 0.35, height, half + 0.25), 0.1, trim)
	for step in range(1, int(height / 0.5)):
		var t := step * 0.5 / height
		kit.beam(Vector3(-0.35, step * 0.5, half + 0.7 - t * 0.45), Vector3(0.35, step * 0.5, half + 0.7 - t * 0.45), 0.08, trim)
	var outer := kit.frame
	kit.frame = outer * Transform3D(Basis(Vector3.UP, PI / 4.0), Vector3(0, height + 2.3, 0))
	kit.cylinder(Vector3.ZERO, width * 0.82, 1.7, roof_color, 4, 0.0)
	kit.frame = outer
	kit.frame = Transform3D.IDENTITY


## A market stall: a counter, two posts and a sloping cloth awning.
static func stall(kit: BuildingKit, base: Vector3, yaw: float, wood: Color, trim: Color, cloth: Color, length := 4.0) -> void:
	kit.frame = Transform3D(Basis(Vector3.UP, yaw), base)
	kit.block(Vector3(0, 0, 0), Vector3(1.4, 1.0, length), wood, 0.0, true)
	kit.block(Vector3(-0.1, 1.0, 0), Vector3(1.6, 0.1, length + 0.2), trim)
	for z: float in [-1.0, 1.0]:
		kit.block(Vector3(0.9, 0, z * (length / 2.0 - 0.1)), Vector3(0.18, 2.95, 0.18), trim)
		kit.block(Vector3(-0.7, 0, z * (length / 2.0 - 0.1)), Vector3(0.15, 2.55, 0.15), trim)
	# The awning, high at the back (+x) and sloping to the front.
	var awning := Basis(Vector3.BACK, atan2(0.4, 1.6))
	kit.box(Vector3(0.1, 2.8, 0), Vector3(2.2, 0.08, length + 0.4), cloth, awning)
	for z in range(int(length)):
		kit.box(Vector3(-0.95, 2.45, -length / 2.0 + 0.5 + z), Vector3(0.06, 0.35, 0.5), cloth.darkened(0.2 if z % 2 == 0 else 0.0))
	kit.frame = Transform3D.IDENTITY


## Crates, a few: each with a darker band round it.
static func crate(kit: BuildingKit, base: Vector3, size: float, wood: Color, trim: Color, yaw := 0.0) -> void:
	kit.frame = Transform3D(Basis(Vector3.UP, yaw), base)
	kit.block(Vector3.ZERO, Vector3.ONE * size, wood, 0.0, true)
	for y: float in [0.08, size - 0.08]:
		kit.box(Vector3(0, y, 0), Vector3(size + 0.04, 0.12, size + 0.04), trim)
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			kit.block(Vector3(x * size / 2.0, 0, z * size / 2.0), Vector3(0.1, size, 0.1), trim)
	kit.frame = Transform3D.IDENTITY


## A barrel: a staved cylinder with dark hoops.
static func barrel(kit: BuildingKit, base: Vector3, radius: float, height: float, wood: Color) -> void:
	kit.frame = Transform3D(Basis(), base)
	kit.cylinder(Vector3.ZERO, radius * 0.88, height * 0.5, wood, 10, radius, true)
	kit.cylinder(Vector3(0, height * 0.5, 0), radius, height * 0.5, wood, 10, radius * 0.88)
	for y: float in [height * 0.15, height * 0.5, height * 0.85]:
		kit.cylinder(Vector3(0, y - 0.04, 0), radius * (0.96 if absf(y - height * 0.5) < 0.01 else 0.92) + 0.02, 0.08, DARK, 10)
	kit.frame = Transform3D.IDENTITY
