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
## a second row of windows. `hollow` makes it a room you can walk into: walls
## with an open doorway, a plank floor, windows letting in daylight, roof
## trusses, a hearth under the chimney, a warm light, and a roof the camera
## stops at. Returns the room (for furnish): its frame, yaw, inside half
## length and half span, height and door.
static func house(kit: BuildingKit, base: Vector3, size: Vector3, yaw: float, look: Dictionary,
		door_side := Vector2(0, 1), door_offset := 0.0, storeys := 1, chimney := true, hollow := false) -> Dictionary:
	kit.footprint(base, size, yaw)
	var made := _frame(base, size, yaw)
	kit.frame = made[0]
	var length: float = made[1]
	var span: float = made[2]
	var height := size.y
	var wall: Color = look.wall
	var trim: Color = _look(look, "trim", Color(0.3, 0.2, 0.13))
	var stone: Color = _look(look, "stone", Color(0.45, 0.43, 0.41))
	var door := [] if door_side == Vector2.ZERO else _door_place(size, door_side, door_offset, made[3])
	var thick := WALL_THICK if hollow else 0.0
	var hearth := hollow and chimney
	# The hearth's end: +x, or -x when the door is in that end wall.
	var hearth_side := -1.0 if not door.is_empty() and (door[1] as Vector3).x > 0.5 else 1.0
	var windows := _window_places(length, span, height, storeys, door, hearth_side if hearth else 0.0)
	if hollow:
		_hollow_walls(kit, length, span, height, thick, wall, stone, door, windows)
		kit.block(Vector3(0, -0.05, 0), Vector3(length - thick * 2.0, 0.15, span - thick * 2.0), _look(look, "floor", FLOOR), 0.0, true)
	else:
		kit.block(Vector3.ZERO, Vector3(length, height, span), wall, 0.0, true)
		kit.block(Vector3(0, -0.1, 0), Vector3(length + 0.3, 0.55, span + 0.3), stone)
	if _look(look, "timber", false):
		_timber(kit, length, span, height, storeys, trim, windows)
	var shutter: Color = _look(look, "shutter", SHUTTER)
	for place: Array in windows:
		_window(kit, place[0], place[1], trim, shutter, thick)
	if not door.is_empty():
		if hollow:
			_doorway(kit, door[0], door[1], thick, trim, stone)
		else:
			_door(kit, door[0], door[1], trim, stone)
	var thatch: bool = _look(look, "thatch", false)
	var rise := span * (0.55 if thatch else 0.45)
	roof(kit, height, length, span, rise, look.roof, wall, thatch, trim, hollow)
	if hearth:
		_hearth(kit, length, span, height, rise, thick, stone, trim, hearth_side)
	elif chimney:
		var x := length / 2.0 - 0.9
		kit.block(Vector3(x, 0, -span * 0.18), Vector3(0.9, height + rise * 0.8 + 1.0, 0.9), stone)
		kit.block(Vector3(x, height + rise * 0.8 + 1.0, -span * 0.18), Vector3(1.15, 0.22, 1.15), stone)
	if hollow:
		_trusses(kit, length, span, height, rise, thick, trim)
		_room_lights(kit, length, span, height, 0.9)
		kit.dust(Vector3(0, (height + rise * 0.5) / 2.0, 0), Vector3(length - thick * 2.0, height + rise * 0.5, span - thick * 2.0))
	kit.frame = Transform3D.IDENTITY
	return { "frame": made[0], "yaw": yaw + (PI / 2.0 if made[3] else 0.0), "x": length / 2.0 - thick, "z": span / 2.0 - thick,
		"height": height, "door": door, "hearth": hearth, "hearth_side": hearth_side }


const WALL_THICK := 0.45
## Half the doorway's width, and its height.
const DOOR_HALF := 0.9
const DOOR_HEIGHT := 2.6
## The planks' color (WOOD in the zones), so it's drawn with their texture.
const FLOOR := Color(0.45, 0.31, 0.2)
const WARM := Color(1.0, 0.8, 0.55)
const IRON := Color(0.16, 0.15, 0.14)
const FLAME := Color(1.0, 0.86, 0.5)


## A room's lamps: lanterns hung from the tie beams down its middle, one every
## 7 yards or so, so a long hall or nave is lit to its far end (one lamp in
## the middle left the ends dark).
static func _room_lights(kit: BuildingKit, length: float, span: float, height: float, energy: float) -> void:
	var count := maxi(1, roundi(length / 7.0))
	var step := length / count
	var reach := maxf(span, step) * 1.1 + 2.0
	for i in count:
		var x := -length / 2.0 + step * (i + 0.5)
		var y := height - 1.1
		kit.beam(Vector3(x, height, 0), Vector3(x, y + 0.3, 0), 0.04, IRON)
		kit.block(Vector3(x, y + 0.25, 0), Vector3(0.36, 0.06, 0.36), IRON)
		kit.block(Vector3(x, y - 0.1, 0), Vector3(0.18, 0.3, 0.18), FLAME)
		kit.block(Vector3(x, y - 0.17, 0), Vector3(0.36, 0.05, 0.36), IRON)
		kit.light(Vector3(x, y - 0.3, 0), WARM, reach, energy * 0.5)
