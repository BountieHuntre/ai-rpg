class_name Fire
extends Node3D
## A fire that burns: flames licking up in the game's pixel look (Vfx's
## painted flame sprite on camera-facing particles, cut out, white-yellow at
## the heart going orange and red as they rise and shrink), embers drifting
## up, smoke over the bigger ones, and a warm light that flickers. Unlike the
## rest of the world, fire has no outline (_quad). Torches,
## campfires, hearths, fire pits and lamps all burn this way (Fire.make, or
## BuildingKit.fire for buildings). Only fires within ACTIVE_RANGE yards of
## the camera burn and flicker; further ones go still (their light steady),
## so a zone full of torches costs only the near ones.

## Yards from the camera within which fires burn and flicker.
static var ACTIVE_RANGE := 40.0
## How often (seconds) a fire looks again at how far the camera is.
static var CHECK_EVERY := 0.3
## A fire's light: how far it dips and rises (share of its energy), and how
## far (yards) it wavers about.
static var FLICKER := 0.22
static var WAVER := 0.05
## Fires at least this big smoke (torches and lamps don't).
static var SMOKE_SIZE := 0.5
## How solid each part of a fire is (1 solid, 0 unseen); changed live.
## The flame tongues.
static var FLAME_OPACITY := 1.0
## The bright heart at the base.
static var HEART_OPACITY := 1.0
## The embers drifting up.
static var EMBER_OPACITY := 1.0
## The smoke over big fires.
static var SMOKE_OPACITY := 1.0
## How fast the flames play (1 is their natural speed).
static var FLAME_SPEED := 0.5

var light: OmniLight3D
var size := 0.3
var _energy := 1.0
var _light_at := Vector3.ZERO
var _particles: Array[GPUParticles3D] = []
var _active := true
var _wait := 0.0
var _time := 0.0
var _phase := 0.0

static var _gradients: Dictionary = {}
## Each gradient's colours at full opacity, and the opacities last laid on
## them (_sync_opacity).
static var _solid_colors: Dictionary = {}
static var _applied_opacity := []
static var _synced_frame := -1
static var _quads: Dictionary = {}
static var _curves: Dictionary = {}


## A fire at `at` (its base, local to `parent`) `size` yards across, with a
## light of `light_range` and `energy` above it (none when light_range is
## 0). A `size` of 0 makes only the flickering light (a lamp whose flame is
## part of a building).
static func make(parent: Node3D, at: Vector3, fire_size: float, light_range: float, energy := 1.0, color := Color(1.0, 0.65, 0.35)) -> Fire:
	var fire := Fire.new()
	fire.name = "Fire"
	fire.size = fire_size
	fire.position = at
	fire._phase = absf(at.x * 3.7 + at.z * 5.3 + at.y)
	fire.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(fire)
	if fire_size > 0.0 and Vfx.quality != "Off":
		fire._build_flames()
	if light_range > 0.0:
		var lamp := OmniLight3D.new()
		lamp.light_color = color
		lamp.omni_range = light_range
		lamp.light_energy = energy
		lamp.shadow_enabled = false
		# Lights the place, not the dust in it (rooms' and caves' haze).
		lamp.light_volumetric_fog_energy = 0.0
		lamp.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		fire._light_at = Vector3(0, maxf(fire_size, 0.15) * 1.2, 0)
		lamp.position = fire._light_at
		fire.add_child(lamp)
		fire.light = lamp
		fire._energy = energy
	return fire


func _build_flames() -> void:
	var low := Vfx.quality == "Low"
	var many := 1.0 if not low else 0.6
	# The flames: many small tongues, short-lived, rising fast and narrowing
	# away, over a bright heart at the base.
	_particles.append(_emitter("flame", size * 0.42, maxi(roundi((16.0 + size * 40.0) * many), 9), 0.5,
		"flame", Vector3(size * 0.3, size * 0.06, size * 0.3), size * 1.8, 14.0, size * 1.6, "flame"))
	_particles.append(_emitter("flame", size * 0.3, maxi(roundi((8.0 + size * 16.0) * many), 5), 0.28,
		"heart", Vector3(size * 0.18, 0.0, size * 0.18), size * 0.9, 8.0, size * 0.6, "flame"))
	# The flames move a little slower than they'd fly, so they lick rather
	# than spray (the same height, as their life slows with them).
	for flames in _particles:
		flames.speed_scale = FLAME_SPEED
	# Embers: a few sparks drifting higher.
	_particles.append(_emitter("mote", maxf(size * 0.09, 0.035), maxi(roundi((2.0 + size * 6.0) * many), 2), 1.6,
		"ember", Vector3(size * 0.3, 0.05, size * 0.3), 0.9 + size, 35.0, 0.6, "ember"))
	# Thin smoke well over the bigger fires.
	if size >= SMOKE_SIZE and not low:
		var smoke := _emitter("wisp", size * 0.5, 3, 3.0,
			"smoke", Vector3(size * 0.15, 0.0, size * 0.15), 0.6, 10.0, 0.3, "smoke")
		smoke.position = Vector3(0, size * 1.8, 0)
		_particles.append(smoke)


