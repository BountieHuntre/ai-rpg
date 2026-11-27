class_name Vfx
extends RefCounted
## Combat effects in the game's pixel look: small sprites painted in code
## (sparks, flames, frost shards, leaves, holy rays, shadow wisps, arcane
## stars, rings, motes; _sprite) on camera-facing particles, with no outline
## (NO_OUTLINE), each spell school moving its own way (SCHOOL_STYLES), with a
## brief light where spells land. Hits, heals, buffs, spell releases, flying
## bolts and the glow at a caster's hands all come from here. Effects further
## than RANGE yards from the camera aren't made, so crowds of distant bots
## and creatures fighting cost nothing.

## Effects have no outline, unlike the world: their materials are blended
## (kept out of the depth and normals the outline pass traces) and drawn at
## this render priority, after the outline material's 0, so no outline is
## drawn over them either. Fire's sprites too.
static var NO_OUTLINE := 1
## How solid each kind of effect sprite is (1 solid, 0 unseen), read as each
## effect is made (the Tuning tab changes them live).
## Sparks: weapon hits and the physical school's bursts.
static var SPARK_OPACITY := 1.0
## Stars: the arcane school, parries and blocks.
static var STAR_OPACITY := 1.0
## Motes: glows at casting hands, heals' rising specks.
static var MOTE_OPACITY := 1.0
## Flashes: the bright cores of impacts and releases.
static var FLASH_OPACITY := 1.0
## Ring sprites (the flat 3D rings are the solid shapes').
static var RING_OPACITY := 1.0
## Crosses: heals.
static var PLUS_OPACITY := 1.0
## Flames: the fire school's bursts and burning units.
static var FLAME_OPACITY := 1.0
## Shards: the frost school.
static var SHARD_OPACITY := 1.0
## Leaves: the nature school.
static var LEAF_OPACITY := 1.0
## Rays: the holy school.
static var RAY_OPACITY := 1.0
## Wisps: the shadow school.
static var WISP_OPACITY := 1.0
## The solid shapes: orbs, gems, ice crystals, shockwave and buff rings, bolts.
static var SOLID_OPACITY := 1.0
## The mist round an enchanted weapon.
static var MIST_OPACITY := 1.0
## Yards from the camera past which effects are skipped.
const RANGE := 45.0
## The Spell Effects option: "Off" (none), "Low" (nearer, fewer particles, no
## lights) or "High".
static var quality := "High"
static var LOW_RANGE := 25.0
static var LOW_AMOUNT := 0.5
## Colours by spell school (physical, holy, fire, nature, frost, shadow, arcane).
const SCHOOL_COLORS := [
	Color(1.0, 0.92, 0.65), Color(1.0, 0.92, 0.45), Color(1.0, 0.42, 0.1), Color(0.45, 0.95, 0.3),
	Color(0.55, 0.85, 1.0), Color(0.6, 0.25, 0.85), Color(0.85, 0.55, 1.0),
]
const HEAL_COLOR := Color(0.55, 1.0, 0.45)
## Yards a second visible bolts fly (creature spells set their own).
static var BOLT_SPEED := 30.0
## How each school's particles look and move: the sprite, speed (yards a
## second), gravity (up is +), life (seconds), how much they slow (damping),
## spin (degrees a second) and whether they swell before fading.
const SCHOOL_STYLES := [
	{ "sprite": "spark", "speed": 4.0, "gravity": -8.0, "life": 0.3, "damping": 0.0, "spin": 0.0 },
	{ "sprite": "ray", "speed": 1.6, "gravity": 3.0, "life": 0.6, "damping": 1.0, "spin": 0.0 },
	{ "sprite": "flame", "speed": 2.0, "gravity": 4.0, "life": 0.5, "damping": 2.0, "spin": 0.0 },
	{ "sprite": "leaf", "speed": 2.4, "gravity": -1.5, "life": 0.8, "damping": 2.0, "spin": 300.0 },
	{ "sprite": "shard", "speed": 3.2, "gravity": -7.0, "life": 0.5, "damping": 0.5, "spin": 0.0 },
	{ "sprite": "wisp", "speed": 1.2, "gravity": 0.8, "life": 0.8, "damping": 1.5, "spin": 160.0, "swell": true },
	{ "sprite": "star", "speed": 2.6, "gravity": 0.0, "life": 0.55, "damping": 3.0, "spin": 90.0 },
]
## At most this many effect lights at once (each a few frames long).
static var MAX_LIGHTS := 8
## Each school's solid body for a bolt: [mesh ("orb", "gem", "crystal"),
## size (yards), colour, degrees a second it spins]. The sprites stream
## round it.
const BOLT_BODIES := [
	["orb", 0.1, Color(0.42, 0.38, 0.34), 0.0],
	["orb", 0.13, Color(1.0, 0.95, 0.6), 0.0],
	["orb", 0.15, Color(1.0, 0.55, 0.12), 120.0],
	["orb", 0.12, Color(0.35, 0.8, 0.25), 90.0],
	["crystal", 0.16, Color(0.7, 0.92, 1.0), 360.0],
	["orb", 0.14, Color(0.28, 0.08, 0.4), 60.0],
	["gem", 0.14, Color(0.9, 0.6, 1.0), 420.0],
]

static var _quads: Dictionary = {}
static var _materials: Dictionary = {}
static var _textures: Dictionary = {}
static var _curves: Dictionary = {}
static var _lights := 0
static var _meshes: Dictionary = {}
## While set, effects are put on the unit they're about (so they move with
## it: a hit, a heal, a buff such as an Oath) rather than left in the world
## where it stood (arrow rain, a trap's blast, a bolt landing). See _on.
static var _solids: Dictionary = {}
static var _follow := false


static func school_color(school: int) -> Color:
	return SCHOOL_COLORS[clampi(school, 0, SCHOOL_COLORS.size() - 1)]


static func _style(school: int) -> Dictionary:
	return SCHOOL_STYLES[clampi(school, 0, SCHOOL_STYLES.size() - 1)]


## Whether an effect at this point would be seen: near enough to the camera.
static func near(anchor: Node3D, at: Vector3) -> bool:
	if not is_instance_valid(anchor) or not anchor.is_inside_tree():
		return false
	if quality == "Off":
		return false
	var camera := anchor.get_viewport().get_camera_3d()
	return camera != null and camera.global_position.distance_to(at) <= (LOW_RANGE if quality == "Low" else RANGE)


## How many particles an effect of `amount` gets at the Spell Effects option.
static func count(amount: int) -> int:
	return maxi(1, roundi(amount * LOW_AMOUNT)) if quality == "Low" else amount