const FIRE := Color(1.0, 0.55, 0.25)


## Walls `thick` thick round a room, open where the door and the windows
## are (`holes`: [middle, outward, half width, half height] each): each wall
## is cut into solid blocks round its openings, on a stone plinth broken
## only by the doorway.
static func _hollow_walls(kit: BuildingKit, length: float, span: float, height: float, thick: float, color: Color, plinth: Color, door: Array, holes: Array = []) -> void:
	var walls := [
		[Vector3(0, 0, span / 2.0 - thick / 2.0), Vector3.RIGHT, length, Vector3.BACK],
		[Vector3(0, 0, -(span / 2.0 - thick / 2.0)), Vector3.RIGHT, length, Vector3.FORWARD],
		[Vector3(length / 2.0 - thick / 2.0, 0, 0), Vector3.BACK, span - thick * 2.0, Vector3.RIGHT],
		[Vector3(-(length / 2.0 - thick / 2.0), 0, 0), Vector3.BACK, span - thick * 2.0, Vector3.LEFT],
	]
	for each: Array in walls:
		var center: Vector3 = each[0]
		var along: Vector3 = each[1]
		var wall_length: float = each[2]
		var out: Vector3 = each[3]
		# This wall's openings: [middle along it, half width, bottom, top].
		var openings := []
		var gap := INF
		if not door.is_empty() and (door[1] as Vector3).dot(out) > 0.9:
			gap = ((door[0] as Vector3) - center).dot(along)
			openings.append([gap, DOOR_HALF, -1.0, DOOR_HEIGHT])
		for hole: Array in holes:
			if (hole[1] as Vector3).dot(out) > 0.9:
				var middle: Vector3 = hole[0]
				openings.append([(middle - center).dot(along), hole[2], middle.y - hole[3], middle.y + hole[3]])
		_wall_around(kit, center, along, wall_length, out, thick, height, color, openings)
		# The plinth runs round all but the doorway.
		var pieces := [[-wall_length / 2.0, wall_length / 2.0]]
		if gap != INF:
			pieces = [[-wall_length / 2.0, gap - DOOR_HALF], [gap + DOOR_HALF, wall_length / 2.0]]
		for piece: Array in pieces:
			var a: float = piece[0]
			var b: float = piece[1]
			if b - a > 0.01:
				kit.block(center + along * (a + b) / 2.0 - Vector3(0, 0.1, 0), along * (b - a) + out.abs() * (thick + 0.3) + Vector3.UP * 0.55, plinth)


## One wall, solid but for its openings: cut at every opening's sides into
## strips, and each strip into the blocks above and below whatever opening
## it passes through.
static func _wall_around(kit: BuildingKit, center: Vector3, along: Vector3, wall_length: float, out: Vector3, thick: float, height: float, color: Color, openings: Array) -> void:
	var half := wall_length / 2.0
	var cuts: Array[float] = [-half, half]
	for opening: Array in openings:
		for edge: float in [opening[0] - opening[1], opening[0] + opening[1]]:
			if edge > -half and edge < half:
				cuts.append(edge)
	cuts.sort()
	for i in cuts.size() - 1:
		var a := cuts[i]
		var b := cuts[i + 1]
		if b - a < 0.01:
			continue
		var middle := (a + b) / 2.0
		# Heights left solid in this strip.
		var spans := [[0.0, height]]
		for opening: Array in openings:
			if absf(middle - float(opening[0])) >= float(opening[1]):
				continue
			var kept := []
			for each: Array in spans:
				if float(opening[2]) > each[0]:
					kept.append([each[0], minf(each[1], float(opening[2]))])
				if float(opening[3]) < each[1]:
					kept.append([maxf(each[0], float(opening[3])), each[1]])
			spans = kept
		for each: Array in spans:
			if each[1] - each[0] > 0.01:
				kit.block(center + along * middle + Vector3.UP * each[0], along * (b - a) + out.abs() * thick + Vector3.UP * (each[1] - each[0]), color, 0.0, true)


## An open doorway: a frame through the wall, a lintel, a step outside, and
## the door standing open against the inside wall.
static func _doorway(kit: BuildingKit, at: Vector3, out: Vector3, thick: float, trim: Color, stone: Color) -> void:
	var across := Vector3(out.z, 0, out.x).abs()
	var through := at - out * (thick / 2.0)
	for s: float in [-1.0, 1.0]:
		kit.block(through + across * s * (DOOR_HALF + 0.05), across * 0.22 + Vector3.UP * (DOOR_HEIGHT + 0.1) + out.abs() * (thick + 0.14), trim)
	kit.block(through + Vector3.UP * DOOR_HEIGHT, across * (DOOR_HALF * 2.0 + 0.5) + Vector3.UP * 0.28 + out.abs() * (thick + 0.16), trim)
	kit.block(at + out * 0.35 - Vector3.UP * 0.12, across * 2.2 + Vector3.UP * 0.25 + out.abs() * 0.7, stone)
	kit.block(at - out * (thick + 0.55) + across * (DOOR_HALF - 0.05), out.abs() * 1.1 + Vector3.UP * (DOOR_HEIGHT - 0.15) + across * 0.08, trim.darkened(0.25))


