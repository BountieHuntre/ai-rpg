class_name Vfx
extends RefCounted
## Small combat effects in the game's blocky look: bursts of tiny cubes that
## fly out and shrink away (opaque, as the outline shader draws over anything
## transparent), coloured by spell school. Hits, heals, buffs, spell
## releases, flying bolts and the glow at a caster's hands all come from here.
## Effects further than RANGE yards from the camera aren't made, so crowds of
## distant bots and creatures fighting cost nothing.

## Yards from the camera past which effects are skipped.
const RANGE := 45.0
## Colours by spell school (physical, holy, fire, nature, frost, shadow, arcane).
const SCHOOL_COLORS := [
	Color(1.0, 0.92, 0.65), Color(1.0, 0.92, 0.45), Color(1.0, 0.42, 0.1), Color(0.45, 0.95, 0.3),
	Color(0.55, 0.85, 1.0), Color(0.6, 0.25, 0.85), Color(0.85, 0.55, 1.0),
]
const HEAL_COLOR := Color(0.55, 1.0, 0.45)
## Yards a second visible bolts fly (creature spells set their own).
const BOLT_SPEED := 30.0

static var _cubes: Dictionary = {}
static var _shrink: Curve


static func school_color(school: int) -> Color:
	return SCHOOL_COLORS[clampi(school, 0, SCHOOL_COLORS.size() - 1)]


## Whether an effect at this point would be seen: near enough to the camera.
static func near(anchor: Node3D, at: Vector3) -> bool:
	if not is_instance_valid(anchor) or not anchor.is_inside_tree():
		return false
	var camera := anchor.get_viewport().get_camera_3d()
	return camera != null and camera.global_position.distance_to(at) <= RANGE


## A burst of cubes from a point: `speed` yards a second outward within
## `spread` degrees of `direction`, falling (or rising) by `gravity`.
static func burst(anchor: Node3D, at: Vector3, color: Color, amount := 8, speed := 3.0, size := 0.1,
		life := 0.35, gravity := -6.0, spread := 180.0, direction := Vector3.UP, radius := 0.0) -> CPUParticles3D:
	if not near(anchor, at):
		return null
	var p := _particles(color, size, life)
	p.one_shot = true
	p.amount = amount
	p.explosiveness = 1.0
	p.direction = direction
	p.spread = spread
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	if radius > 0.0:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = radius
	_place(anchor, p, at)
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


## A unit is hit: sparks for weapons (more on a crit), a burst of the
## school's colour for spells.
static func hit(unit: Node3D, school: int, crit: bool) -> void:
	var at := unit.global_position + Vector3.UP * 1.0
	if school == 0:
		burst(unit, at, school_color(0), 10 if crit else 5, 4.0 if crit else 3.0, 0.08, 0.25, -8.0)
	else:
		burst(unit, at, school_color(school), 14 if crit else 9, 3.0, 0.12, 0.4, -2.0, 180.0, Vector3.UP, 0.15)


## A blow turned aside (parry, block): a few white sparks.
static func deflect(unit: Node3D) -> void:
	burst(unit, unit.global_position + Vector3.UP * 1.1, Color(1, 1, 1), 5, 3.5, 0.07, 0.2, -6.0)


## Healed: green sparkles rising round the unit.
static func heal(unit: Node3D, crit: bool) -> void:
	burst(unit, unit.global_position + Vector3.UP * 0.6, HEAL_COLOR, 14 if crit else 9, 1.8, 0.1, 0.8, 1.5, 25.0,
		Vector3.UP, 0.4)


## A buff put on a unit: a ring of the school's colour rising from its feet.
static func buff(unit: Node3D, school: int) -> void:
	var at := unit.global_position + Vector3.UP * 0.1
	if not near(unit, at):
		return
	var p := _particles(school_color(school).lightened(0.2), 0.09, 0.6)
	p.one_shot = true
	p.amount = 14
	p.explosiveness = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.6
	p.emission_ring_inner_radius = 0.55
	p.emission_ring_height = 0.0
	p.direction = Vector3.UP
	p.spread = 5.0
	p.initial_velocity_min = 1.6
	p.initial_velocity_max = 2.2
	p.gravity = Vector3.ZERO
	_place(unit, p, at)
	p.emitting = true
	p.finished.connect(p.queue_free)


