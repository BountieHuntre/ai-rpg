class_name GatherNodes
extends Node3D
## A zone's herbs and ore (GatherNode), scattered by its ground: herbs on
## grass and forest floor (never on rock, roads, water or buildings' ground),
## ore where classic's lies, at the foot of steep ground: where a mountain's
## or a hill's slope meets level ground (its rocky places first), set into the
## rise, and in its caves at the foot of the walls. How many depends on the zone's area; which kinds on whether
## it's a starting zone (Zone.gather_kinds). Spots are found once from the
## zone's seed, a pool of several for each node, and an emptied node comes
## back after its respawn time at another free spot of the pool, as classic's
## pooled spawns move about.

## Nodes per 400 by 400 yards (a starting zone's size).
const HERBS_PER_AREA := 20.0
const ORE_PER_AREA := 8.0
## Spots in the pool for each node, so respawns move.
const POOL := 3
## No spot within this of another, nor of the zone's hub (its town).
const SPACING := 12.0
const HUB_CLEAR := 40.0
## Steepest ground a node stands on (its normal's height).
const HERB_FLAT := 0.8
const ORE_FLAT := 0.7
## Ore stands at the foot of steep ground: within FOOT_NEAR yards the ground
## rises at least FOOT_RISE, and keeps rising to FOOT_HIGH by twice as far.
const FOOT_NEAR := 2.5
const FOOT_RISE := 1.4
const FOOT_HIGH := 2.6
## How far into the rise a node is set, so it sits in the slope.
const FOOT_SET := 0.5
## Places whose names say they're mines or rock: ore spots there whatever
## the ground shows.
const MINE_WORDS := ["delve", "mine", "hollow", "quarry", "dig", "cave", "rock", "crag"]

var zone: Zone
## Free spots by kind (Vector3).
var spots := { "herb": [], "ore": [] }
## Ore spots inside the zone's caves (Zone.cave_ore_spots): in the pool like
## any spot, but not checked for a roof, and filled first.
var cave_spots: Array[Vector3] = []
## The way a node on a spot faces (out of its slope or wall), by spot.
var facings := {}
## [unix time, kind] of emptied nodes waiting to come back.
var waiting: Array = []
var _rng := RandomNumberGenerator.new()
var _check := 0.0
## How many of each kind to put out once the zone is in the world (its
## spots are checked against its bodies first: boulders, trunks, walls).
var _first: Dictionary = {}
## Furthest up the edge mountains a node may stand (Zone.edge_ring).
const EDGE_LIMIT := 0.12


## Scatters a zone's nodes (Zone.spawn_creatures calls it, the ground built).
static func populate(owner: Zone, rng_seed: int, water_level: float) -> GatherNodes:
	var field := GatherNodes.new()
	field.name = "GatherNodes"
	field.zone = owner
	field._rng.seed = rng_seed
	owner.add_child(field)
	var area := owner.size * owner.size / (400.0 * 400.0)
	for kind: String in ["herb", "ore"]:
		var count := roundi((HERBS_PER_AREA if kind == "herb" else ORE_PER_AREA) * area)
		if (owner.gather_kinds().get(kind, {}) as Dictionary).is_empty():
			continue
		field.spots[kind] = field._find_spots(kind, count * POOL, water_level)
		field._first[kind] = count
		if kind == "ore":
			for vein: Array in owner.cave_ore_spots():
				field.cave_spots.append(vein[0])
				field.facings[vein[0]] = vein[1]
			field._first[kind] = count + field.cave_spots.size()
	return field


## Once in the world: drops spots something stands on (a boulder, a tree,
## a building's floor), found by a ray down to the ground, then puts out the
## first nodes.
func _physics_process(_delta: float) -> void:
	if _first.is_empty():
		set_physics_process(false)
		return
	var space := get_world_3d().direct_space_state
	for kind: String in spots:
		spots[kind] = (spots[kind] as Array).filter(func(spot: Vector3) -> bool: return kind == "ore" and facings.has(spot) and spot in cave_spots or _clear(space, spot))
	# The caves' veins: one on each spot first, and in the pool after.
	if _first.has("ore"):
		for spot: Vector3 in cave_spots:
			_spawn_at("ore", spot)
		(spots["ore"] as Array).append_array(cave_spots)
		_first["ore"] = int(_first["ore"]) - cave_spots.size()
	for kind: String in _first:
		for i in mini(int(_first[kind]), spots[kind].size()):
			_spawn(kind)
	_first.clear()
	set_physics_process(false)