## A burst of sprites from a point: `speed` yards a second outward within
## `spread` degrees of `direction`, falling (or rising) by `gravity`.
static func burst(anchor: Node3D, at: Vector3, color: Color, amount := 8, speed := 3.0, size := 0.1,
		life := 0.35, gravity := -6.0, spread := 180.0, direction := Vector3.UP, radius := 0.0,
		sprite := "spark", damping := 0.0, spin := 0.0, swell := false) -> CPUParticles3D:
	if not near(anchor, at):
		return null
	var p := _particles(sprite, color, size * 1.6, life, swell)
	p.one_shot = true
	p.amount = count(amount)
	p.explosiveness = 1.0
	p.direction = direction
	p.spread = spread
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	p.damping_min = damping * 0.5
	p.damping_max = damping
	if spin != 0.0:
		p.angle_min = -180.0
		p.angle_max = 180.0
		p.angular_velocity_min = -spin
		p.angular_velocity_max = spin
	if radius > 0.0:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = radius
	_place(anchor, p, at)
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


## A burst in a spell school's own style (SCHOOL_STYLES).
static func school_burst(anchor: Node3D, at: Vector3, school: int, amount := 10, radius := 0.15) -> void:
	var s := _style(school)
	burst(anchor, at, school_color(school), amount, s.speed, 0.1, s.life, s.gravity, 180.0, Vector3.UP, radius,
		s.sprite, s.damping, s.spin, s.get("swell", false))


## Where something lands: a ring flashing out and a bright core, a burst in
## the school's style, and a moment's light.
static func impact(anchor: Node3D, at: Vector3, school: int, big := false) -> void:
	if not near(anchor, at):
		return
	var color := school_color(school)
	var scale := 1.4 if big else 1.0
	shockwave(anchor, at, color, 0.55 * scale, 0.22)
	_flash(anchor, at, "flash", color.lerp(Color.WHITE, 0.5), 0.45 * scale, 0.14, Vector2(1.0, 0.3))
	school_burst(anchor, at, school, 16 if big else 10, 0.12)
	light(anchor, at, color, 1.6 * scale, 0.25)


## A unit is hit: sparks for weapons (more on a crit), an impact in the
## school's style for spells.
static func hit(unit: Node3D, school: int, crit: bool) -> void:
	_on(func() -> void: _hit(unit, school, crit))


static func _hit(unit: Node3D, school: int, crit: bool) -> void:
	var at := unit.global_position + Vector3.UP * 1.0
	if school == 0:
		burst(unit, at, school_color(0), 10 if crit else 6, 4.5 if crit else 3.5, 0.09, 0.25, -8.0)
		if crit:
			_flash(unit, at, "ring", Color(1, 0.95, 0.8), 0.8, 0.18, Vector2(0.25, 1.0))
	else:
		impact(unit, at, school, crit)
		if school == FIRE:
			burn(unit, crit)
		elif school == FROST:
			freeze(unit)


const FIRE := 2
const FROST := 4


## Fire burning on a moment after the hit: flames licking up the unit, with
## a flickering light, following it as it moves.
static func burn(unit: Node3D, crit := false) -> void:
	var at := unit.global_position + Vector3.UP * 0.5
	if not near(unit, at):
		return
	var color := school_color(FIRE)
	var p := _particles("flame", color, 0.2, 0.45, false)
	p.amount = count(16 if crit else 10)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.22, 0.45, 0.22)
	p.direction = Vector3.UP
	p.spread = 15.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.3
	p.gravity = Vector3(0, 1.5, 0)
	p.color = Color.WHITE
	p.color_ramp = _ramp(Color(1.0, 0.9, 0.45), color.darkened(0.15))
	# On the unit, so the flames go with it (drawn where it's drawn).
	p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	unit.add_child(p)
	p.position = Vector3.UP * 0.9
	p.emitting = true
	var l := _light(color, 1.3, 3.0)
	if l:
		l.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
		unit.add_child(l)
		l.position = Vector3.UP * 1.0
	var time := 0.9 if crit else 0.65
	var tween := p.create_tween()
	if l:
		# Flickering, then dying away.
		for i in 4:
			tween.tween_property(l, "light_energy", randf_range(0.6, 1.5), time / 5.0)
		tween.tween_property(l, "light_energy", 0.0, time / 5.0)
	else:
		tween.tween_interval(time)
	tween.tween_callback(func() -> void:
		p.emitting = false
		if l:
			_lights -= 1
			l.queue_free())
	tween.tween_interval(p.lifetime)
	tween.tween_callback(p.queue_free)


## Frost taking hold: ice crystals jutting from the unit for a moment, then
## shattering into shards.
static func freeze(unit: Node3D) -> void:
	var at := unit.global_position
	if not near(unit, at):
		return
	var color := school_color(FROST)
	var holder := Node3D.new()
	unit.add_child(holder)
	for i in 5:
		var crystal := _solid_node("crystal", 0.0, color.lerp(Color.WHITE, 0.25 + 0.15 * (i % 2)))
		crystal.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
		holder.add_child(crystal)
		var a := TAU * i / 5.0 + randf() * 0.5
		crystal.position = Vector3(cos(a) * 0.28, 0.25 + randf() * 0.9, sin(a) * 0.28)
		# Jutting outward and up.
		var out := Vector3(cos(a), 0.6, sin(a)).normalized()
		crystal.basis = Basis(Quaternion(Vector3.UP, out))
		var size := randf_range(0.09, 0.14)
		var grow := crystal.create_tween()
		grow.tween_property(crystal, "scale", Vector3.ONE * size, 0.08)
	var tween := holder.create_tween()
	tween.tween_interval(0.55)
	tween.tween_callback(func() -> void:
		if is_instance_valid(unit):
			burst(unit, unit.global_position + Vector3.UP * 0.8, color.lightened(0.3), 14, 3.2, 0.1, 0.45, -8.0, 180.0,
				Vector3.UP, 0.35, "shard")
		holder.queue_free())


## A colour ramp from one colour to another over a particle's life.
static func _ramp(from: Color, to: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, from)
	g.set_color(1, to)
	return g


## A blow turned aside (parry, block): white sparks and a flash.
static func deflect(unit: Node3D) -> void:
	_on(func() -> void: _deflect(unit))


static func _deflect(unit: Node3D) -> void:
	var at := unit.global_position + Vector3.UP * 1.1
	burst(unit, at, Color(1, 1, 1), 6, 4.0, 0.08, 0.2, -6.0)
	_flash(unit, at, "star", Color(1, 1, 0.9), 0.5, 0.12, Vector2(1.0, 0.4))


## Healed: green crosses and motes rising in a spiral round the unit, and a
## soft light.
static func heal(unit: Node3D, crit: bool) -> void:
	_on(func() -> void: _heal(unit, crit))