## A spell leaving the caster's hands.
static func release(unit: Node3D, school: int) -> void:
	var visual := unit.get_node_or_null("Visual") as Node3D
	var forward := -(visual if visual else unit).global_basis.z
	burst(unit, unit.global_position + Vector3.UP * 1.2 + forward * 0.4, school_color(school), 8, 2.5, 0.1, 0.3, 0.0)


## A bolt flying from one unit to another, `flight` seconds long (or at
## BOLT_SPEED), bursting on arrival. Purely a picture: damage is dealt by
## the caller.
static func bolt(from_unit: Node3D, to_unit: Node3D, school: int, flight := -1.0) -> void:
	var start := from_unit.global_position + Vector3.UP * 1.2
	if not near(from_unit, start) and not near(to_unit, to_unit.global_position):
		return
	var color := school_color(school)
	var head := MeshInstance3D.new()
	head.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	head.mesh = _cube(0.18)
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head.material_override = _flat(color)
	var trail := _particles(color, 0.08, 0.25)
	trail.amount = 16
	trail.local_coords = false
	trail.initial_velocity_max = 0.3
	trail.gravity = Vector3.ZERO
	head.add_child(trail)
	from_unit.get_parent().add_child(head)
	head.global_position = start
	trail.emitting = true
	var distance := start.distance_to(to_unit.global_position + Vector3.UP)
	var time := flight if flight > 0.0 else distance / BOLT_SPEED
	var tween := head.create_tween()
	tween.tween_method(func(t: float) -> void:
		if is_instance_valid(to_unit):
			head.global_position = start.lerp(to_unit.get_global_transform_interpolated().origin + Vector3.UP * 1.0, t), 0.0, 1.0, maxf(time, 0.05))
	tween.tween_callback(func() -> void:
		if is_instance_valid(to_unit):
			burst(to_unit, head.global_position, color, 10, 3.0, 0.12, 0.35, -2.0)
		head.queue_free())


## A glow of cubes drifting up from a point, for a caster's hands while
## casting: made once and switched on and off (`emitting`).
static func hand_glow(anchor: Node3D, radius := 0.18) -> CPUParticles3D:
	var p := _particles(Color.WHITE, 0.06, 0.45)
	p.amount = 8
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0, 0.5, 0)
	p.local_coords = false
	p.emitting = false
	anchor.add_child(p)
	return p


static func _particles(color: Color, size: float, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	# Not yet: it would start where it's added, before it's moved into place.
	p.emitting = false
	# Placed (and bolts moved) per drawn frame: not physics-interpolated.
	p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	p.mesh = _cube(size)
	p.lifetime = life
	p.color = color
	p.scale_amount_curve = _shrink_curve()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


static func _place(anchor: Node3D, p: Node3D, at: Vector3) -> void:
	# In the world beside the unit, so it stays put as the unit moves.
	var parent := anchor.get_parent()
	if parent is Node3D:
		parent.add_child(p)
	else:
		anchor.add_child(p)
	p.global_position = at


## A cube of this size, unshaded and coloured by the particles' colour.
static func _cube(size: float) -> BoxMesh:
	if not _cubes.has(size):
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE * size
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		cube.material = material
		_cubes[size] = cube
	return _cubes[size]


static func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material


## Full size, then shrinking to nothing.
static func _shrink_curve() -> Curve:
	if not _shrink:
		_shrink = Curve.new()
		_shrink.add_point(Vector2(0.0, 1.0))
		_shrink.add_point(Vector2(0.6, 0.8))
		_shrink.add_point(Vector2(1.0, 0.0))
	return _shrink
