class_name ClutterField
extends Node3D
## Ground clutter made only near the camera: the zone is cut into square
## chunks, and the chunks within reach are filled (a clump every `step`
## yards, jittered, by the zone's `place` function) and drawn as one
## MultiMesh per kind; chunks left far behind are dropped. Placing runs on
## a worker thread, a chunk at a time, so walking never hitches; the zone's
## functions it calls must only read (as for Terrain.build). Each chunk is
## seeded by its position, so it comes back the same.

## Yards a chunk spans, how far chunks are kept, and the spacing of tries.
var chunk := 24.0
var reach := 70.0
var step := 1.0
## Drawn to this many yards from the camera (0: no limit).
var range_end := 0.0
var shadows := false
## Whether the Environment Detail option thins it (Zone.clutter_share).
var thinned := true
## The square it covers.
var area := Rect2()
var rng_seed := 0
## kind -> [mesh, material or null].
var kinds := {}
## f(point: Vector2, rng: RandomNumberGenerator) -> [kind, Transform3D] or [].
var place: Callable
var zone: Zone

var _chunks := {}
var _task := -1
var _task_key := Vector2i.ZERO
var _task_result := {}
var _check_left := 0.0
var _started := false
const CHECK_EVERY := 0.25


func _process(delta: float) -> void:
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task):
			return
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_draw(_task_key, _task_result)
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var at := Vector2(camera.global_position.x, camera.global_position.z)
	# The first time (entering the world), everything in reach at once.
	if not _started:
		_started = true
		fill_near(at)
		return
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = CHECK_EVERY
		_drop_far(at)
	var next: Variant = _nearest_missing(at)
	if next != null:
		_task_key = next
		_task = WorkerThreadPool.add_task(_fill.bind(next))


## Fills every chunk in reach now (entering the world).
func fill_near(at: Vector2) -> void:
	for key in _keys_near(at):
		if not _chunks.has(key):
			_fill(key)
			_draw(key, _task_result)


func _keys_near(at: Vector2) -> Array[Vector2i]:
	var keys: Array[Vector2i] = []
	var low := Vector2i(floori((at.x - reach) / chunk), floori((at.y - reach) / chunk))
	var high := Vector2i(floori((at.x + reach) / chunk), floori((at.y + reach) / chunk))
	for cz in range(low.y, high.y + 1):
		for cx in range(low.x, high.x + 1):
			var square := Rect2(cx * chunk, cz * chunk, chunk, chunk)
			if not square.intersects(area):
				continue
			var nearest := Vector2(clampf(at.x, square.position.x, square.end.x), clampf(at.y, square.position.y, square.end.y))
			if nearest.distance_to(at) <= reach:
				keys.append(Vector2i(cx, cz))
	return keys


func _nearest_missing(at: Vector2) -> Variant:
	var best: Variant = null
	var best_distance := INF
	for key in _keys_near(at):
		if _chunks.has(key):
			continue
		var distance := (Vector2(key) * chunk + Vector2.ONE * chunk / 2.0).distance_to(at)
		if distance < best_distance:
			best_distance = distance
			best = key
	return best


func _drop_far(at: Vector2) -> void:
	for key: Vector2i in _chunks.keys():
		var square := Rect2(key.x * chunk, key.y * chunk, chunk, chunk)
		var nearest := Vector2(clampf(at.x, square.position.x, square.end.x), clampf(at.y, square.position.y, square.end.y))
		if nearest.distance_to(at) > reach + chunk:
			for view: MultiMeshInstance3D in _chunks[key]:
				if thinned:
					zone.forget_clutter(view)
				view.queue_free()
			_chunks.erase(key)


## Works out a chunk's clumps (on a worker thread): kind -> transforms,
## shuffled so a share of them thins evenly.
func _fill(key: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([rng_seed, key.x, key.y])
	var found := {}
	var cells := int(chunk / step)
	var origin := Vector2(key.x, key.y) * chunk
	for row in cells:
		for column in cells:
			var point := origin + Vector2(column + rng.randf(), row + rng.randf()) * step
			if not area.has_point(point):
				continue
			var made: Array = place.call(point, rng)
			if made.is_empty():
				continue
			if not found.has(made[0]):
				found[made[0]] = [] as Array[Transform3D]
			found[made[0]].append(made[1])
	for list: Array in found.values():
		Nature.shuffle(list, rng)
	_task_result = found


func _draw(key: Vector2i, found: Dictionary) -> void:
	var views: Array[MultiMeshInstance3D] = []
	for kind: String in found:
		var list: Array[Transform3D] = found[kind]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = kinds[kind][0]
		multimesh.instance_count = list.size()
		for i in list.size():
			multimesh.set_instance_transform(i, list[i])
		var view := MultiMeshInstance3D.new()
		view.multimesh = multimesh
		if kinds[kind][1]:
			view.material_override = kinds[kind][1]
		if range_end > 0.0:
			view.visibility_range_end = range_end
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(view)
		if thinned:
			zone.add_clutter_view(view)
		views.append(view)
	_chunks[key] = views


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