## A hearth inside an end wall (`side` +1 for +x, -1 for -x): the chimney
## outside the end wall, a stone fireplace with embers and a mantel inside,
## and the fire's light.
static func _hearth(kit: BuildingKit, length: float, span: float, height: float, rise: float, thick: float, stone: Color, trim: Color, side := 1.0) -> void:
	var end := length / 2.0
	kit.block(Vector3(side * (end + 0.45), -0.1, 0), Vector3(0.9, height + rise + 1.0, 1.4), stone)
	kit.block(Vector3(side * (end + 0.45), height + rise + 0.9, 0), Vector3(1.15, 0.22, 1.65), stone)
	var inner := end - thick
	kit.block(Vector3(side * (inner - 0.35), 0, 0), Vector3(0.7, 1.5, 2.1), stone, 0.0, true)
	kit.block(Vector3(side * (inner - 0.71), 0.1, 0), Vector3(0.04, 0.9, 1.2), DARK)
	kit.block(Vector3(side * (inner - 0.6), 0.1, 0), Vector3(0.25, 0.14, 0.9), Color(0.95, 0.45, 0.12))
	kit.block(Vector3(side * (inner - 0.45), 1.5, 0), Vector3(0.95, 0.15, 2.4), trim)
	kit.block(Vector3(side * (inner - 0.2), 1.65, 0), Vector3(0.4, height - 1.65, 1.2), stone)
	kit.light(Vector3(side * (inner - 1.2), 0.8, 0), FIRE, 7.0, 1.6)


## Tie beams across the room under the roof, each with a king post to the
## ridge.
static func _trusses(kit: BuildingKit, length: float, span: float, height: float, rise: float, thick: float, trim: Color) -> void:
	var bays := maxi(int(length / 3.0), 1)
	for i in range(1, bays):
		var x := -length / 2.0 + length * i / bays
		kit.box(Vector3(x, height - 0.15, 0), Vector3(0.25, 0.25, span - thick * 2.0), trim)
		kit.beam(Vector3(x, height - 0.05, 0), Vector3(x, height + rise - 0.25, 0), 0.2, trim)
	kit.beam(Vector3(-length / 2.0 + thick, height + rise - 0.3, 0), Vector3(length / 2.0 - thick, height + rise - 0.3, 0), 0.22, trim)


## A gable roof on walls `height` tall: its ridge along x, `length` long,
## spanning `span` along z, rising `rise`; gable ends filled with `gable`.
## `solid` gives it collision (over a room, so the camera stops at it).
static func roof(kit: BuildingKit, height: float, length: float, span: float, rise: float, color: Color, gable: Color, thatch := false, trim := Color(0.3, 0.2, 0.13), solid := false) -> void:
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
		kit.box(center, Vector3(length + overhang * 2.0, thick, slab), color, Basis(Vector3.RIGHT, normal, along), solid)
	# Gable ends, with a beam along their foot.
	for end: float in [-1.0, 1.0]:
		var outer := kit.frame
		kit.frame = outer * Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(end * (length / 2.0 - 0.05), height, 0))
		kit.wedge(Vector3.ZERO, span, rise, 0.2, gable, solid)
		kit.frame = outer
		kit.box(Vector3(end * (length / 2.0 + 0.02), height + 0.1, 0), Vector3(0.25, 0.25, span + 0.1), trim)
	if thatch:
		kit.beam(Vector3(-length / 2.0 - overhang, height + rise + thick * 0.55, 0), Vector3(length / 2.0 + overhang, height + rise + thick * 0.55, 0), thick * 1.3, color.darkened(0.12))
	else:
		kit.beam(Vector3(-length / 2.0 - overhang, height + rise + thick, 0), Vector3(length / 2.0 + overhang, height + rise + thick, 0), 0.3, color.darkened(0.25))


## Dark timber over the walls: corner posts, sill, top plate, studs and
## braces (and a band between storeys).
static func _timber(kit: BuildingKit, length: float, span: float, height: float, storeys: int, trim: Color, windows: Array = []) -> void:
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
			# Not across a window.
			var clear := true
			for place: Array in windows:
				var at: Vector3 = place[0]
				if signf(at.z) == z and absf(at.x - x) < 0.7:
					clear = false
			if clear:
				kit.box(Vector3(x, height / 2.0, face), Vector3(0.2, height - 0.4, 0.12), trim)
		for end: float in [-1.0, 1.0]:
			var corner := end * length / 2.0
			kit.beam(Vector3(corner - end * 0.2, 0.55, face), Vector3(corner - end * minf(1.6, length / bays), minf(height - 0.3, height / storeys), face), 0.16, trim)
	# Studs on the ends.
	for x: float in [-1.0, 1.0]:
		kit.box(Vector3(x * (length / 2.0 + out), height / 2.0, 0), Vector3(0.12, height - 0.4, 0.2), trim)


## Where a house's windows go: along the long walls (two rows for two
## storeys) and one in each end; not where the door is, nor in the hearth's
## end. Each is [middle (on the outer face), outward, half width, half
## height].
const WINDOW_HALF_WIDTH := 0.45
const WINDOW_HALF_HEIGHT := 0.55