static func _heal(unit: Node3D, crit: bool) -> void:
	var at := unit.global_position + Vector3.UP * 0.3
	if not near(unit, at):
		return
	for sprite in ["plus", "mote"]:
		var p := _particles(sprite, HEAL_COLOR if sprite == "plus" else HEAL_COLOR.lightened(0.4), 0.16 if sprite == "plus" else 0.1,
			1.1, false)
		p.one_shot = true
		p.amount = count((10 if crit else 7) if sprite == "plus" else 8)
		p.explosiveness = 0.6
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_axis = Vector3.UP
		p.emission_ring_radius = 0.45
		p.emission_ring_inner_radius = 0.3
		p.emission_ring_height = 0.2
		p.direction = Vector3.UP
		p.spread = 8.0
		p.initial_velocity_min = 1.0
		p.initial_velocity_max = 1.6
		p.gravity = Vector3.ZERO
		# Round the body as they rise.
		p.tangential_accel_min = 1.5
		p.tangential_accel_max = 2.5
		_place(unit, p, at)
		p.emitting = true
		p.finished.connect(p.queue_free)
	light(unit, at + Vector3.UP * 0.6, HEAL_COLOR, 1.2, 0.5)


## A buff put on a unit: a ring of the school's colour rising from its feet to
## its head, with motes rising round it.
static func buff(unit: Node3D, school: int) -> void:
	_on(func() -> void: _buff(unit, school))


static func _buff(unit: Node3D, school: int) -> void:
	var at := unit.global_position + Vector3.UP * 0.05
	if not near(unit, at):
		return
	var color := school_color(school).lightened(0.2)
	var ring := _solid_node("ring", 0.62, color)
	_place(unit, ring, at)
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, "position", ring.position + Vector3.UP * 1.9, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(ring, "scale", Vector3.ONE * 0.35, 0.6).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(ring.queue_free)
	var p := _particles("mote", color, 0.1, 0.7, false)
	p.one_shot = true
	p.amount = count(14)
	p.explosiveness = 0.8
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.6
	p.emission_ring_inner_radius = 0.5
	p.emission_ring_height = 0.0
	p.direction = Vector3.UP
	p.spread = 5.0
	p.initial_velocity_min = 1.8
	p.initial_velocity_max = 2.6
	p.gravity = Vector3.ZERO
	_place(unit, p, at)
	p.emitting = true
	p.finished.connect(p.queue_free)


## A spell leaving the caster's hands: a flash before them, a burst in the
## school's style and a moment's light.
static func release(unit: Node3D, school: int) -> void:
	_on(func() -> void: _release(unit, school))


static func _release(unit: Node3D, school: int) -> void:
	var visual := unit.get_node_or_null("Visual") as Node3D
	var forward := -(visual if visual else unit).global_basis.z
	var at := unit.global_position + Vector3.UP * 1.2 + forward * 0.45
	if not near(unit, at):
		return
	var color := school_color(school)
	_flash(unit, at, "flash", color.lerp(Color.WHITE, 0.4), 0.4, 0.12, Vector2(0.6, 1.0))
	var orb := _solid_node("orb", 0.09, color.lerp(Color.WHITE, 0.3))
	_place(unit, orb, at)
	orb.scale = Vector3.ONE * 0.04
	var grow := orb.create_tween()
	grow.tween_property(orb, "scale", Vector3.ONE * 0.12, 0.08)
	grow.tween_property(orb, "scale", Vector3.ZERO, 0.14)
	grow.tween_callback(orb.queue_free)
	var s := _style(school)
	burst(unit, at, color, 10, s.speed * 1.2, 0.1, s.life, s.gravity, 35.0, forward, 0.05, s.sprite, s.damping, s.spin,
		s.get("swell", false))
	light(unit, at, color, 1.2, 0.2)


## A bolt flying from one unit to another, `flight` seconds long (or at
## BOLT_SPEED), landing with an impact. Purely a picture: damage is dealt by
## the caller.
static func bolt(from_unit: Node3D, to_unit: Node3D, school: int, flight := -1.0) -> void:
	var start := from_unit.global_position + Vector3.UP * 1.2
	if not near(from_unit, start) and not near(to_unit, to_unit.global_position):
		return
	var color := school_color(school)
	var s := _style(school)
	# The school's solid body (BOLT_BODIES), spinning, with its sprites
	# streaming round it.
	var shape: Array = BOLT_BODIES[clampi(school, 0, BOLT_BODIES.size() - 1)]
	var head := Node3D.new()
	head.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var body := _solid_node(shape[0], shape[1], shape[2])
	head.add_child(body)
	if float(shape[3]) != 0.0:
		var spin := body.create_tween().set_loops()
		spin.tween_property(body, "rotation:y", TAU, 360.0 / float(shape[3])).from(0.0)
	var aura := _particles(s.sprite, color.lightened(0.15), 0.14, 0.25, false)
	aura.amount = count(10)
	aura.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = float(shape[1]) * 1.1
	aura.initial_velocity_min = 0.3
	aura.initial_velocity_max = 0.8
	aura.gravity = Vector3(0, s.gravity * 0.3, 0)
	if s.spin != 0.0:
		aura.angle_min = -180.0
		aura.angle_max = 180.0
	head.add_child(aura)
	# A trail of the school's sprites, left behind in the world.
	var trail := _particles(s.sprite, color, 0.16, 0.45, s.get("swell", false))
	trail.amount = count(32)
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = float(shape[1]) * 0.8
	trail.local_coords = false
	trail.initial_velocity_max = 0.4
	trail.gravity = Vector3(0, s.gravity * 0.25, 0)
	if s.spin != 0.0:
		trail.angle_min = -180.0
		trail.angle_max = 180.0
		trail.angular_velocity_min = -s.spin
		trail.angular_velocity_max = s.spin
	head.add_child(trail)
	var glow: OmniLight3D = _light(color, 1.0, 2.5)
	if glow:
		head.add_child(glow)
	from_unit.get_parent().add_child(head)
	head.global_position = start
	trail.emitting = true
	aura.emitting = true
	var distance := start.distance_to(to_unit.global_position + Vector3.UP)
	var time := flight if flight > 0.0 else distance / BOLT_SPEED
	var tween := head.create_tween()
	tween.tween_method(func(t: float) -> void:
		if is_instance_valid(to_unit):
			head.global_position = start.lerp(to_unit.get_global_transform_interpolated().origin + Vector3.UP * 1.0, t), 0.0, 1.0, maxf(time, 0.05))
	tween.tween_callback(func() -> void:
		# Bursting where it lands; the hit (if it hits) shows the impact.
		if is_instance_valid(to_unit):
			_flash(to_unit, head.global_position, "flash", color.lerp(Color.WHITE, 0.4), 0.4, 0.12, Vector2(1.0, 0.3))
		if glow:
			_lights -= 1
		head.queue_free())


