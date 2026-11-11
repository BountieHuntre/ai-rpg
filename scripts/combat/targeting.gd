class_name Targeting
extends Node
## Tracks the player's current target (a creature, an NPC or a playerbot) and
## draws the ring under it: a decal projected down onto the ground, so all of
## it shows on slopes, steps and rocks. Units' meshes are on their own render
## layer (UNIT_RENDER_LAYER, `mark_unit`) that the decal leaves alone.

## A corpse or a game object (GameObject) to loot.
signal loot_requested(corpse: Node3D, take_all: bool)
## Right-click on a friendly NPC.
signal npc_clicked(npc: Node3D)

const UNIT_LAYER := 2
## Render layer bit for units' meshes (the player, bots, creatures, NPCs),
## which the ring isn't projected onto.
const UNIT_RENDER_LAYER := 1 << 1
## The ring: inner and outer radius at a target's normal size, and how far
## up and down it reaches to find the ground, in yards.
const RING_INNER := 0.55
const RING_OUTER := 0.9
## The dark edge on both sides of the band, so it shows on bright ground.
const RING_EDGE := 0.05
## Far off, the ring grows: from FAR_START yards from the camera, up to
## FAR_GROWTH times its size at FAR_START + FAR_SPAN.
const FAR_START := 8.0
const FAR_SPAN := 32.0
const FAR_GROWTH := 3.0
const RING_REACH := 3.0
## Pixels across the ring's texture.
const RING_TEXTURE_SIZE := 96
const HOSTILE_COLOR := Color(0.8, 0.2, 0.2)
const NEUTRAL_COLOR := Color(0.95, 0.8, 0.15)
const FRIENDLY_COLOR := Color(0.25, 1, 0.25)
## Other players' names, as classic shows friendly players.
const PLAYER_COLOR := Color(0.35, 0.6, 1)
## Creatures someone outside your group tapped.
const TAPPED_COLOR := Color(0.6, 0.6, 0.6)
## In combat with the target, the ring flashes red this many times a second.
const COMBAT_FLASH_RATE := 2.0

@export var tab_range := 40.0

## An Enemy, a friendly Npc or a Bot.
var target: Node3D

@onready var _player: Player = get_parent()
var _ring := Decal.new()
static var _ring_texture: ImageTexture
var _flash_time := 0.0


## The target's Combatant if it's a creature, or null.
func target_combatant() -> Combatant:
	var enemy := target as Enemy
	return enemy.combatant if enemy else null


## The targeted playerbot's Combatant (alive or dead), or null.
func friendly_combatant() -> Combatant:
	var bot := target as Bot
	return bot.combatant if bot else null


## Reaction colors: red for creatures that attack on sight, yellow for
## passive ones that only fight back, green for friendly NPCs.
static func reaction_color(unit: Node) -> Color:
	if unit is Npc or unit is PlayerUnit:
		return FRIENDLY_COLOR
	var enemy := unit as Enemy
	if enemy and not enemy.is_aggressive():
		return NEUTRAL_COLOR
	return HOSTILE_COLOR


## The same reactions as text colors, brighter so names read well: red for
## aggressive creatures, yellow for passive ones, green for friendly NPCs.
static func name_color(unit: Node) -> Color:
	if unit is Npc:
		return FRIENDLY_COLOR
	if unit is PlayerUnit:
		return PLAYER_COLOR
	var enemy := unit as Enemy
	if enemy and enemy.is_tapped_by_others():
		return TAPPED_COLOR
	if enemy and not enemy.is_aggressive():
		return Color(1, 0.85, 0.15)
	return Color(1, 0.25, 0.2)


func set_target(node: Node3D) -> void:
	if node and node != target:
		Sfx.play("target")
	target = node
	if target:
		_set_ring_color(reaction_color(target))
	# Auto-attack follows target changes but never starts from selecting alone.
	if _player.combatant.attack_target:
		_player.combatant.attack_target = target_combatant()


## Moves to the next enemy on screen, nearest first, as Tab does in WoW.
func cycle() -> void:
	var camera := _player.get_viewport().get_camera_3d()
	var candidates: Array[Enemy] = []
	for node in _player.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		var in_range := _player.global_position.distance_to(enemy.global_position) <= tab_range
		if enemy.combatant.is_alive() and in_range and camera.is_position_in_frustum(enemy.global_position):
			candidates.append(enemy)
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return _player.global_position.distance_to(a.global_position) < _player.global_position.distance_to(b.global_position)
	)
	var next := candidates.find(target) + 1
	set_target(candidates[next % candidates.size()])


## How many looted corpses a click can pass through.
const CLICK_THROUGH := 8


## The creature, corpse or NPC under a point of the game view, or null.
## Corpses already looted are clicked through, to whatever lies under them
## (another corpse to loot, a creature).
func unit_at(screen_position: Vector2) -> Node3D:
	var camera := _player.get_viewport().get_camera_3d()
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * camera.far
	var query := PhysicsRayQueryParameters3D.create(from, to, UNIT_LAYER | Enemy.CORPSE_LAYER)
	var skipped: Array[RID] = [_player.get_rid()]
	var space := _player.get_world_3d().direct_space_state
	for attempt in CLICK_THROUGH:
		query.exclude = skipped
		var collider := space.intersect_ray(query).get("collider") as Node3D
		var corpse := collider as Enemy
		if corpse == null or corpse.combatant.is_alive() or corpse.has_loot():
			return collider
		skipped.append(corpse.get_rid())
	return null