static func _window_places(length: float, span: float, height: float, storeys: int, door: Array, hearth_side := 0.0) -> Array:
	var places := []
	var rows: Array[float] = []
	rows.assign([height * 0.5] if storeys == 1 else [height * 0.27, height * 0.73])
	var count := maxi(int(length / 3.2), 1)
	for z: float in [-1.0, 1.0]:
		for i in count:
			var x := -length / 2.0 + length * (i + 0.5) / count
			var at := Vector3(x, 0, z * span / 2.0)
			for y: float in rows:
				if not door.is_empty() and at.distance_to(door[0]) < 1.6 and y < 2.8:
					continue
				places.append([at + Vector3.UP * y, Vector3(0, 0, z), WINDOW_HALF_WIDTH, WINDOW_HALF_HEIGHT])
	for x: float in [-1.0, 1.0]:
		var at := Vector3(x * length / 2.0, 0, 0)
		if (not door.is_empty() and at.distance_to(door[0]) < 1.6) or x == hearth_side:
			continue
		places.append([at + Vector3.UP * rows[0], Vector3(x, 0, 0), WINDOW_HALF_WIDTH, WINDOW_HALF_HEIGHT])
	return places


## A window, `at` the middle of its outer face. In a solid wall, a dark
## pane; in a wall `thick` thick (a room), an opening you see through, lined
## with a wooden frame, a mullion and transom across it, sills inside and
## out. Shutters stand open either side.
static func _window(kit: BuildingKit, at: Vector3, out: Vector3, trim: Color, shutter: Color, thick := 0.0) -> void:
	var across := Vector3(out.z, 0, -out.x).abs()
	var w := WINDOW_HALF_WIDTH * 2.0
	var h := WINDOW_HALF_HEIGHT * 2.0
	if thick > 0.0:
		var middle := at - out * (thick / 2.0)
		var deep := out.abs() * (thick + 0.04)
		for side: float in [-1.0, 1.0]:
			kit.box(middle + across * side * (w / 2.0 - 0.04), across * 0.08 + Vector3.UP * h + deep, trim)
			kit.box(middle + Vector3.UP * side * (h / 2.0 - 0.04), across * w + Vector3.UP * 0.08 + deep, trim)
		kit.box(middle, across * 0.06 + Vector3.UP * h + out.abs() * 0.07, trim.darkened(0.2))
		kit.box(middle + Vector3.UP * 0.1, across * w + Vector3.UP * 0.06 + out.abs() * 0.07, trim.darkened(0.2))
		kit.box(at - out * (thick + 0.08) - Vector3.UP * (h / 2.0 + 0.05), across * (w + 0.25) + Vector3.UP * 0.1 + out.abs() * 0.2, trim)
	else:
		kit.box(at + out * 0.03, across * w + Vector3.UP * h + out.abs() * 0.06, GLASS)
		kit.box(at + out * 0.06, across * 0.08 + Vector3.UP * h + out.abs() * 0.05, trim)
	kit.box(at + out * 0.06 + Vector3.UP * (h / 2.0 + 0.04), across * (w + 0.2) + Vector3.UP * 0.12 + out.abs() * 0.1, trim)
	kit.box(at + out * 0.1 - Vector3.UP * (h / 2.0 + 0.05), across * (w + 0.35) + Vector3.UP * 0.12 + out.abs() * 0.25, trim)
	for side: float in [-1.0, 1.0]:
		kit.box(at + out * 0.06 + across * side * (w / 2.0 + 0.26), across * 0.46 + Vector3.UP * h + out.abs() * 0.06, shutter)


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
## `hollow` opens it: a stone floor, rows of pews either side of a carpeted
## aisle up to the altar at the far wall, candles, trusses and light.
static func chapel(kit: BuildingKit, base: Vector3, size: Vector3, yaw: float, look: Dictionary, door_side: Vector2,
		tower_at: Vector2, tower_size: float, tower_height: float, hollow := false) -> Dictionary:
	kit.footprint(base, size, yaw)
	var made := _frame(base, size, yaw)
	kit.frame = made[0]
	var length: float = made[1]
	var span: float = made[2]
	var height := size.y
	var wall: Color = look.wall
	var trim: Color = _look(look, "trim", Color(0.3, 0.2, 0.13))
	var stone: Color = _look(look, "stone", Color(0.45, 0.43, 0.41))
	var placed := _door_place(size, door_side, 0.0, made[3])
	var face: Vector3 = placed[0]
	var out: Vector3 = placed[1]
	var thick := 0.6 if hollow else 0.0
	# Lancets along the long walls between the buttresses, and one in each
	# end: [bottom middle (on the outer face), outward, height].
	var bays := maxi(int(length / 3.0), 2)
	var lancets := []
	for z: float in [-1.0, 1.0]:
		for i in bays:
			var x := -length / 2.0 + length * (i + 0.5) / bays
			if Vector3(x, 0, z * span / 2.0).distance_to(face) >= 1.6:
				lancets.append([Vector3(x, height * 0.3, z * span / 2.0), Vector3(0, 0, z), height * 0.45])
	for x: float in [-1.0, 1.0]:
		if Vector3(x * length / 2.0, 0, 0).distance_to(face) > 1.6:
			lancets.append([Vector3(x * length / 2.0, height * 0.3, 0), Vector3(x, 0, 0), height * 0.5])
	if hollow:
		var holes := []
		for lancet: Array in lancets:
			var bottom: Vector3 = lancet[0]
			holes.append([bottom + Vector3.UP * (float(lancet[2]) / 2.0), lancet[1], LANCET_HALF_WIDTH, float(lancet[2]) / 2.0])
		_hollow_walls(kit, length, span, height, thick, wall, stone, placed, holes)
		kit.block(Vector3(0, -0.05, 0), Vector3(length - thick * 2.0, 0.15, span - thick * 2.0), _look(look, "floor", wall), 0.0, true)
	else:
		kit.block(Vector3.ZERO, Vector3(length, height, span), wall, 0.0, true)
		kit.block(Vector3(0, -0.1, 0), Vector3(length + 0.5, 0.7, span + 0.5), stone)
	# A course under the eaves.
	kit.block(Vector3(0, height - 0.35, 0), Vector3(length + 0.25, 0.3, span + 0.25), stone)
	for z: float in [-1.0, 1.0]:
		for i in bays + 1:
			var x := -length / 2.0 + length * i / bays
			# Buttresses, stepped.
			kit.block(Vector3(x, 0, z * (span / 2.0 + 0.35)), Vector3(0.7, height * 0.75, 0.7), stone)
			kit.block(Vector3(x, height * 0.75, z * (span / 2.0 + 0.2)), Vector3(0.6, height * 0.15, 0.4), stone)
	for lancet: Array in lancets:
		_lancet(kit, lancet[0], lancet[1], lancet[2], stone, thick)
	# The arched door (open, in a hollow chapel).
	var across := Vector3(out.z, 0, out.x).abs()
	if hollow:
		_doorway(kit, face, out, thick, trim, stone)
	else:
		kit.block(face + out * 0.05, across * 1.6 + Vector3.UP * 2.6 + out.abs() * 0.12, trim.darkened(0.2))
	var outer := kit.frame
	kit.frame = outer * Transform3D(Basis(Vector3.UP, atan2(out.x, out.z)), face + out * 0.08 + Vector3.UP * (DOOR_HEIGHT + 0.25 if hollow else 2.6))
	if not hollow:
		kit.wedge(Vector3.ZERO, 1.6, 0.9, 0.12, trim.darkened(0.2))
	kit.wedge(Vector3(0, -0.05, 0.05), 2.2, 1.2, 0.2, stone)
	kit.frame = outer
	for s: float in [-1.0, 1.0]:
		kit.block(face + out * 0.15 + across * s * 1.25, across * 0.35 + Vector3.UP * 2.9 + out.abs() * 0.3, stone)
	if not hollow:
		kit.block(face + out * 0.5 - Vector3.UP * 0.1, across * 2.4 + Vector3.UP * 0.3 + out.abs() * 1.0, stone)
	var rise := span * 0.7
	roof(kit, height, length, span, rise, look.roof, wall, false, trim, hollow)
	var room := { "frame": made[0], "yaw": yaw + (PI / 2.0 if made[3] else 0.0), "x": length / 2.0 - thick, "z": span / 2.0 - thick,
		"height": height, "door": placed, "hearth": false }
	if hollow:
		_trusses(kit, length, span, height, rise, thick, trim)
		_room_lights(kit, length, span, height, 1.0)
		kit.dust(Vector3(0, (height + rise * 0.5) / 2.0, 0), Vector3(length - thick * 2.0, height + rise * 0.5, span - thick * 2.0))
	kit.frame = Transform3D.IDENTITY
	if hollow:
		_furnish_chapel(kit, room, look)
	if tower_size > 0.0:
		bell_tower(kit, base + Basis(Vector3.UP, yaw) * Vector3(tower_at.x, 0, tower_at.y), tower_size, tower_height, look)
	return room