func _clear(space: PhysicsDirectSpaceState3D, spot: Vector3) -> bool:
	for offset: Vector3 in [Vector3.ZERO, Vector3(0.6, 0, 0), Vector3(-0.6, 0, 0), Vector3(0, 0, 0.6), Vector3(0, 0, -0.6)]:
		var at := spot + offset
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3(0, 6, 0), at - Vector3(0, 1, 0), 1)
		var hit := space.intersect_ray(ray)
		if not hit.is_empty() and (hit.position as Vector3).y > zone.ground_height(at.x, at.z) + 0.3:
			return false
	return true


func _find_spots(kind: String, wanted: int, water_level: float) -> Array:
	var found: Array = []
	var half := zone.size / 2.0 - 20.0
	if kind == "ore":
		# The feet of slopes in mines and rocky places first, then anywhere.
		for place: Array in zone.places:
			var name := str(place[0]).to_lower()
			if not MINE_WORDS.any(func(word: String) -> bool: return word in name):
				continue
			for attempt in 40:
				var angle := _rng.randf() * TAU
				var p: Vector2 = place[1] + Vector2(cos(angle), sin(angle)) * sqrt(_rng.randf()) * (float(place[2]) + 20.0)
				var spot := _ore_foot(p, water_level, found)
				if spot != Vector3.INF:
					found.append(spot)
		for attempt in wanted * 80:
			if found.size() >= wanted:
				break
			var p := zone.center + Vector2(_rng.randf_range(-half, half), _rng.randf_range(-half, half))
			var spot := _ore_foot(p, water_level, found)
			if spot != Vector3.INF:
				found.append(spot)
		return found
	for attempt in wanted * 40:
		if found.size() >= wanted:
			break
		var p := zone.center + Vector2(_rng.randf_range(-half, half), _rng.randf_range(-half, half))
		var spot := _try(p, kind, water_level, found, true)
		if spot != Vector3.INF:
			found.append(spot)
	return found


## An ore spot at the foot of steep ground near `p`, or Vector3.INF: level
## enough to stand on there, with the ground rising steeply right beside it
## (FOOT_RISE within FOOT_NEAR, FOOT_HIGH by twice as far) the way it faces
## most; set FOOT_SET into the rise, facing out of it (`facings`).
func _ore_foot(p: Vector2, water_level: float, found: Array) -> Vector3:
	if not zone.contains(p) or zone.is_cleared(p) or p.distance_to(zone.hub) < HUB_CLEAR:
		return Vector3.INF
	# The foot of the edge mountains is fine; not up them.
	if zone.edge_ring(p) > 0.35:
		return Vector3.INF
	for e: Array in zone.enclosures:
		if p.x >= float(e[0]) - 4.0 and p.x <= float(e[2]) + 4.0 and p.y >= float(e[1]) - 4.0 and p.y <= float(e[3]) + 4.0:
			return Vector3.INF
	var y := zone.height_at(p.x, p.y)
	if y < water_level + 0.4:
		return Vector3.INF
	var normal := Vector3(zone.height_at(p.x - 1.0, p.y) - zone.height_at(p.x + 1.0, p.y), 2.0,
		zone.height_at(p.x, p.y - 1.0) - zone.height_at(p.x, p.y + 1.0)).normalized()
	if normal.y < 0.8:
		return Vector3.INF
	for other: Vector3 in found:
		if Vector2(other.x, other.z).distance_to(p) < SPACING:
			return Vector3.INF
	# The steepest way up, all round.
	var best := Vector2.ZERO
	var best_rise := 0.0
	for k in 12:
		var way := Vector2(cos(TAU * k / 12.0), sin(TAU * k / 12.0))
		var near := zone.height_at(p.x + way.x * FOOT_NEAR, p.y + way.y * FOOT_NEAR) - y
		var far := zone.height_at(p.x + way.x * FOOT_NEAR * 2.0, p.y + way.y * FOOT_NEAR * 2.0) - y
		if near >= FOOT_RISE and far >= FOOT_HIGH and near > best_rise:
			best_rise = near
			best = way
	if best == Vector2.ZERO:
		return Vector3.INF
	# Not on a road or in a field.
	var weights := zone.ground_weights()
	if weights.is_valid():
		var layers: Color = weights.call(p.x, p.y, y, normal)
		if layers.r > 0.6 or layers.g > 0.3:
			return Vector3.INF
	# On toward the rise until the ground starts climbing, so the node sits
	# where the slope meets the level ground.
	var foot := p
	for k in int(FOOT_NEAR * 2.0 / 0.25):
		var next := foot + best * 0.25
		if zone.height_at(next.x, next.y) - zone.height_at(foot.x, foot.y) > 0.12:
			break
		foot = next
	var set := foot + best * FOOT_SET
	var spot := Vector3(set.x, zone.height_at(foot.x, foot.y), set.y)
	facings[spot] = atan2(-best.x, -best.y)
	return spot