## A glow of motes drifting up from a point, for a caster's hands while
## casting: made once and switched on and off (`emitting`), coloured by the
## caster's spell (`color`).
static func hand_glow(anchor: Node3D, radius := 0.18) -> CPUParticles3D:
	var p := _particles("mote", Color.WHITE, 0.09, 0.5, false)
	p.amount = count(10)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0, 0.6, 0)
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.local_coords = false
	p.emitting = false
	anchor.add_child(p)
	return p


## An enchanted weapon's mist (Enchanting.weapon_look): soft puffs of its
## colour, see-through and adding light, swelling and fading as they drift
## off the blade: from within `blade` (a box in the weapon bone's space, the
## blade's own faces: an axe's or mace's head, a sword's blade past its
## hilt) on `anchor`: rising, sinking or hanging round it by `motion`.
## Unlike the other effects it's blended, not cut out, so it reads as a glow
## rather than as shapes.
static func weapon_mist(anchor: Node3D, color: Color, motion: String, blade: AABB) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	p.mesh = _mist_quad()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount = count(34)
	p.lifetime = 1.2
	# The blade glow's deep tone (its colour in linear light, as the glow
	# has it), a little brighter so it shines without washing out to white.
	var deep := color.srgb_to_linear()
	p.color = Color(deep.r * MIST_SHINE, deep.g * MIST_SHINE, deep.b * MIST_SHINE)
	p.color_ramp = _mist_fade()
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.1
	p.scale_amount_curve = _grow_curve(Vector2(0.6, 1.2))
	# Close about the blade's line, barely drifting off it.
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	# Kept in a little from the blade's edges, so it hugs it.
	p.emission_box_extents = (blade.size / 2.0 * 0.8).max(Vector3.ONE * 0.01)
	p.position = blade.get_center()
	p.direction = Vector3.DOWN if motion == "down" else Vector3.UP
	p.spread = 180.0 if motion == "swirl" else 30.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.05 if motion == "swirl" else 0.08
	p.gravity = Vector3(0, -0.06, 0) if motion == "down" else (Vector3.ZERO if motion == "swirl" else Vector3(0, 0.06, 0))
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.local_coords = false
	anchor.add_child(p)
	return p


## How much brighter than its colour an enchanted weapon's mist is drawn.
static var MIST_SHINE := 1.3
## An enchanted weapon's own light: its reach in yards and strength, shown
## only within WEAPON_LIGHT_NEAR yards of the camera, at High effects.
static var WEAPON_LIGHT_RANGE := 2.2
static var WEAPON_LIGHT_ENERGY := 0.9
static var WEAPON_LIGHT_NEAR := 25.0


## A soft light in an enchanted weapon's colour at the middle of its blade
## (`at`, in the weapon bone's space), so its mist shines on the hand and
## what's near. Not counted in MAX_LIGHTS (it lasts as long as the enchant);
## the model shows it only when near.
static func weapon_light(anchor: Node3D, color: Color, at: Vector3) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = WEAPON_LIGHT_ENERGY
	l.omni_range = WEAPON_LIGHT_RANGE
	l.shadow_enabled = false
	l.light_volumetric_fog_energy = 0.0
	l.position = at
	l.visible = false
	anchor.add_child(l)
	return l


## A puff of mist: a soft round patch, clear at its rim, blended over what's
## behind (unlit, facing the camera).
static func _mist_quad() -> QuadMesh:
	if not _quads.has("mist"):
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * 0.24
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# Mixed rather than added, so overlapping puffs keep their colour
		# instead of piling up to white.
		material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		material.vertex_color_use_as_albedo = true
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.no_depth_test = false
		material.render_priority = NO_OUTLINE
		var n := SPRITE_SIZE
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var c := (n - 1) / 2.0
		for y in n:
			for x in n:
				var r := Vector2((x - c) / c, (y - c) / c).length()
				var a := clampf(1.0 - r, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a))
		material.albedo_texture = ImageTexture.create_from_image(img)
		quad.material = material
		_quads["mist"] = quad
	var mist: QuadMesh = _quads["mist"]
	(mist.material as StandardMaterial3D).albedo_color.a = MIST_OPACITY
	return mist


## Mist fades in, holds faintly and fades out.
static func _mist_fade() -> Gradient:
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	fade.add_point(0.2, Color(1, 1, 1, 0.65))
	fade.add_point(0.7, Color(1, 1, 1, 0.45))
	return fade


## A ring flying out from a point and thinning away: a shockwave, facing the
## camera, `size` yards across at its widest.
static func shockwave(anchor: Node3D, at: Vector3, color: Color, size: float, time: float) -> void:
	if not near(anchor, at):
		return
	var ring := _solid_node("ring", 0.5, color)
	_place(anchor, ring, at)
	var camera := anchor.get_viewport().get_camera_3d()
	if camera:
		# A torus lies flat (in XZ): turned so its axis points at the camera.
		var to_camera := (camera.global_position - at).normalized()
		var side := to_camera.cross(Vector3.UP)
		side = side.normalized() if side.length() > 0.01 else Vector3.RIGHT
		ring.global_basis = Basis(side, to_camera, side.cross(to_camera))
	ring.scale = Vector3.ONE * size * 0.3
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3(size, size * 0.3, size), time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(ring.queue_free)