## A tall narrow window, `at` the middle of its foot on the outer face,
## with a stone sill and a pointed hood. In a solid wall a dark pane with a
## pointed top; in a wall `thick` thick, an opening you see through,
## crossed by lead bars, with a sill inside too.
const LANCET_HALF_WIDTH := 0.35
const LEAD := Color(0.16, 0.16, 0.18)


static func _lancet(kit: BuildingKit, at: Vector3, out: Vector3, height: float, stone: Color, thick := 0.0) -> void:
	var across := Vector3(out.z, 0, -out.x).abs()
	var w := LANCET_HALF_WIDTH * 2.0
	kit.block(at + out * 0.05 - Vector3.UP * 0.12, across * (w + 0.3) + Vector3.UP * 0.12 + out.abs() * 0.2, stone)
	var outer := kit.frame
	kit.frame = outer * Transform3D(Basis(Vector3.UP, atan2(out.x, out.z)), at + out * 0.04 + Vector3.UP * height)
	if thick <= 0.0:
		kit.wedge(Vector3.ZERO, w, 0.45, 0.06, GLASS)
	kit.wedge(Vector3(0, 0, 0.03), w + 0.3, 0.65, 0.08, stone)
	kit.frame = outer
	if thick > 0.0:
		var middle := at - out * (thick / 2.0) + Vector3.UP * (height / 2.0)
		kit.box(middle, across * 0.05 + Vector3.UP * height + out.abs() * 0.05, LEAD)
		for t: float in [-0.25, 0.1]:
			kit.box(middle + Vector3.UP * height * t, across * w + Vector3.UP * 0.05 + out.abs() * 0.05, LEAD)
		kit.block(at - out * (thick + 0.08) - Vector3.UP * 0.12, across * (w + 0.2) + Vector3.UP * 0.12 + out.abs() * 0.2, stone)
	else:
		kit.block(at + out * 0.03, across * w + Vector3.UP * height + out.abs() * 0.06, GLASS)