## A spot for a node of `kind` at `p`, or Vector3.INF. `by_ground` asks the
## ground to show the right thing (rock for ore, grass for herbs).
func _try(p: Vector2, kind: String, water_level: float, found: Array, by_ground: bool) -> Vector3:
	if not zone.contains(p) or zone.is_cleared(p) or p.distance_to(zone.hub) < HUB_CLEAR:
		return Vector3.INF
	# Not up the edge mountains, which can't be climbed.
	if zone.edge_ring(p) > EDGE_LIMIT:
		return Vector3.INF
	for e: Array in zone.enclosures:
		if p.x >= float(e[0]) - 4.0 and p.x <= float(e[2]) + 4.0 and p.y >= float(e[1]) - 4.0 and p.y <= float(e[3]) + 4.0:
			return Vector3.INF
	var y := zone.ground_height(p.x, p.y)
	if y < water_level + 0.4:
		return Vector3.INF
	var step := 1.0
	var normal := Vector3(zone.height_at(p.x - step, p.y) - zone.height_at(p.x + step, p.y), 2.0 * step,
		zone.height_at(p.x, p.y - step) - zone.height_at(p.x, p.y + step)).normalized()
	if normal.y < (HERB_FLAT if kind == "herb" else ORE_FLAT):
		return Vector3.INF
	for other: Vector3 in found:
		if Vector2(other.x, other.z).distance_to(p) < SPACING:
			return Vector3.INF
	var weights := zone.ground_weights()
	if weights.is_valid():
		var rock := zone.shows_rock(p, y, weights)
		if by_ground and (kind == "ore") != rock:
			return Vector3.INF
		if kind == "herb":
			# Not on roads (dirt or cobbles).
			var layers: Color = weights.call(p.x, p.y, y, normal)
			if layers.r > 0.5 or layers.g > 0.3:
				return Vector3.INF
	return Vector3(p.x, y, p.y)


## Puts a node of `kind` (a kind the zone has, by weight) on a free spot.
func _spawn(kind: String) -> GatherNode:
	var pool: Array = spots[kind]
	if pool.is_empty():
		return null
	var taken: Array[Vector3] = []
	for node: GatherNode in get_children():
		taken.append(node.position)
	var player := get_tree().get_first_node_in_group("player") as Node3D if is_inside_tree() else null
	var spot := Vector3.INF
	for attempt in 12:
		var candidate: Vector3 = pool[_rng.randi_range(0, pool.size() - 1)]
		if taken.any(func(t: Vector3) -> bool: return t.distance_to(candidate) < SPACING):
			continue
		# Not right under the player's nose.
		if player and player.global_position.distance_to(candidate) < 30.0 and is_inside_tree():
			continue
		spot = candidate
		break
	if spot == Vector3.INF:
		return null
	return _spawn_at(kind, spot)


## Puts a node of `kind` on `spot`.
func _spawn_at(kind: String, spot: Vector3) -> GatherNode:
	var node := GatherNode.new()
	node.kind = kind
	node.entry = _pick(kind)
	node.field = self
	node.position = spot
	node.rotation.y = float(facings[spot]) if facings.has(spot) else _rng.randf() * TAU
	add_child(node)
	return node


## A node entry of `kind`, by the zone's weights.
func _pick(kind: String) -> int:
	var kinds: Dictionary = zone.gather_kinds().get(kind, {})
	var total := 0.0
	for id: int in kinds:
		total += float(kinds[id])
	var roll := _rng.randf() * total
	for id: int in kinds:
		roll -= float(kinds[id])
		if roll <= 0.0:
			return id
	return kinds.keys()[0]


## A node was emptied: one comes back after its respawn time (classic's,
## halved as creatures' are).
func emptied(node: GatherNode) -> void:
	var respawn := float(node.data().get("respawn", 300)) * Enemy.RESPAWN_SCALE
	waiting.append([Time.get_unix_time_from_system() + respawn, node.kind])


## Brings back every emptied node now (dev tools).
func respawn_all() -> int:
	var count := waiting.size()
	for wait: Array in waiting:
		_spawn(str(wait[1]))
	waiting.clear()
	return count


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0 or waiting.is_empty():
		return
	_check = 1.0
	var now := Time.get_unix_time_from_system()
	for wait: Array in waiting.duplicate():
		if now >= float(wait[0]) and _spawn(str(wait[1])) != null:
			waiting.erase(wait)
