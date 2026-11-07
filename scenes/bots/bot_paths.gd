class_name BotPaths
extends RefCounted
## Ways round obstacles for playerbots: houses, fences, walls, trees, rocks
## and steep ground, anything solid in the world (physics layer 1) that a
## straight walk runs into. A bot that stops getting anywhere asks for a
## detour (Bot._move): a grid search (AStarGrid2D) over the yards around it
## and its next waypoint, each cell found open or blocked by a physics test of
## a bot-sized box above the ground, kept so later detours cost little, then
## straightened into as few waypoints as can see each other. Far bots walk
## without collision and may stand in a wall when they come near the player:
## free_spot moves them out.

## Yards per cell, and the box tested at each: about a bot's width, from just
## above the ground (small steps and bumps are fine) to above its head.
const CELL := 1.0
const BOX_HALF := Vector3(0.55, 0.65, 0.55)
const BOX_LIFT := 1.0
## Yards searched round the bot and its goal, and the furthest goal a detour
## goes for (beyond, it heads for a point that far along the way).
const MARGIN := 14
const REACH := 56.0
## Detours worked out a physics frame at most: a fresh one tests up to a few
## thousand cells (several milliseconds), so many stuck at once take turns.
const PER_FRAME := 2
var _frame := -1
var _this_frame := 0
## Cells known: true blocked, false open.
var _cells := {}
var _manager: BotManager
var _box := BoxShape3D.new()
var _query := PhysicsShapeQueryParameters3D.new()


func _init(manager: BotManager) -> void:
	_manager = manager
	_box.size = BOX_HALF * 2.0
	_query.shape = _box
	_query.collision_mask = 1


static func cell_of(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / CELL), floori(point.z / CELL))


func _center(cell: Vector2i) -> Vector3:
	var x := (cell.x + 0.5) * CELL
	var z := (cell.y + 0.5) * CELL
	return Vector3(x, _manager.ground_height(x, z), z)


func blocked(cell: Vector2i) -> bool:
	var known: Variant = _cells.get(cell)
	if known != null:
		return known
	var at := _center(cell)
	_query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * BOX_LIFT)
	var hit := not _manager.space_state().intersect_shape(_query, 1).is_empty()
	_cells[cell] = hit
	return hit


## Whether this frame's detours are used up.
func busy() -> bool:
	return Engine.get_physics_frames() == _frame and _this_frame >= PER_FRAME


func blocked_at(point: Vector3) -> bool:
	return blocked(cell_of(point))


## Waypoints from `from` round whatever is in the way towards `to` (or a point
## REACH yards along the way), ending at `to`'s cell; empty when there's no
## way within the search, or too many bots asked this frame.
func detour(from: Vector3, to: Vector3) -> Array[Vector3]:
	if Engine.get_physics_frames() != _frame:
		_frame = Engine.get_physics_frames()
		_this_frame = 0
	if _this_frame >= PER_FRAME:
		return []
	_this_frame += 1
	var goal := to
	var flat := Vector2(to.x - from.x, to.z - from.z)
	if flat.length() > REACH:
		flat = flat.normalized() * REACH
		goal = Vector3(from.x + flat.x, to.y, from.z + flat.y)
	var start := cell_of(from)
	var end := cell_of(goal)
	var low := Vector2i(mini(start.x, end.x), mini(start.y, end.y)) - Vector2i.ONE * MARGIN
	var high := Vector2i(maxi(start.x, end.x), maxi(start.y, end.y)) + Vector2i.ONE * MARGIN
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(low, high - low + Vector2i.ONE)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			var cell := Vector2i(x, y)
			if cell != start and blocked(cell):
				grid.set_point_solid(cell)
	var cells := grid.get_id_path(start, end, true)
	if cells.size() < 2:
		return []
	# Straighten: from each kept cell, on to the furthest one in plain sight.
	var kept: Array[Vector2i] = [cells[0]]
	var i := 0
	while i < cells.size() - 1:
		var next := i + 1
		for j in range(cells.size() - 1, i + 1, -1):
			if _clear(cells[i], cells[j]):
				next = j
				break
		kept.append(cells[next])
		i = next
	var points: Array[Vector3] = []
	for cell in kept.slice(1):
		points.append(_center(cell))
	return points


## Whether a bot can walk straight from one cell to another: no blocked cell
## on the line between them, nor beside it where it cuts a corner.
func _clear(a: Vector2i, b: Vector2i) -> bool:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y)) * 2
	for s in range(1, steps):
		var t := float(s) / steps
		var x := lerpf(a.x, b.x, t)
		var y := lerpf(a.y, b.y, t)
		for cell: Vector2i in [Vector2i(floori(x + 0.5), floori(y + 0.5)), Vector2i(floori(x + 0.2), floori(y + 0.2)), Vector2i(floori(x + 0.8), floori(y + 0.8))]:
			if blocked(cell):
				return false
	return true


## The nearest open place to a point (itself when it's open), within a few
## yards; the point when there's none.
func free_spot(point: Vector3) -> Vector3:
	var here := cell_of(point)
	if not blocked(here):
		return point
	for ring in range(1, 8):
		var best := Vector2i.ZERO
		var best_distance := INF
		for x in range(-ring, ring + 1):
			for y in range(-ring, ring + 1):
				if maxi(absi(x), absi(y)) != ring:
					continue
				var cell := here + Vector2i(x, y)
				if not blocked(cell):
					var distance := _center(cell).distance_to(point)
					if distance < best_distance:
						best_distance = distance
						best = cell
		if best_distance < INF:
			return _center(best) + Vector3.UP * 0.2
	return point