# Furnishing rooms (from house and chapel): positions in the room's own
# terms (+x the hearth end, door where the room says), drawn in the world.

## A point in a room's terms, in the world.
static func _at(room: Dictionary, x: float, z: float) -> Vector3:
	return (room.frame as Transform3D) * Vector3(x, 0.1, z)


## Which way a room's door faces, as a sign along z (or along x when the
## door is on an end): [axis "x" or "z", sign].
static func _door_axis(room: Dictionary) -> Array:
	var out: Vector3 = room.door[1] if not (room.door as Array).is_empty() else Vector3.BACK
	return ["x", signf(out.x)] if absf(out.x) > 0.5 else ["z", signf(out.z)]


## Fills a room: "cottage" (a bed, a table and stools, a shelf, a barrel),
## "hall" (a long table with benches, banners, a rug), or "inn" (a bar
## with its barrels and the keeper's place behind it, tables and stools).
## Returns named spots in the world ("keeper" for an inn).
static func furnish(kit: BuildingKit, room: Dictionary, kind: String, look: Dictionary) -> Dictionary:
	var wood: Color = _look(look, "furniture", FLOOR)
	var trim: Color = _look(look, "trim", Color(0.3, 0.2, 0.13))
	var cloth: Color = _look(look, "cloth", Color(0.55, 0.22, 0.17))
	var hx: float = room.x
	var hz: float = room.z
	var yaw: float = room.yaw
	var axis := _door_axis(room)
	# The wall away from the door (along z when the door's on a long wall).
	var back: float = -axis[1] * (hz - 0.6) if axis[0] == "z" else -(hz - 0.6)
	var spots := {}
	match kind:
		"cottage":
			# The bed at the end away from the hearth, along the back wall.
			var hs: float = room.get("hearth_side", 1.0)
			bed(kit, _at(room, -hs * (hx - 1.15), back * 0.85), yaw + (0.0 if hs > 0.0 else PI), Color(0.5, 0.18, 0.15))
			table(kit, _at(room, 0.0, 0.0), yaw, 1.4, 0.9, wood)
			for side: float in [-1.0, 1.0]:
				stool(kit, _at(room, side * 1.1, 0.0), wood)
			shelf(kit, _at(room, hs * 0.6, back), yaw + (PI if back > 0.0 else 0.0), wood)
			barrel(kit, _at(room, hs * (hx - 0.6), -back * 0.85), 0.4, 0.9, wood)
		"hall":
			var long := hx * 1.3
			table(kit, _at(room, -0.3, 0.0), yaw, long, 1.2, wood)
			for side: float in [-1.0, 1.0]:
				bench(kit, _at(room, -0.3, side * 1.1), yaw, long - 0.4, wood)
			rug(kit, _at(room, -0.3, 0.0), yaw, long + 1.6, 3.4, cloth)
			# Banners between the windows (_window_places spaces those).
			var length := (hx + WALL_THICK) * 2.0
			var count := maxi(int(length / 3.2), 1)
			for i in range(1, count):
				for side: float in [-1.0, 1.0]:
					banner(kit, _at(room, -length / 2.0 + length * i / count, side * (hz - 0.02)) + Vector3.UP * 2.0, yaw + (0.0 if side < 0.0 else PI), cloth if i % 2 == 1 else Color(0.2, 0.3, 0.55))
		"inn":
			# The bar across the back, the keeper behind it, barrels on the wall.
			var bar_z := back * 0.62
			counter(kit, _at(room, -hx * 0.25, bar_z), yaw, hx * 1.1, wood, trim)
			spots.keeper = _at(room, -hx * 0.25, back * 0.95)
			for i in 4:
				barrel(kit, _at(room, -hx * 0.95 + i * 0.9, back * 1.05), 0.42, 0.95, wood)
			shelf(kit, _at(room, hx * 0.35, back), yaw + (PI if back > 0.0 else 0.0), wood)
			# Tables in the front half, clear of the door.
			var door_x: float = (room.door[0] as Vector3).x if not (room.door as Array).is_empty() else 99.0
			for i in 3:
				var x := -hx * 0.7 + hx * 0.7 * i
				if absf(x - door_x) < 1.6:
					x += 1.8
				var z := -back * 0.35
				table(kit, _at(room, x, z), yaw, 1.1, 1.1, wood)
				for side: float in [-1.0, 1.0]:
					stool(kit, _at(room, x + side * 0.9, z), wood)
	return spots