## A solid shape of a colour, unshaded: "orb" (a faceted ball), "gem" (an
## eight-sided gem), "crystal" (a long ice crystal) or "ring" (a thin ring
## lying flat), its unit shape scaled by `size`.
static func _solid_node(shape: String, size: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	node.mesh = _solid_mesh(shape)
	node.scale = Vector3.ONE * size
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var key := color.to_html()
	if not _solids.has(key):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		# No outline: kept out of the depth and normals the outline pass
		# traces, drawn after it, writing its own depth so its faces still
		# hide each other.
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		material.render_priority = NO_OUTLINE
		_solids[key] = material
	(_solids[key] as StandardMaterial3D).albedo_color.a = SOLID_OPACITY
	node.material_override = _solids[key]
	return node


## The shapes at unit size.
static func _solid_mesh(shape: String) -> Mesh:
	if _meshes.has(shape):
		return _meshes[shape]
	var mesh: Mesh
	match shape:
		"orb":
			var sphere := SphereMesh.new()
			sphere.radius = 1.0
			sphere.height = 2.0
			sphere.radial_segments = 8
			sphere.rings = 5
			mesh = sphere
		"ring":
			var torus := TorusMesh.new()
			torus.inner_radius = 0.82
			torus.outer_radius = 1.0
			torus.rings = 16
			torus.ring_segments = 4
			mesh = torus
		_:
			# Two pyramids base to base: a gem, or stretched along Y a crystal.
			var tall := 1.8 if shape == "crystal" else 1.0
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var top := Vector3(0, tall, 0)
			var bottom := Vector3(0, -tall, 0)
			var sides := 4 if shape == "crystal" else 6
			for i in sides:
				var a := Vector3(cos(TAU * i / sides), 0, sin(TAU * i / sides)) * 0.7
				var b := Vector3(cos(TAU * (i + 1) / sides), 0, sin(TAU * (i + 1) / sides)) * 0.7
				for tri in [[top, b, a], [bottom, a, b]]:
					for v: Vector3 in tri:
						st.add_vertex(v)
			st.generate_normals()
			mesh = st.commit()
	_meshes[shape] = mesh
	return mesh


## A moment's light of a colour: `energy` fading to nothing over `time`. Not
## at the Low setting, and at most MAX_LIGHTS at once.
static func light(anchor: Node3D, at: Vector3, color: Color, energy: float, time: float) -> void:
	var l := _light(color, energy, 3.5)
	if not l:
		return
	_place(anchor, l, at)
	var tween := l.create_tween()
	tween.tween_property(l, "light_energy", 0.0, time).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_lights -= 1
		l.queue_free())


static func _light(color: Color, energy: float, reach: float) -> OmniLight3D:
	if quality != "High" or _lights >= MAX_LIGHTS:
		return null
	_lights += 1
	var l := OmniLight3D.new()
	l.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	l.shadow_enabled = false
	l.light_volumetric_fog_energy = 0.0
	return l


## One sprite flashing at a point: its size going from `grow.x` to `grow.y`
## of `size` over `life` seconds.
static func _flash(anchor: Node3D, at: Vector3, sprite: String, color: Color, size: float, life: float, grow: Vector2) -> void:
	var p := _particles(sprite, color, size, life, false)
	p.one_shot = true
	p.amount = 1
	p.explosiveness = 1.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_max = 0.0
	p.scale_amount_curve = _grow_curve(grow)
	_place(anchor, p, at)
	p.emitting = true
	p.finished.connect(p.queue_free)


