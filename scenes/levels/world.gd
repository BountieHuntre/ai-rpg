class_name World
extends Node3D
## Every zone, side by side in one world, with the sky and sun they share.
## Zones are its children (Zone); a point belongs to the zone whose square
## holds it. What's asked of "the world" (the ground's height, named places,
## creature spawns, walled places) is answered from the zone in question, or
## from all of them together.

var zones: Array[Zone] = []


func _init() -> void:
	child_entered_tree.connect(func(node: Node) -> void:
		if node is Zone and not zones.has(node):
			zones.append(node)
	)


## The zone a point is in: the one whose square holds it, else the nearest.
func zone_at(point: Vector3) -> Zone:
	var flat := Vector2(point.x, point.z)
	var best: Zone = null
	var best_distance := INF
	for zone in zones:
		if zone.contains(flat):
			return zone
		var distance := zone.center.distance_to(flat)
		if distance < best_distance:
			best_distance = distance
			best = zone
	return best


func zone_named(zone_name: String) -> Zone:
	for zone in zones:
		if zone.zone_name.to_lower() == zone_name.to_lower():
			return zone
	return null


func height_at(x: float, z: float) -> float:
	return zone_at(Vector3(x, 0, z)).height_at(x, z)


func set_clutter(level: String) -> void:
	for zone in zones:
		zone.set_clutter(level)


## Every zone's named places, spawns and walled places.
func places() -> Array:
	var all := []
	for zone in zones:
		all.append_array(zone.places)
	return all


func spawns() -> Array:
	var all := []
	for zone in zones:
		all.append_array(zone.spawns)
	return all


func enclosures() -> Array:
	var all := []
	for zone in zones:
		all.append_array(zone.enclosures)
	return all


## The points of the pass between two zones, from the first to the second,
## or empty if no pass joins them.
func pass_between(from: Zone, to: Zone) -> Array[Vector2]:
	for line: Array in Zone.PASSES:
		var first: Vector2 = line[0]
		var last: Vector2 = line[line.size() - 1]
		var points: Array[Vector2] = []
		points.assign(line)
		if from.contains(first) and to.contains(last):
			return points
		if from.contains(last) and to.contains(first):
			points.reverse()
			return points
	return []