## The chapel's pews, aisle, altar and candles: the aisle runs from the door
## to the far wall, pews in rows either side, the altar at the end.
static func _furnish_chapel(kit: BuildingKit, room: Dictionary, look: Dictionary) -> void:
	var frame: Transform3D = room.frame
	var door_at: Vector3 = room.door[0]
	var out: Vector3 = room.door[1]
	var deep: Vector3 = -out
	var side_axis := Vector3(absf(out.z), 0, absf(out.x))
	var depth: float = (room.z if absf(out.z) > 0.5 else room.x) * 2.0
	var width: float = (room.x if absf(out.z) > 0.5 else room.z) * 2.0
	var start := door_at + deep * (0.6 if absf(out.z) > 0.5 else 0.6)
	var wood := FLOOR
	var cloth := Color(0.55, 0.15, 0.13)
	var stone: Color = _look(look, "stone", Color(0.45, 0.43, 0.41))
	# Pews face -z in their own terms, so turned by this their backs are to
	# the door; the altar's front (+z) faces the door.
	var face_yaw: float = room.yaw + atan2(out.x, out.z)
	var pew_length := minf(3.6, width / 2.0 - 1.6)
	var row := 2.6
	while row < depth - 3.6:
		for s: float in [-1.0, 1.0]:
			pew(kit, frame * (start + deep * row + side_axis * s * (0.95 + pew_length / 2.0) + Vector3.UP * 0.1), face_yaw, pew_length, wood)
		row += 1.5
	rug(kit, frame * (start + deep * (depth / 2.0 - 0.6) + Vector3.UP * 0.1), face_yaw, 1.5, depth - 1.6, cloth)
	altar(kit, frame * (start + deep * (depth - 1.85) + Vector3.UP * 0.1), face_yaw, stone, Color(0.85, 0.82, 0.72))


# Furniture: each at `at` (the middle of its foot) turned by `yaw`.

static func table(kit: BuildingKit, at: Vector3, yaw: float, sx: float, sz: float, wood: Color) -> void:
	kit.frame = Transform3D(Basis(Vector3.UP, yaw), at)
	kit.block(Vector3(0, 0.75, 0), Vector3(sx, 0.1, sz), wood)
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			kit.block(Vector3(x * (sx / 2.0 - 0.12), 0, z * (sz / 2.0 - 0.12)), Vector3(0.12, 0.75, 0.12), wood.darkened(0.2))
	kit.collider(Vector3(0, 0.42, 0), Vector3(sx, 0.85, sz))
	kit.frame = Transform3D.IDENTITY


static func bench(kit: BuildingKit, at: Vector3, yaw: float, length: float, wood: Color) -> void:
	kit.frame = Transform3D(Basis(Vector3.UP, yaw), at)
	kit.block(Vector3(0, 0.4, 0), Vector3(length, 0.08, 0.4), wood)
	for x: float in [-1.0, 1.0]:
		kit.block(Vector3(x * (length / 2.0 - 0.2), 0, 0), Vector3(0.1, 0.4, 0.35), wood.darkened(0.2))
	kit.collider(Vector3(0, 0.22, 0), Vector3(length, 0.45, 0.4))
	kit.frame = Transform3D.IDENTITY


static func stool(kit: BuildingKit, at: Vector3, wood: Color) -> void:
	kit.frame = Transform3D(Basis(), at)
	kit.cylinder(Vector3.ZERO, 0.2, 0.42, wood.darkened(0.15), 6)
	kit.cylinder(Vector3(0, 0.42, 0), 0.24, 0.06, wood, 6)
	kit.frame = Transform3D.IDENTITY


## A bed along x, its head at -x.
static func bed(kit: BuildingKit, at: Vector3, yaw: float, blanket: Color) -> void:
	kit.frame = Transform3D(Basis(Vector3.UP, yaw), at)
	kit.block(Vector3.ZERO, Vector3(2.1, 0.35, 1.1), FLOOR.darkened(0.15))
	kit.block(Vector3(0, 0.35, 0), Vector3(1.95, 0.18, 0.98), Color(0.8, 0.76, 0.66))
	kit.block(Vector3(0.25, 0.53, 0), Vector3(1.4, 0.06, 1.02), blanket)
	kit.block(Vector3(-0.75, 0.53, 0), Vector3(0.35, 0.12, 0.7), Color(0.92, 0.9, 0.84))
	kit.block(Vector3(-1.05, 0, 0), Vector3(0.1, 0.95, 1.1), FLOOR.darkened(0.25))
	kit.collider(Vector3(0, 0.3, 0), Vector3(2.1, 0.6, 1.1))
	kit.frame = Transform3D.IDENTITY


## Shelves against a wall at its back (-z), with jars and a pot.
static func shelf(kit: BuildingKit, at: Vector3, yaw: float, wood: Color) -> void:
	kit.frame = Transform3D(Basis(Vector3.UP, yaw), at)
	kit.block(Vector3(0, 0, -0.05), Vector3(1.6, 1.9, 0.08), wood.darkened(0.2))
	for y: float in [0.5, 1.1, 1.7]:
		kit.block(Vector3(0, y, 0.12), Vector3(1.6, 0.06, 0.38), wood)
	var jars := [Color(0.55, 0.6, 0.5), Color(0.6, 0.45, 0.3), Color(0.4, 0.42, 0.55), Color(0.7, 0.68, 0.6)]
	for i in 6:
		kit.cylinder(Vector3(-0.6 + (i % 3) * 0.6, 0.56 + (i / 3) * 0.6, 0.12), 0.1, 0.22, jars[i % jars.size()], 6)
	kit.collider(Vector3(0, 0.95, 0.12), Vector3(1.6, 1.9, 0.45))
	kit.frame = Transform3D.IDENTITY