static func _particles(sprite: String, color: Color, size: float, life: float, swell: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	# Not yet: it would start where it's added, before it's moved into place.
	p.emitting = false
	# Placed (and bolts moved) per drawn frame: not physics-interpolated.
	p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	p.mesh = _sprite_quad(sprite, size)
	p.lifetime = life
	p.color = color
	p.scale_amount_curve = _grow_curve(Vector2(0.4, 0.0)) if swell else _shrink_curve()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Runs an effect with its parts put on the unit, so they move with it.
static func _on(effect: Callable) -> void:
	_follow = true
	effect.call()
	_follow = false


static func _place(anchor: Node3D, p: Node3D, at: Vector3) -> void:
	if _follow and anchor.is_inside_tree():
		# On the unit: carried along as it moves, drawn where it's drawn (the
		# particles it throws out drift free, left behind in the world).
		p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
		anchor.add_child(p)
		p.global_position = at
		return
	# In the world beside the unit, so it stays put as the unit moves.
	var parent := anchor.get_parent()
	if parent is Node3D:
		parent.add_child(p)
	else:
		anchor.add_child(p)
	p.global_position = at


## A camera-facing quad of a sprite, coloured by its particles' colour.
static func _sprite_quad(sprite: String, size: float) -> QuadMesh:
	var key := "%s:%s" % [sprite, size]
	if not _quads.has(key):
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * size
		var material := _sprite_material(sprite)
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		material.vertex_color_use_as_albedo = true
		quad.material = material
		_quads[key] = quad
	var quad: QuadMesh = _quads[key]
	(quad.material as StandardMaterial3D).albedo_color.a = opacity(sprite)
	return quad


## How solid a kind of sprite is (its *_OPACITY).
static func opacity(sprite: String) -> float:
	match sprite:
		"spark": return SPARK_OPACITY
		"star": return STAR_OPACITY
		"mote": return MOTE_OPACITY
		"flash": return FLASH_OPACITY
		"ring": return RING_OPACITY
		"plus": return PLUS_OPACITY
		"flame": return FLAME_OPACITY
		"shard": return SHARD_OPACITY
		"leaf": return LEAF_OPACITY
		"ray": return RAY_OPACITY
		"wisp": return WISP_OPACITY
	return 1.0


static func _sprite_material(sprite: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _sprite(sprite)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Blended rather than cut out (the sprites are solid or clear, so they
	# look the same), and drawn after the outline pass: no outline.
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.render_priority = NO_OUTLINE
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## Full size, then shrinking to nothing.
static func _shrink_curve() -> Curve:
	return _grow_curve(Vector2(1.0, 0.0), true)


## Size from `from` to `to` over a particle's life (with `hold`, held near
## full size most of the way first).
static func _grow_curve(span: Vector2, hold := false) -> Curve:
	var key := "%s:%s" % [span, hold]
	if not _curves.has(key):
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, span.x))
		if hold:
			curve.add_point(Vector2(0.6, 0.8))
		elif span.y < span.x:
			curve.add_point(Vector2(0.3, maxf(span.x, 1.0)))
		curve.add_point(Vector2(1.0, span.y))
		_curves[key] = curve
	return _curves[key]


# ---------------------------------------------------------------- sprites

static var SPRITE_SIZE := 16


## A sprite painted in code: a flat white shape on clear, so a particle's
## colour is its colour (_shade's lighter middles are only its outline now).
static func _sprite(sprite: String) -> ImageTexture:
	if _textures.has(sprite):
		return _textures[sprite]
	var n := SPRITE_SIZE
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (n - 1) / 2.0
	for y in n:
		for x in n:
			var dx := (x - c) / c
			var dy := (y - c) / c
			# One flat tone: the shape only, its colour all the particle's
			# (lighter middles and greyer rims looked muddy once tinted).
			if _shade(sprite, dx, dy) > 0.0:
				img.set_pixel(x, y, Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	_textures[sprite] = tex
	return tex


## How light a sprite is at a point (-1 to 1 across, y down), 0 where it's
## clear.
static func _shade(sprite: String, x: float, y: float) -> float:
	var r := sqrt(x * x + y * y)
	match sprite:
		"spark":
			# A four-pointed star.
			var arm := minf(absf(x), absf(y))
			if arm < 0.16 and r < 0.95:
				return 1.0 if r < 0.35 else 0.75
			return 0.0
		"star":
			# A thin four-pointed star with short diagonals.
			if (absf(x) < 0.1 and absf(y) < 1.0) or (absf(y) < 0.1 and absf(x) < 1.0):
				return 1.0 if r < 0.3 else 0.8
			if absf(absf(x) - absf(y)) < 0.12 and r < 0.45:
				return 0.85
			return 0.0
		"mote":
			return (1.0 if r < 0.3 else 0.7) if r < 0.6 else 0.0
		"flash":
			return (1.0 if r < 0.55 else 0.8) if r < 0.95 else 0.0
		"ring":
			return 1.0 if r > 0.7 and r < 0.97 else 0.0
		"plus":
			if (absf(x) < 0.28 and absf(y) < 0.9) or (absf(y) < 0.28 and absf(x) < 0.9):
				return 1.0 if absf(x) < 0.14 or absf(y) < 0.14 else 0.75
			return 0.0
		"flame":
			# A teardrop, pointed at the top, its middle bright.
			var t := (y + 1.0) / 2.0
			var w := 0.7 * sqrt(clampf(t, 0.0, 1.0)) * (1.0 if t < 0.75 else (1.0 - t) / 0.25 + 0.0)
			if t > 0.75:
				w = 0.7 * sqrt(0.75) * (1.0 - (t - 0.75) / 0.25)
			if absf(x) < w and t > 0.05:
				return 1.0 if absf(x) < w * 0.45 and t > 0.4 else 0.7
			return 0.0
		"shard":
			# A tall diamond.
			var d := absf(x) / 0.45 + absf(y)
			return (1.0 if d < 0.45 else 0.75) if d < 1.0 else 0.0
		"leaf":
			# A leaf on the diagonal with a vein.
			var u := (x + y) * 0.7071
			var v := (x - y) * 0.7071
			if absf(v) < 0.45 * (1.0 - u * u) and absf(u) < 0.95:
				return 1.0 if absf(v) < 0.08 else 0.7
			return 0.0
		"ray":
			# A thin upright streak, tapering at both ends.
			var w := 0.18 * (1.0 - absf(y))
			return (1.0 if absf(x) < w * 0.5 else 0.75) if absf(x) < w else 0.0
		"wisp":
			# A comma: a round head with a tail curling below.
			if Vector2(x + 0.15, y + 0.2).length() < 0.5:
				return 1.0 if Vector2(x + 0.25, y + 0.3).length() < 0.2 else 0.75
			var a := atan2(y - 0.1, x - 0.1)
			var rr := Vector2(x - 0.1, y - 0.1).length()
			if rr > 0.45 and rr < 0.75 and a > 0.0 and a < 2.4:
				return 0.7
			return 0.0
	return 0.0


# Area spells on the ground: rain falling (arrows, hail), a pillar of fire and
# the flames it leaves.

## Rain: projectiles fall from this high over the area, this fast (yards a
## second), and splash where they land this often (seconds).
static var RAIN_HEIGHT := 12.0
static var RAIN_SPEED := 22.0
static var RAIN_SPLASH_EVERY := 0.12
## How many projectiles are in the air at once, per 10 yards of radius.
static var RAIN_DENSITY := 80
## An arrow's and a hailstone's length, in yards.
static var ARROW_LENGTH := 1.2
static var HAIL_SIZE := 0.6
## Hailstorm's stones: each its own, falling this fast (yards a second) with a
## frosty trail, so many a second per 10 yards of radius, bursting where it
## hits the ground.
static var HAIL_SPEED := 10.0
static var HAIL_PER_SECOND := 9.0
## The ground under an area: frost under Hailstorm, a scorched glow under
## Pillar of Flame (a decal), fading in and out over this long.
static var PATCH_FADE := 0.6
static var PATCH_TEXTURE_SIZE := 128
## Pillar of Flame: how tall the column rises and how long it roars.
static var PILLAR_HEIGHT := 9.0
static var PILLAR_TIME := 0.7
static var _rain_materials: Dictionary = {}


## Projectiles raining down on a circle of the ground (`kind` "arrows" or
## "hail") until stop_rain: each turned along its fall, a burst where they
## land. Returns the effect's node (null when it wouldn't be seen).
static func rain(anchor: Node3D, center: Vector3, radius: float, kind: String) -> Node3D:
	if not near(anchor, center):
		return null
	var root := Node3D.new()
	root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_place(anchor, root, center)
	if kind == "hail":
		_hailstorm(root, center, radius)
		return root
	var fall := CPUParticles3D.new()
	fall.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	fall.emitting = false
	fall.mesh = _rain_mesh(kind)
	fall.material_override = _rain_material()
	fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fall.local_coords = false
	fall.amount = count(maxi(roundi(RAIN_DENSITY * radius / 10.0), 6))
	fall.lifetime = RAIN_HEIGHT / RAIN_SPEED
	fall.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	fall.emission_ring_axis = Vector3.UP
	fall.emission_ring_radius = radius
	fall.emission_ring_inner_radius = 0.0
	fall.emission_ring_height = 0.5
	fall.direction = Vector3(0.12, -1.0, 0.05) if kind == "arrows" else Vector3.DOWN
	fall.spread = 4.0
	fall.initial_velocity_min = RAIN_SPEED * 0.9
	fall.initial_velocity_max = RAIN_SPEED * 1.1
	fall.gravity = Vector3.ZERO
	fall.particle_flag_align_y = true
	root.add_child(fall)
	fall.position = Vector3.UP * RAIN_HEIGHT
	fall.emitting = true
	# Splashes where they land, at random points of the circle.
	var splash := func() -> void:
		if not is_instance_valid(root) or root.get_meta("stopping", false):
			return
		var a := randf() * TAU
		var spot := center + Vector3(cos(a), 0.0, sin(a)) * radius * sqrt(randf()) + Vector3.UP * 0.15
		burst(root, spot, Color(0.62, 0.55, 0.42), 4, 1.6, 0.07, 0.3, -9.0, 50.0, Vector3.UP, 0.05, "spark")
	var timer := Timer.new()
	timer.wait_time = RAIN_SPLASH_EVERY
	timer.autostart = true
	timer.timeout.connect(splash)
	root.add_child(timer)
	return root


## Ends a rain (or burning ground): nothing more falls or flares, and what's
## in the air lands first.
static func stop_rain(effect: Node3D) -> void:
	if effect == null or not is_instance_valid(effect) or effect.get_meta("stopping", false):
		return
	effect.set_meta("stopping", true)
	for child in effect.get_children():
		if child is CPUParticles3D:
			(child as CPUParticles3D).emitting = false
		elif child is Timer:
			(child as Timer).stop()
		elif child is Decal:
			child.create_tween().tween_property(child, "modulate:a", 0.0, PATCH_FADE)
	var tween := effect.create_tween()
	tween.tween_interval(maxf(1.2, PATCH_FADE + 0.1))
	tween.tween_callback(effect.queue_free)


## A projectile for rain, lengthwise along +Y (the way it falls once turned
## along its velocity), its parts in their own colours: an arrow (steel head,
## wooden shaft, white fletching) or a hailstone (an ice crystal).
static func _rain_mesh(kind: String) -> Mesh:
	var key := "rain_" + kind
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if kind == "arrows":
		var half := ARROW_LENGTH / 2.0
		_rain_box(st, Vector3(0, -half * 0.2, 0), Vector3(0.05, half * 1.6, 0.05), Color(0.5, 0.36, 0.2))
		_rain_spike(st, Vector3(0, half * 0.6, 0), half * 0.4, 0.08, Color(0.78, 0.8, 0.85))
		_rain_box(st, Vector3(0, -half * 0.85, 0), Vector3(0.16, half * 0.35, 0.012), Color(0.92, 0.9, 0.85))
		_rain_box(st, Vector3(0, -half * 0.85, 0), Vector3(0.012, half * 0.35, 0.16), Color(0.92, 0.9, 0.85))
	else:
		_rain_spike(st, Vector3.ZERO, HAIL_SIZE, HAIL_SIZE * 0.45, Color(0.72, 0.9, 1.0))
		_rain_spike(st, Vector3.ZERO, -HAIL_SIZE, HAIL_SIZE * 0.45, Color(0.42, 0.68, 0.95))
	st.generate_normals()
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh


## A box centred at `at`, `size` its full extents, in one colour.
static func _rain_box(st: SurfaceTool, at: Vector3, size: Vector3, color: Color) -> void:
	var h := size / 2.0
	var corners := []
	for i in 8:
		corners.append(at + Vector3(h.x * (1 if i & 1 else -1), h.y * (1 if i & 2 else -1), h.z * (1 if i & 4 else -1)))
	for quad in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
		for tri in [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]]:
			for index: int in tri:
				st.set_color(color)
				st.add_vertex(corners[index])


## A four-sided spike from a base at `at` to a point `length` along Y.
static func _rain_spike(st: SurfaceTool, at: Vector3, length: float, width: float, color: Color) -> void:
	var tip := at + Vector3(0, length, 0)
	for i in 4:
		var a := at + Vector3(cos(TAU * i / 4.0), 0, sin(TAU * i / 4.0)) * width
		var b := at + Vector3(cos(TAU * (i + 1) / 4.0), 0, sin(TAU * (i + 1) / 4.0)) * width
		for v: Vector3 in ([tip, b, a] if length > 0.0 else [tip, a, b]):
			st.set_color(color)
			st.add_vertex(v)
		for v: Vector3 in ([at, a, b] if length > 0.0 else [at, b, a]):
			st.set_color(color.darkened(0.2))
			st.add_vertex(v)


## Unshaded and coloured by the mesh's own colours, with no outline (as the
## other solid shapes).
static func _rain_material() -> StandardMaterial3D:
	if _rain_materials.has("solid"):
		return _rain_materials.solid
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	material.render_priority = NO_OUTLINE
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_rain_materials.solid = material
	return material


## Pillar of Flame striking: a column of fire roaring up from the ground, a
## flash where it lands and a burst of light.
static func pillar(anchor: Node3D, center: Vector3, radius: float) -> void:
	if not near(anchor, center):
		return
	var fire := school_color(SpellDB.School.FIRE)
	var column := _particles("flame", fire, 1.1, PILLAR_TIME, false)
	column.amount = count(140)
	column.local_coords = false
	column.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	column.emission_ring_axis = Vector3.UP
	column.emission_ring_radius = radius * 0.3
	column.emission_ring_inner_radius = 0.0
	column.emission_ring_height = 0.3
	column.direction = Vector3.UP
	column.spread = 6.0
	column.initial_velocity_min = PILLAR_HEIGHT / PILLAR_TIME * 0.7
	column.initial_velocity_max = PILLAR_HEIGHT / PILLAR_TIME
	column.gravity = Vector3.ZERO
	column.color_ramp = _flame_ramp()
	_place(anchor, column, center)
	column.emitting = true
	var tween := column.create_tween()
	tween.tween_interval(PILLAR_TIME)
	tween.tween_callback(func() -> void: column.emitting = false)
	tween.tween_interval(PILLAR_TIME + 0.2)
	tween.tween_callback(column.queue_free)
	_flash(anchor, center + Vector3.UP * 0.6, "flash", fire.lerp(Color.WHITE, 0.4), radius * 0.3, 0.2, Vector2(0.6, 1.0))
	school_burst(anchor, center + Vector3.UP * 0.5, SpellDB.School.FIRE, 24, radius * 0.5)
	light(anchor, center + Vector3.UP * 2.0, fire, 4.0, 0.6)


## The flames Pillar of Flame leaves burning on the ground until stop_rain:
## tongues of fire and embers rising across the circle.
static func burning_ground(anchor: Node3D, center: Vector3, radius: float) -> Node3D:
	if not near(anchor, center):
		return null
	var root := Node3D.new()
	root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_place(anchor, root, center)
	var fire := school_color(SpellDB.School.FIRE)
	_ground_patch(root, center, radius, "scorch")
	for layer in [["flame", 0.6, 0.7, 2.6, 60], ["mote", 0.12, 1.4, 1.8, 24]]:
		var p := _particles(layer[0], fire.lightened(0.2) if layer[0] == "mote" else fire, layer[1], layer[2], false)
		p.amount = count(maxi(roundi(float(layer[4]) * radius / 5.0), 6))
		p.local_coords = false
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_axis = Vector3.UP
		p.emission_ring_radius = radius
		p.emission_ring_inner_radius = 0.0
		p.emission_ring_height = 0.1
		p.direction = Vector3.UP
		p.spread = 15.0
		p.initial_velocity_min = float(layer[3]) * 0.5
		p.initial_velocity_max = float(layer[3])
		p.gravity = Vector3(0, 0.5, 0)
		if layer[0] == "flame":
			p.color_ramp = _flame_ramp()
		root.add_child(p)
		p.position = Vector3.UP * 0.1
		p.emitting = true
	return root


## White-yellow at the heart, going orange and red as flames rise.
static func _flame_ramp() -> Gradient:
	if _rain_materials.has("flame_ramp"):
		return _rain_materials.flame_ramp
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.7))
	ramp.set_color(1, Color(0.8, 0.15, 0.05, 0.0))
	ramp.add_point(0.4, Color(1.0, 0.6, 0.15))
	_rain_materials.flame_ramp = ramp
	return ramp