## As in classic: left click selects the creature or NPC under the cursor.
## Right click also acts on it: attacks a creature, talks to an NPC, loots a
## corpse.
func on_camera_clicked(screen_position: Vector2, button: MouseButton) -> void:
	var collider := unit_at(screen_position)
	if collider is Npc:
		set_target(collider)
		if button == MOUSE_BUTTON_RIGHT:
			npc_clicked.emit(collider)
		return
	# Right-clicking a game object (a Bundle of Wood) opens it, when it holds
	# something a quest needs.
	if collider is GameObject:
		var thing := collider as GameObject
		if button == MOUSE_BUTTON_RIGHT and thing.open():
			loot_requested.emit(thing, Input.is_key_pressed(KEY_SHIFT) != Settings.get_value("auto_loot"))
		return
	# Clicking a playerbot only targets it: its menu is on the target and
	# party frames.
	if collider is Bot:
		set_target(collider)
		return
	var enemy := collider as Enemy
	if not enemy:
		return
	if not enemy.combatant.is_alive():
		# Right-clicking a corpse loots it. Shift loots everything at once.
		if button == MOUSE_BUTTON_RIGHT and enemy.has_loot():
			# Shift does the opposite of the Auto Loot option, as in classic.
			loot_requested.emit(enemy, Input.is_key_pressed(KEY_SHIFT) != Settings.get_value("auto_loot"))
		return
	set_target(enemy)
	if button == MOUSE_BUTTON_RIGHT:
		_player.combatant.attack_target = enemy.combatant


func _ready() -> void:
	if not _ring_texture:
		_ring_texture = _make_ring_texture()
	_ring.texture_albedo = _ring_texture
	# Lit by its own glow, as the unshaded torus was.
	_ring.texture_emission = _ring_texture
	_ring.emission_energy = 2.0
	_ring.size = Vector3(RING_OUTER * 2.0, RING_REACH * 2.0, RING_OUTER * 2.0)
	_ring.cull_mask = ~UNIT_RENDER_LAYER & 0xFFFFF
	_ring.upper_fade = 0.0
	_ring.lower_fade = 0.0
	_ring.top_level = true
	# Placed every drawn frame where the target is drawn, so not interpolated
	# itself.
	_ring.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_ring.visible = false
	add_child(_ring)


## Puts every mesh under a unit on UNIT_RENDER_LAYER, out of the ring's way.
static func mark_unit(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = UNIT_RENDER_LAYER
	for child in node.get_children():
		mark_unit(child)


## A white ring on clear, its edges hard (pixel art), for the decal.
static func _make_ring_texture() -> ImageTexture:
	var size := RING_TEXTURE_SIZE
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := size / 2.0
	for y in size:
		for x in size:
			var r := Vector2(x + 0.5 - half, y + 0.5 - half).length() / half * RING_OUTER
			# Clear pixels black too: the glow (emission) ignores alpha. The
			# edges are dark, so the band shows on bright ground.
			var color := Color(0, 0, 0, 0)
			if r >= RING_INNER and r <= RING_OUTER:
				color = Color.WHITE if r >= RING_INNER + RING_EDGE and r <= RING_OUTER - RING_EDGE else Color(0, 0, 0, 0.85)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


func _set_ring_color(color: Color) -> void:
	_ring.modulate = color


## Whether the target is fighting the player: being auto-attacked, or chasing.
func in_combat_with_target() -> bool:
	var enemy := target as Enemy
	if enemy == null or not enemy.combatant.is_alive():
		return false
	return _player.combatant.attack_target == enemy.combatant or (enemy.state == Enemy.State.CHASE and enemy.threat.has(_player.combatant))


func _process(delta: float) -> void:
	# A target removed from the world (a deleted bot, a spawned creature gone).
	if target != null and not is_instance_valid(target):
		target = null
	if target is Enemy and not (target as Enemy).combatant.is_alive():
		set_target(null)
	_ring.visible = target != null
	if target:
		_ring.global_position = target.get_global_transform_interpolated().origin
		# As big as the target is drawn (big creatures, elites and bosses).
		var visual := target.get_node_or_null("Visual") as Node3D
		var size := clampf(visual.scale.x, 0.8, 2.0) if visual else 1.0
		var camera := _player.get_viewport().get_camera_3d()
		if camera:
			var far := clampf((camera.global_position.distance_to(target.global_position) - FAR_START) / FAR_SPAN, 0.0, 1.0)
			size *= lerpf(1.0, FAR_GROWTH, far)
		_ring.size = Vector3(RING_OUTER * 2.0 * size, RING_REACH * 2.0, RING_OUTER * 2.0 * size)
		if in_combat_with_target():
			# Flashes between bright and dark red.
			_flash_time += delta
			var pulse := 0.5 + 0.5 * cos(_flash_time * TAU * COMBAT_FLASH_RATE)
			_set_ring_color(HOSTILE_COLOR.darkened(0.7).lerp(Color(1, 0.25, 0.2), pulse))
		else:
			_flash_time = 0.0
			_set_ring_color(reaction_color(target))