## A particle emitter of `sprite` quads `quad` yards across.
func _emitter(sprite: String, quad: float, amount: int, life: float, ramp: String, box: Vector3, speed: float, spread: float, lift: float, curve: String) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = life
	particles.randomness = 0.4
	particles.preprocess = life
	particles.draw_pass_1 = _quad(sprite, quad)
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	particles.visibility_aabb = AABB(Vector3(-1.5, -0.5, -1.5) * maxf(size, 0.3) * 2.0, Vector3(3.0, 6.0, 3.0) * maxf(size, 0.3) * 2.0)
	# Each sprite starts above the base rather than centred on it, so no
	# flame hangs below what's burning.
	particles.position.y = quad * 0.45
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = box
	process.direction = Vector3.UP
	process.spread = spread
	process.initial_velocity_min = speed * 0.5
	process.initial_velocity_max = speed
	process.gravity = Vector3(0, lift, 0)
	process.damping_min = 0.5
	process.damping_max = 1.5
	process.angle_min = -15.0
	process.angle_max = 15.0
	var curve_texture := CurveTexture.new()
	curve_texture.curve = _curve(curve)
	process.scale_curve = curve_texture
	process.scale_min = 0.7
	process.scale_max = 1.2
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = _gradient(ramp)
	process.color_ramp = ramp_texture
	particles.process_material = process
	add_child(particles)
	return particles


## A camera-facing quad of Vfx's painted sprite, coloured by its particles'
## colour, with no outline (Vfx.NO_OUTLINE).
static func _quad(sprite: String, quad_size: float) -> QuadMesh:
	var key := "%s:%s" % [sprite, quad_size]
	if not _quads.has(key):
		var material := Vfx._sprite_material(sprite)
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		material.vertex_color_use_as_albedo = true
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * quad_size
		quad.material = material
		_quads[key] = quad
	return _quads[key]


## How a kind of particle's colour goes over its life.
static func _gradient(kind: String) -> Gradient:
	if not _gradients.has(kind):
		var gradient := Gradient.new()
		match kind:
			"flame":
				gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
				gradient.colors = PackedColorArray([Color(1.6, 1.45, 0.85), Color(1.5, 0.95, 0.3), Color(1.2, 0.45, 0.1), Color(0.75, 0.16, 0.05)])
			"heart":
				gradient.offsets = PackedFloat32Array([0.0, 1.0])
				gradient.colors = PackedColorArray([Color(1.8, 1.7, 1.2), Color(1.6, 1.2, 0.45)])
			"ember":
				gradient.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
				gradient.colors = PackedColorArray([Color(1.6, 1.0, 0.4), Color(1.3, 0.5, 0.12), Color(0.6, 0.15, 0.05)])
			_:
				gradient.offsets = PackedFloat32Array([0.0, 1.0])
				gradient.colors = PackedColorArray([Color(0.4, 0.38, 0.36), Color(0.55, 0.53, 0.5)])
		_gradients[kind] = gradient
		_solid_colors[kind] = gradient.colors.duplicate()
		_applied_opacity = []
	return _gradients[kind]


## How solid a part of a fire is (its *_OPACITY).
static func opacity(kind: String) -> float:
	match kind:
		"flame": return FLAME_OPACITY
		"heart": return HEART_OPACITY
		"ember": return EMBER_OPACITY
	return SMOKE_OPACITY


## Lays the parts' opacities on their gradients (shared by every fire) when
## they've changed, once a frame at most.
static func _sync_opacity() -> void:
	var frame := Engine.get_process_frames()
	if frame == _synced_frame:
		return
	_synced_frame = frame
	var now := [FLAME_OPACITY, HEART_OPACITY, EMBER_OPACITY, SMOKE_OPACITY]
	if now == _applied_opacity:
		return
	_applied_opacity = now
	for kind: String in _gradients:
		var colors: PackedColorArray = (_solid_colors[kind] as PackedColorArray).duplicate()
		for i in colors.size():
			colors[i].a = clampf(opacity(kind), 0.0, 1.0)
		(_gradients[kind] as Gradient).colors = colors


## How a kind of particle's size goes over its life.
static func _curve(kind: String) -> Curve:
	if not _curves.has(kind):
		var curve := Curve.new()
		match kind:
			"flame":
				# Full at the base, a tongue narrowing to nothing.
				curve.add_point(Vector2(0.0, 0.8))
				curve.add_point(Vector2(0.2, 1.0))
				curve.add_point(Vector2(1.0, 0.0))
			"ember":
				curve.add_point(Vector2(0.0, 1.0))
				curve.add_point(Vector2(0.7, 0.8))
				curve.add_point(Vector2(1.0, 0.0))
			_:
				# Smoke swells as it rises, then thins away.
				curve.add_point(Vector2(0.0, 0.3))
				curve.add_point(Vector2(0.6, 1.0))
				curve.add_point(Vector2(1.0, 0.0))
		_curves[kind] = curve
	return _curves[kind]


func _process(delta: float) -> void:
	_sync_opacity()
	_wait -= delta
	if _wait <= 0.0:
		_wait = CHECK_EVERY
		var camera := get_viewport().get_camera_3d() if get_viewport() != null else null
		var near := camera != null and camera.global_position.distance_squared_to(global_position) < ACTIVE_RANGE * ACTIVE_RANGE
		if near != _active:
			_active = near
			for particles in _particles:
				particles.emitting = near
				particles.visible = near
			if light != null and not near:
				light.light_energy = _energy
				light.position = _light_at
	if not _active or light == null:
		return
	# The light dips and rises at rates that don't line up, with a sudden
	# gutter now and then, and wavers about as the flames move.
	_time += delta
	var t := _time + _phase
	var wave := sin(t * 11.3) * 0.45 + sin(t * 23.7 + 1.3) * 0.3 + sin(t * 5.1 + 2.1) * 0.25
	var gutter := maxf(sin(t * 1.7 + _phase) - 0.92, 0.0) * 6.0
	light.light_energy = _energy * (1.0 + wave * FLICKER - gutter * FLICKER)
	light.position = _light_at + Vector3(sin(t * 7.9) , sin(t * 13.1) * 0.6, cos(t * 9.3)) * WAVER