## Hailstorm: frost spreading on the ground and a cold mist over it, and
## stones falling one by one (HAIL_PER_SECOND), each with a frosty trail,
## bursting into ice where it lands.
static func _hailstorm(root: Node3D, center: Vector3, radius: float) -> void:
	_ground_patch(root, center, radius, "frost")
	var frost := school_color(SpellDB.School.FROST)
	var mist := _particles("wisp", frost.lightened(0.4), 1.2, 2.2, true)
	mist.amount = count(maxi(roundi(radius * 2.0), 6))
	mist.local_coords = false
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	mist.emission_ring_axis = Vector3.UP
	mist.emission_ring_radius = radius
	mist.emission_ring_inner_radius = 0.0
	mist.emission_ring_height = 0.3
	mist.direction = Vector3.UP
	mist.spread = 60.0
	mist.initial_velocity_min = 0.1
	mist.initial_velocity_max = 0.4
	mist.gravity = Vector3.ZERO
	mist.color = Color(frost.lightened(0.4), 0.5)
	root.add_child(mist)
	mist.position = Vector3.UP * 0.5
	mist.emitting = true
	var timer := Timer.new()
	timer.wait_time = 1.0 / maxf(HAIL_PER_SECOND * radius / 10.0 * (LOW_AMOUNT if quality == "Low" else 1.0), 1.0)
	timer.autostart = true
	timer.timeout.connect(func() -> void:
		if is_instance_valid(root) and not root.get_meta("stopping", false):
			_hailstone(root, center, radius))
	root.add_child(timer)