## A bar counter along x, its front to +z.
static func counter(kit: BuildingKit, at: Vector3, yaw: float, length: float, wood: Color, trim: Color) -> void:
	kit.frame = Transform3D(Basis(Vector3.UP, yaw), at)
	kit.block(Vector3.ZERO, Vector3(length, 1.05, 0.6), wood, 0.0, true)
	kit.block(Vector3(0, 1.05, 0.05), Vector3(length + 0.15, 0.1, 0.8), trim)
	for i in int(length / 1.2):
		kit.block(Vector3(-length / 2.0 + 0.6 + i * 1.2, 0, 0.31), Vector3(0.12, 1.05, 0.04), trim)
	for i in 3:
		kit.cylinder(Vector3(-length / 3.0 + i * 0.5, 1.15, 0.05), 0.07, 0.18, Color(0.75, 0.75, 0.7), 6)
	kit.frame = Transform3D.IDENTITY


## A pew facing -z: a seat and a back.
static func pew(kit: BuildingKit, at: Vector3, yaw: float, length: float, wood: Color) -> void:
	kit.frame = Transform3D(Basis(Vector3.UP, yaw), at)
	kit.block(Vector3(0, 0.42, 0), Vector3(length, 0.08, 0.45), wood)
	kit.block(Vector3(0, 0.46, 0.2), Vector3(length, 0.6, 0.07), wood)
	for x: float in [-1.0, 1.0]:
		kit.block(Vector3(x * (length / 2.0 - 0.05), 0, 0.05), Vector3(0.1, 1.05, 0.55), wood.darkened(0.2))
	kit.collider(Vector3(0, 0.5, 0.05), Vector3(length, 1.0, 0.55))
	kit.frame = Transform3D.IDENTITY


## An altar, its back to -z and its front (+z) to whoever stands before
## it: stone with a cloth, a hanging, candlesticks, a cross and their light.
static func altar(kit: BuildingKit, at: Vector3, yaw: float, stone: Color, cloth: Color) -> void:
	kit.frame = Transform3D(Basis(Vector3.UP, yaw), at)
	kit.block(Vector3(0, -0.1, 0), Vector3(3.4, 0.3, 2.0), stone)
	kit.block(Vector3.ZERO, Vector3(2.2, 1.0, 0.9), stone, 0.0, true)
	kit.block(Vector3(0, 1.0, 0), Vector3(2.3, 0.05, 1.0), cloth)
	kit.block(Vector3(0, 0.3, 0.47), Vector3(0.9, 0.75, 0.04), Color(0.6, 0.15, 0.13))
	for x: float in [-0.8, 0.8]:
		kit.cylinder(Vector3(x, 1.05, -0.15), 0.06, 0.4, Color(0.75, 0.62, 0.3), 6)
		kit.cylinder(Vector3(x, 1.45, -0.15), 0.035, 0.12, Color(1.0, 0.85, 0.5), 6)
	kit.beam(Vector3(0, 1.05, -0.3), Vector3(0, 1.75, -0.3), 0.08, Color(0.75, 0.62, 0.3))
	kit.beam(Vector3(-0.22, 1.55, -0.3), Vector3(0.22, 1.55, -0.3), 0.07, Color(0.75, 0.62, 0.3))
	kit.light(Vector3(0, 1.8, 0.6), Color(1.0, 0.82, 0.55), 6.0, 1.2)
	kit.frame = Transform3D.IDENTITY


## A rug or runner on the floor, `sx` by `sz`, with a darker border.
static func rug(kit: BuildingKit, at: Vector3, yaw: float, sx: float, sz: float, color: Color) -> void:
	kit.frame = Transform3D(Basis(Vector3.UP, yaw), at)
	kit.block(Vector3(0, 0.0, 0), Vector3(sx, 0.03, sz), color.darkened(0.3))
	kit.block(Vector3(0, 0.01, 0), Vector3(sx - 0.3, 0.03, sz - 0.3), color)
	kit.frame = Transform3D.IDENTITY


## A banner hanging on a wall, its face to +z.
static func banner(kit: BuildingKit, at: Vector3, yaw: float, color: Color) -> void:
	kit.frame = Transform3D(Basis(Vector3.UP, yaw), at)
	kit.box(Vector3(0, 0.9, 0.05), Vector3(1.1, 0.08, 0.08), Color(0.3, 0.2, 0.13))
	kit.box(Vector3(0, 0.0, 0.06), Vector3(0.9, 1.7, 0.04), color)
	kit.box(Vector3(0, 0.1, 0.085), Vector3(0.35, 0.35, 0.02), Color(0.85, 0.75, 0.35))
	kit.frame = Transform3D.IDENTITY


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
	kit.footprint(base, size, yaw)
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