## One hailstone: a big ice crystal falling at HAIL_SPEED from RAIN_HEIGHT to
## a random point of the circle, trailing frost, then bursting there.
static func _hailstone(root: Node3D, center: Vector3, radius: float) -> void:
	var a := randf() * TAU
	var land := center + Vector3(cos(a), 0.0, sin(a)) * radius * sqrt(randf())
	# Where the ground is there (a ray down), so it bursts on it.
	var space := root.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(land + Vector3.UP * 4.0, land + Vector3.DOWN * 6.0, 1))
	if not hit.is_empty():
		land = hit.position
	var start := land + Vector3(randf_range(-1.5, 1.5), RAIN_HEIGHT, randf_range(-1.5, 1.5))
	var frost := school_color(SpellDB.School.FROST)
	var stone := Node3D.new()
	stone.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var body := MeshInstance3D.new()
	body.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	body.mesh = _rain_mesh("hail")
	body.material_override = _rain_material()
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.scale = Vector3.ONE * randf_range(0.8, 1.25)
	stone.add_child(body)
	var trail := _particles("shard", frost.lightened(0.2), 0.16, 0.45, false)
	trail.amount = count(14)
	trail.local_coords = false
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = HAIL_SIZE * 0.3
	trail.initial_velocity_max = 0.3
	trail.gravity = Vector3(0, 1.0, 0)
	stone.add_child(trail)
	root.add_child(stone)
	stone.global_position = start
	# Pointing along its fall, turning as it comes.
	stone.look_at(land, Vector3.FORWARD if absf((land - start).normalized().y) > 0.99 else Vector3.UP)
	body.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	trail.emitting = true
	var time := start.distance_to(land) / HAIL_SPEED
	var tween := stone.create_tween()
	tween.tween_property(stone, "global_position", land, time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(body, "rotation:y", TAU * 2.0, time)
	tween.tween_callback(func() -> void:
		body.queue_free()
		trail.emitting = false
		burst(root, land + Vector3.UP * 0.2, frost.lightened(0.3), 10, 3.2, 0.11, 0.45, -9.0, 70.0, Vector3.UP, 0.1, "shard")
		_flash(root, land + Vector3.UP * 0.3, "flash", frost.lerp(Color.WHITE, 0.5), 0.7, 0.15, Vector2(0.4, 1.0)))
	tween.tween_interval(0.5)
	tween.tween_callback(stone.queue_free)


## A patch on the ground under an area (a decal, units left out), fading in:
## "frost" (pale blue crystals spreading) or "scorch" (blackened ground with
## glowing embers).
static func _ground_patch(root: Node3D, center: Vector3, radius: float, kind: String) -> Decal:
	var decal := Decal.new()
	decal.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	decal.texture_albedo = _patch_texture(kind, false)
	decal.texture_emission = _patch_texture(kind, true)
	decal.emission_energy = 1.4 if kind == "scorch" else 0.5
	decal.size = Vector3(radius * 2.0, 6.0, radius * 2.0)
	decal.cull_mask = ~Targeting.UNIT_RENDER_LAYER & 0xFFFFF
	decal.normal_fade = 0.5
	decal.upper_fade = 0.2
	decal.lower_fade = 0.2
	decal.modulate = Color(1, 1, 1, 0)
	root.add_child(decal)
	decal.global_position = center
	decal.create_tween().tween_property(decal, "modulate:a", 1.0, PATCH_FADE)
	return decal


## The patches' textures, painted once: the colour (albedo, its alpha the
## patch's shape: ragged at the edge) and the glow (emission, black where
## nothing glows; it ignores alpha).
static func _patch_texture(kind: String, glow: bool) -> ImageTexture:
	var key := "patch_%s_%s" % [kind, glow]
	if _textures.has(key):
		return _textures[key]
	var size := PATCH_TEXTURE_SIZE
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 7 if kind == "frost" else 11
	noise.frequency = 0.09
	var half := size / 2.0
	for y in size:
		for x in size:
			var r := Vector2(x + 0.5 - half, y + 0.5 - half).length() / half
			var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
			# Ragged at the edge: the noise eats into it.
			var cover := clampf((1.0 - r) * 3.5 + (n - 0.5) * 1.2, 0.0, 1.0)
			var color := Color(0, 0, 0, 0)
			if kind == "frost":
				var crystal := n > 0.62
				if glow:
					color = Color(0.25, 0.4, 0.55) * cover if crystal else Color(0, 0, 0)
				else:
					color = Color(0.82, 0.92, 1.0, cover * (0.85 if crystal else 0.55))
			else:
				var ember := n > 0.68 and r < 0.9
				if glow:
					color = Color(1.0, 0.45, 0.1) * cover * ((n - 0.68) / 0.32 * 1.5 + 0.3) if ember else Color(0, 0, 0)
				else:
					color = Color(0.08, 0.05, 0.03, cover * 0.85) if not ember else Color(0.9, 0.35, 0.08, cover)
			color.a = 1.0 if glow else color.a
			image.set_pixel(x, y, color)
	var texture := ImageTexture.create_from_image(image)
	_textures[key] = texture
	return texture
