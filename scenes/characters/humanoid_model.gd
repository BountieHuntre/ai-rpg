class_name HumanoidModel
extends Node3D
## A character model: Human, Dwarf or Gnome (assets/models/<race>/<race>.glb,
## all built by tools/models/human/build_human.py on one skeleton): a body,
## hair and beard from an appearance, the gear worn (armour colours, helm,
## cloak, weapons and shield in hand, the ranged weapon while shooting), and
## animations driven by the unit it stands for.
##
## Set `race` (RACE_MODELS), put it under a unit's Visual and call
## `attach(unit)` for a player unit or `attach_creature(enemy)`; without one
## (the character preview, NPCs) it idles. Colours come from one
## ShaderMaterial a model (shaders/character.gdshader), its slots in the enum.

const SHADER := preload("res://shaders/character.gdshader")
## Races with a model: ClassicData.Race -> its file's name.
const RACE_MODELS := { ClassicData.Race.HUMAN: "human", ClassicData.Race.DWARF: "dwarf", ClassicData.Race.GNOME: "gnome" }
## Colour slots, as the build script's SLOT_NAMES; the shader has room for 32.
const SLOT_COUNT := 32

enum { SKIN, HAIR, EYES, CHEST, LEGS, FEET, HANDS, WAIST, SHOULDERS, WRISTS, HEAD, TRIM, BLADE, HANDLE, SHIELD, SHIELD_TRIM,
	BACK, RANGED, RANGED_TRIM, HELM_TRIM }

const SKIN_COLORS := [
	Color(0.96, 0.8, 0.68), Color(0.9, 0.71, 0.56), Color(0.8, 0.59, 0.43),
	Color(0.64, 0.45, 0.32), Color(0.46, 0.32, 0.22), Color(0.98, 0.86, 0.78),
]
const HAIR_COLORS := [
	Color(0.1, 0.08, 0.07), Color(0.26, 0.16, 0.09), Color(0.45, 0.28, 0.14), Color(0.6, 0.24, 0.1),
	Color(0.86, 0.7, 0.4), Color(0.62, 0.6, 0.58), Color(0.95, 0.9, 0.8),
]
## Hair meshes per body ("" is none), then beards (men only).
const HAIR_STYLES := [["HairShort", "HairLong", "HairCrest", ""], ["HairFLong", "HairFTail", "HairFBun", "HairShort"]]
const FACES := [["", "BeardShort", "BeardLong"], [""]]
const BODIES := ["BodyMale", "BodyFemale"]
const EYE_COLOR := Color(0.1, 0.09, 0.12)
## Bare legs show smallclothes.
const SMALLCLOTHES := Color(0.62, 0.58, 0.5)
const TRIM_COLOR := Color(0.72, 0.56, 0.26)
const WOOD := Color(0.4, 0.26, 0.13)
const STEEL := Color(0.72, 0.74, 0.78)
const INVTYPE_ROBE := 20

## Armour colours by subclass (cloth, leather, mail, plate), picked by item.
const CLOTH := [Color(0.6, 0.2, 0.17), Color(0.2, 0.3, 0.58), Color(0.3, 0.45, 0.2), Color(0.45, 0.28, 0.55),
	Color(0.66, 0.6, 0.45), Color(0.4, 0.32, 0.25)]
const LEATHER := [Color(0.45, 0.3, 0.17), Color(0.33, 0.21, 0.12), Color(0.55, 0.4, 0.24), Color(0.28, 0.25, 0.22)]
const MAIL := [Color(0.56, 0.58, 0.62), Color(0.45, 0.47, 0.5), Color(0.52, 0.46, 0.4)]
const PLATE := [Color(0.74, 0.76, 0.8), Color(0.78, 0.66, 0.38), Color(0.6, 0.63, 0.7)]
## Words in an item's name that say its colour.
const NAME_COLORS := {
	"red": Color(0.62, 0.15, 0.12), "crimson": Color(0.6, 0.1, 0.12), "scarlet": Color(0.7, 0.15, 0.1),
	"blood": Color(0.5, 0.08, 0.08), "blue": Color(0.18, 0.28, 0.62), "azure": Color(0.25, 0.45, 0.75),
	"green": Color(0.25, 0.48, 0.2), "emerald": Color(0.12, 0.5, 0.3), "black": Color(0.12, 0.12, 0.14),
	"shadow": Color(0.18, 0.15, 0.22), "dark": Color(0.2, 0.18, 0.2), "white": Color(0.88, 0.88, 0.85),
	"silver": Color(0.78, 0.8, 0.84), "gold": Color(0.85, 0.68, 0.3), "golden": Color(0.85, 0.68, 0.3),
	"purple": Color(0.42, 0.2, 0.55), "violet": Color(0.5, 0.3, 0.65), "brown": Color(0.38, 0.25, 0.14),
	"grey": Color(0.48, 0.48, 0.5), "gray": Color(0.48, 0.48, 0.5), "linen": Color(0.72, 0.66, 0.52),
}
## Weapon subclass -> prop.
const MAIN_PROPS := {
	0: "axe", 1: "axe2h", 4: "mace", 5: "mace2h", 6: "polearm", 7: "sword", 8: "sword2h",
	10: "staff", 13: "fist", 15: "dagger", 20: "staff",
}
const OFF_PROPS := { 0: "axe", 4: "mace", 7: "sword", 13: "fist", 15: "dagger" }
## Head armour subclass -> helm (cloth hood, leather cap, mail coif, plate helm).
const HELMS := { 0: "Helm_cap", 1: "Helm_hood", 2: "Helm_cap", 3: "Helm_coif", 4: "Helm_plate" }
## Ranged weapon subclass -> the prop drawn while shooting, and how it's shot.
const RANGED_PROPS := { 2: "Ranged_bow", 3: "Ranged_gun", 18: "Ranged_gun", 16: "Ranged_thrown", 19: "Main_wand" }
const RANGED_SHOTS := { 2: "shoot_bow", 3: "shoot_gun", 18: "shoot_gun", 16: "throw", 19: "shoot_wand" }

## Animations that loop.
const LOOPS := ["idle", "ready", "walk", "run", "backpedal", "strafe_left", "strafe_right", "fall", "sit",
	"stunned", "dead", "cast", "channel", "dance", "aim_bow", "aim_gun"]
const LOCO := ["idle", "ready", "walk", "run", "backpedal", "strafe_left", "strafe_right", "fall", "sit",
	"stunned", "dead", "cast", "channel", "dance", "aim_bow", "aim_gun"]
const UPPER := ["attack_1h", "attack_1h_b", "attack_2h", "attack_off", "punch", "block", "parry", "dodge", "hit",
	"cast_release", "shoot_bow", "shoot_gun", "throw", "shoot_wand"]
const FULL := ["jump", "land", "sit_down", "stand_up", "death", "wave", "bow", "cheer", "nod", "laugh", "cry"]
## Bones the upper-body actions move; the legs keep walking.
const UPPER_BONES := ["Spine", "Chest", "Neck", "Head", "RightShoulder", "RightUpperArm", "RightLowerArm",
	"RightHand", "LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand", "WeaponR", "WeaponL", "ShieldL"]
## Emote commands -> animations.
const EMOTES := {
	"wave": "wave", "hello": "wave", "bye": "wave", "bow": "bow", "cheer": "cheer", "thank": "nod",
	"laugh": "laugh", "cry": "cry", "dance": "dance",
}
## Speeds the walk and run cycles were made for, in yards per second.
const WALK_SPEED := 2.5
const RUN_SPEED := 7.0
## Animation steps by distance from the camera: [beyond yards, seconds], in
## rising order; nearer than the first animates every frame.
const ANIM_STEPS: Array[Vector2] = [Vector2(15, 1.0 / 30.0), Vector2(25, 1.0 / 15.0), Vector2(35, 0.1)]
## Out of view: just enough to keep the pose right when turned to.
const OFF_SCREEN_STEP := 0.5
## How often gear is checked for changes, in seconds.
const GEAR_CHECK := 0.5

## Per race: meshes and skins of every part, from its model file, by name.
static var _parts_by_race: Dictionary = {}
## Per race: the model without its parts, instanced for each character.
static var _bare_by_race: Dictionary = {}
static var _tree_root: AnimationNodeBlendTree

## Which model: "human", "dwarf" or "gnome" (RACE_MODELS). Set before adding.
var race := "human"
## Props for a creature, which has no gear: { "main": prop, "off": prop,
## "helm": helm part } (MAIN_PROPS values, "Off_..." or "Shield_..." parts).
var creature_gear: Dictionary = {}
var appearance: Dictionary = {}
## Clothes shown where nothing is worn (slot enum -> colour), for NPCs.
var outfit: Dictionary = {}
var _material := ShaderMaterial.new()
var _model: Node3D
var _skeleton: Skeleton3D
var _tree: AnimationTree
var _shown: Dictionary = {}
## The unit it stands for: a player unit (_unit) or a creature, with its body
## and combatant.
var _unit: PlayerUnit
var _body: CharacterBody3D
var _combatant: Combatant
var _caster: SpellCaster
var _parts: Dictionary
## Shooting: the ranged weapon is drawn in place of the melee ones.
var _drawn := false
var _was_casting := false
var _profile: CharacterProfile
var _equipment: Dictionary = {}
var _gear_key := -1
var _gear_check := 0.0
var _loco := ""
var _was_sitting := false
var _airborne := 0.0
var _dancing := false
var _dead := false
var _swing := 0
var _colors: Array[Color] = []
## Time not yet given to the AnimationTree (see _advance).
var _anim_time := 0.0


func _init() -> void:
	name = "HumanoidModel"
	_colors.resize(SLOT_COUNT)
	_colors.fill(Color.WHITE)
	_material.shader = SHADER


func _ready() -> void:
	_load(race)
	_parts = _parts_by_race[race]
	_model = _bare_by_race[race].instantiate()
	add_child(_model)
	_skeleton = _model.get_node("Armature/Skeleton3D")
	_tree = AnimationTree.new()
	_tree.name = "AnimationTree"
	add_child(_tree)
	_tree.root_node = _tree.get_path_to(_model)
	_tree.anim_player = _tree.get_path_to(_model.get_node("AnimationPlayer"))
	_tree.tree_root = _tree_root
	_tree.active = true
	# Advanced by hand in _process, less often the further off it is.
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_anim_time = randf() * 0.1
	if appearance.is_empty():
		set_appearance(random_appearance(randi()))
	else:
		_apply_appearance()
	_apply_equipment()
	_set_loco("idle")


## Reads a race's model file once: its parts' meshes and a copy without them.
static func _load(race_name: String) -> void:
	if _bare_by_race.has(race_name):
		return
	var scene: Node3D = load("res://assets/models/%s/%s.glb" % [race_name, race_name]).instantiate()
	var skeleton: Skeleton3D = scene.get_node("Armature/Skeleton3D")
	var parts := {}
	for child in skeleton.get_children():
		if child is MeshInstance3D:
			parts[child.name] = [child.mesh, child.skin]
			skeleton.remove_child(child)
			child.free()
	var player: AnimationPlayer = scene.get_node("AnimationPlayer")
	for anim_name in player.get_animation_list():
		player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR if anim_name in LOOPS else Animation.LOOP_NONE
	var bare := PackedScene.new()
	bare.pack(scene)
	scene.free()
	_parts_by_race[race_name] = parts
	_bare_by_race[race_name] = bare
	if not _tree_root:
		_tree_root = _build_tree()


## The model a race uses, or "" for none yet (the placeholder capsule).
static func model_race(race_id: int) -> String:
	return RACE_MODELS.get(race_id, "")


## Locomotion and lasting states (a crossfading choice, sped up to match the
## unit's speed), with upper-body actions over it and whole-body ones over
## that.
static func _build_tree() -> AnimationNodeBlendTree:
	var tree := AnimationNodeBlendTree.new()
	var loco := AnimationNodeTransition.new()
	loco.xfade_time = 0.18
	_add_choices(tree, loco, "loco", LOCO, Vector2(-600, 0))
	var speed := AnimationNodeTimeScale.new()
	tree.add_node("speed", speed, Vector2(-300, 0))
	tree.connect_node("speed", 0, "loco")
	var upper := AnimationNodeOneShot.new()
	upper.fadein_time = 0.06
	upper.fadeout_time = 0.15
	upper.filter_enabled = true
	for bone in UPPER_BONES:
		upper.set_filter_path(NodePath("Armature/Skeleton3D:" + bone), true)
	var upper_pick := AnimationNodeTransition.new()
	_add_choices(tree, upper_pick, "upper_pick", UPPER, Vector2(-300, 300))
	tree.add_node("upper", upper, Vector2(0, 0))
	tree.connect_node("upper", 0, "speed")
	tree.connect_node("upper", 1, "upper_pick")
	var full := AnimationNodeOneShot.new()
	full.fadein_time = 0.1
	full.fadeout_time = 0.2
	var full_pick := AnimationNodeTransition.new()
	_add_choices(tree, full_pick, "full_pick", FULL, Vector2(0, 300))
	tree.add_node("full", full, Vector2(300, 0))
	tree.connect_node("full", 0, "upper")
	tree.connect_node("full", 1, "full_pick")
	tree.connect_node("output", 0, "full")
	return tree


static func _add_choices(tree: AnimationNodeBlendTree, node: AnimationNodeTransition, node_name: String,
		anims: Array, at: Vector2) -> void:
	tree.add_node(node_name, node, at)
	for i in anims.size():
		var anim := AnimationNodeAnimation.new()
		anim.animation = anims[i]
		var anim_node: String = "%s_%s" % [node_name, anims[i]]
		tree.add_node(anim_node, anim, at + Vector2(-250, i * 60))
		node.add_input(anims[i])
		tree.connect_node(node_name, i, anim_node)


# ---------------------------------------------------------------- looks

## A random look, the same for the same seed.
static func random_appearance(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var body := rng.randi_range(0, 1)
	return {
		"body": body,
		"skin": rng.randi_range(0, SKIN_COLORS.size() - 1),
		"hair": rng.randi_range(0, HAIR_STYLES[body].size() - 1),
		"hair_color": rng.randi_range(0, HAIR_COLORS.size() - 1),
		"face": rng.randi_range(0, FACES[body].size() - 1),
	}


## Fills in what an appearance lacks and keeps its choices in range.
static func clean_appearance(look: Dictionary) -> Dictionary:
	var body := clampi(int(look.get("body", 0)), 0, 1)
	return {
		"body": body,
		"skin": clampi(int(look.get("skin", 0)), 0, SKIN_COLORS.size() - 1),
		"hair": clampi(int(look.get("hair", 0)), 0, HAIR_STYLES[body].size() - 1),
		"hair_color": clampi(int(look.get("hair_color", 0)), 0, HAIR_COLORS.size() - 1),
		"face": clampi(int(look.get("face", 0)), 0, FACES[body].size() - 1),
	}


func set_appearance(look: Dictionary) -> void:
	appearance = clean_appearance(look)
	if _skeleton:
		_apply_appearance()
		_apply_equipment()


func _apply_appearance() -> void:
	var body: int = appearance.body
	for i in BODIES.size():
		_show(BODIES[i], i == body)
	_colors[SKIN] = SKIN_COLORS[appearance.skin]
	_colors[HAIR] = HAIR_COLORS[appearance.hair_color]
	_colors[EYES] = EYE_COLOR
	_colors[TRIM] = TRIM_COLOR
	# Women are a little smaller.
	_model.scale = Vector3.ONE * (0.95 if body == 1 else 1.0)


func _show(part: String, on: bool) -> void:
	if on == _shown.has(part):
		return
	if not on:
		_shown[part].queue_free()
		_shown.erase(part)
		return
	var mesh := MeshInstance3D.new()
	mesh.name = part
	mesh.mesh = _parts[part][0]
	mesh.skin = _parts[part][1]
	mesh.material_override = _material
	_skeleton.add_child(mesh)
	mesh.skeleton = mesh.get_path_to(_skeleton)
	_shown[part] = mesh


## Shows what's worn: Inventory.Slot -> item stack.
func show_equipment(equipment: Dictionary) -> void:
	_equipment = equipment
	if _skeleton:
		_apply_equipment()


func _apply_equipment() -> void:
	var skin: Color = _colors[SKIN]
	var shirt := _armor_color(Inventory.Slot.SHIRT, outfit.get(CHEST, skin))
	var chest := _armor_color(Inventory.Slot.CHEST, shirt)
	_colors[CHEST] = chest
	# Sleeves are the chest piece's, or the shirt's, where no bracers are worn.
	_colors[WRISTS] = _armor_color(Inventory.Slot.WRIST, chest if _item(Inventory.Slot.CHEST).size() > 0 else shirt)
	_colors[HANDS] = _armor_color(Inventory.Slot.HANDS, outfit.get(HANDS, skin))
	_colors[LEGS] = _armor_color(Inventory.Slot.LEGS, outfit.get(LEGS, SMALLCLOTHES))
	# A robe's skirt covers the legs.
	if int(_item(Inventory.Slot.CHEST).get("InventoryType", 0)) == INVTYPE_ROBE:
		_colors[LEGS] = chest
	_colors[FEET] = _armor_color(Inventory.Slot.FEET, outfit.get(FEET, skin))
	_colors[WAIST] = _armor_color(Inventory.Slot.WAIST, outfit.get(WAIST, _colors[LEGS].darkened(0.25)))
	_colors[SHOULDERS] = _armor_color(Inventory.Slot.SHOULDER, chest)
	_show("Shoulders", _item(Inventory.Slot.SHOULDER).size() > 0)
	# A helm hides the hair (and a closed one the beard).
	var head := _item(Inventory.Slot.HEAD)
	var helm: String = creature_gear.get("helm", HELMS.get(int(head.get("subclass", 0)), "Helm_cap") if head.size() > 0 else "")
	for part: String in HELMS.values():
		_show(part, part == helm)
	_colors[HEAD] = _armor_color(Inventory.Slot.HEAD, outfit.get(HEAD, chest))
	_colors[HELM_TRIM] = TRIM_COLOR if int(head.get("Quality", 1)) >= 3 else Color(0.5, 0.5, 0.53)
	var body: int = appearance.get("body", 0)
	var hair: String = HAIR_STYLES[body][appearance.get("hair", 0)] if helm == "" else ""
	var face: String = FACES[body][appearance.get("face", 0)] if helm != "Helm_plate" else ""
	for style: String in HAIR_STYLES[0] + HAIR_STYLES[1] + FACES[0]:
		if style != "":
			_show(style, style == hair or style == face)
	# A cloak.
	var cloak := _item(Inventory.Slot.BACK)
	_show("Cloak", cloak.size() > 0 or outfit.has(BACK))
	_colors[BACK] = _armor_color(Inventory.Slot.BACK, outfit.get(BACK, CLOTH[0]))
	_apply_props()


## Weapons and shield in hand, or the ranged weapon while shooting.
func _apply_props() -> void:
	var main := _item(Inventory.Slot.MAIN_HAND)
	var off := _item(Inventory.Slot.OFF_HAND)
	var main_prop := ""
	if main.size() > 0 and int(main.get("class", 0)) == 2:
		main_prop = "Main_" + MAIN_PROPS.get(int(main.subclass), "")
	var off_prop := ""
	if off.size() > 0:
		if int(off.get("class", 0)) == 2:
			off_prop = "Off_" + OFF_PROPS.get(int(off.subclass), "sword")
		elif int(off.get("subclass", 0)) == Inventory.ARMOR_SUBCLASS_SHIELD:
			off_prop = "Shield_kite" if _pick(off, 2) == 1 else "Shield_round"
		else:
			off_prop = "Off_orb"
	if not creature_gear.is_empty():
		main_prop = "Main_" + str(creature_gear.get("main", "")) if creature_gear.get("main", "") != "" else ""
		off_prop = str(creature_gear.get("off", ""))
	var ranged := _item(Inventory.Slot.RANGED)
	if _drawn and ranged.size() > 0:
		main_prop = RANGED_PROPS.get(int(ranged.subclass), "")
		off_prop = ""
		_colors[RANGED] = _handle_color(ranged).lightened(0.15)
		_colors[RANGED_TRIM] = Color(0.3, 0.3, 0.33)
		if main_prop == "Main_wand":
			main = ranged
	for part: String in _parts:
		if part.begins_with("Main_") or part.begins_with("Ranged_"):
			_show(part, part == main_prop)
		elif part.begins_with("Off_") or part.begins_with("Shield_"):
			_show(part, part == off_prop)
	if main.size() > 0:
		_colors[BLADE] = _blade_color(main)
		_colors[HANDLE] = _handle_color(main)
		_colors[TRIM] = TRIM_COLOR if int(main.get("Quality", 1)) >= 2 else Color(0.42, 0.42, 0.44)
	if off.size() > 0:
		if off_prop.begins_with("Shield"):
			_colors[SHIELD] = _armor_color(Inventory.Slot.OFF_HAND, WOOD)
			_colors[SHIELD_TRIM] = TRIM_COLOR if int(off.get("Quality", 1)) >= 3 else Color(0.5, 0.5, 0.53)
		else:
			_colors[SHIELD_TRIM] = _blade_color(off)
			_colors[SHIELD] = TRIM_COLOR if int(off.get("Quality", 1)) >= 2 else Color(0.42, 0.42, 0.44)
			if main.size() == 0:
				_colors[HANDLE] = _handle_color(off)
	if not creature_gear.is_empty():
		_colors[BLADE] = STEEL.darkened(0.15)
		_colors[HANDLE] = WOOD
		_colors[SHIELD] = WOOD
		_colors[SHIELD_TRIM] = STEEL.darkened(0.15)
	_material.set_shader_parameter("slot_colors", PackedColorArray(_colors.map(func(c: Color) -> Color: return c.srgb_to_linear())))


## Clothes for an NPC by its trade (a trainer list: "paladin" in plate,
## "warrior" in mail, "priest" in robes), else plain cloth, picked by seed.
static func outfit_for(trade: String, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var body: Color = CLOTH[rng.randi_range(0, CLOTH.size() - 1)]
	var legs: Color = LEATHER[rng.randi_range(0, LEATHER.size() - 1)]
	match trade:
		"paladin":
			body = PLATE[rng.randi_range(0, PLATE.size() - 1)]
			legs = body.darkened(0.15)
		"warrior", "weapons":
			body = MAIL[rng.randi_range(0, MAIL.size() - 1)]
		"priest":
			body = [Color(0.88, 0.86, 0.8), Color(0.75, 0.65, 0.4), Color(0.55, 0.15, 0.15)][rng.randi_range(0, 2)]
			legs = body
		"spellsword":
			body = Color(0.25, 0.3, 0.55)
	var boots: Color = LEATHER[rng.randi_range(0, LEATHER.size() - 1)].darkened(0.2)
	return { CHEST: body, LEGS: legs, FEET: boots, HANDS: boots, WAIST: boots.darkened(0.2) }


func _item(slot: int) -> Dictionary:
	var stack = _equipment.get(slot)
	if not stack is Dictionary or stack.is_empty():
		return {}
	return ItemDB.get_item(int(stack.id))


## A stable choice of n for an item.
static func _pick(item: Dictionary, n: int) -> int:
	return absi(hash(int(item.get("entry", 0)) * 7919)) % n


func _armor_color(slot: int, bare: Color) -> Color:
	var item := _item(slot)
	if item.is_empty():
		return bare
	var color := Color()
	var named := _name_color(item)
	if named.a > 0.0:
		color = named
	else:
		var palette: Array = CLOTH
		match int(item.get("subclass", 0)):
			2:
				palette = LEATHER
			3:
				palette = MAIL
			4:
				palette = PLATE
			6:
				palette = [WOOD, Color(0.55, 0.15, 0.12), Color(0.2, 0.28, 0.5), Color(0.5, 0.5, 0.52)]
		color = palette[_pick(item, palette.size())]
	return _by_quality(color, int(item.get("Quality", 1)))


func _name_color(item: Dictionary) -> Color:
	for word in str(item.get("name", "")).to_lower().replace("'", " ").split(" "):
		if NAME_COLORS.has(word):
			return NAME_COLORS[word]
	return Color(0, 0, 0, 0)


static func _by_quality(color: Color, quality: int) -> Color:
	if quality == 0:
		return color.lerp(Color(0.52, 0.5, 0.46), 0.35)
	if quality >= 3:
		return color.lightened(0.1)
	return color


func _blade_color(item: Dictionary) -> Color:
	var subclass := int(item.get("subclass", 0))
	if subclass in [10, 19, 20]:
		# Staves and wands: a gem or a carved head.
		var gems := [Color(0.3, 0.6, 0.9), Color(0.8, 0.3, 0.2), Color(0.5, 0.85, 0.4), Color(0.75, 0.5, 0.9), WOOD.lightened(0.2)]
		return gems[_pick(item, gems.size())]
	var named := _name_color(item)
	if named.a > 0.0 and int(item.get("Quality", 1)) >= 2:
		return STEEL.lerp(named, 0.4)
	return _by_quality(STEEL, int(item.get("Quality", 1)))


func _handle_color(item: Dictionary) -> Color:
	return [WOOD, Color(0.3, 0.2, 0.12), Color(0.2, 0.16, 0.14)][_pick(item, 3)]


## A tint over the whole model: the corpse's grey, or none.
func set_corpse(on: bool) -> void:
	_material.set_shader_parameter("tint", Color(0.3, 0.28, 0.28, 0.7) if on else Color(0, 0, 0, 0))


func set_flash(on: bool) -> void:
	_material.set_shader_parameter("flash", 1.0 if on else 0.0)

# ---------------------------------------------------------------- animation

## Drives the animations from a player unit (the player or a playerbot).
func attach(unit: PlayerUnit) -> void:
	_unit = unit
	_profile = unit.profile
	_caster = unit.get_node_or_null("SpellCaster")
	_follow(unit, unit.combatant)
	if _caster:
		_caster.spell_finished.connect(_on_spell)


## Drives the animations from a creature (Human brigands and the like).
func attach_creature(creature: CharacterBody3D, c: Combatant) -> void:
	_follow(creature, c)


func _follow(body: CharacterBody3D, c: Combatant) -> void:
	_body = body
	_combatant = c
	c.shot.connect(_on_shot)
	c.swung.connect(func(_target: Combatant) -> void: _attack(false))
	c.off_hand_swung.connect(func(_target: Combatant) -> void: _attack(true))
	c.took_damage.connect(func(_amount: int, _source: Combatant, _crit: bool) -> void: _upper("hit", true))
	c.avoided.connect(_on_avoided)
	c.blocked_attack.connect(func(_attacker: Combatant) -> void: _upper("block"))
	c.died.connect(_on_died)


## Stops or restarts animating (far units hold their pose).
func set_animating(on: bool) -> void:
	if _tree:
		_tree.active = on
	set_process(on)


func _process(delta: float) -> void:
	if _body:
		_update_unit(delta)
	_advance(delta)


## Plays the animations on: every frame close to the camera, and less often
## further off or out of view (each step covering the time since the last),
## so a crowd costs little. The player's own model always runs every frame.
func _advance(delta: float) -> void:
	_anim_time += delta
	var interval := 0.0
	var camera := get_viewport().get_camera_3d()
	if camera and not _unit is Player:
		var at := global_position
		var distance := camera.global_position.distance_to(at)
		if not camera.is_position_in_frustum(at + Vector3.UP) and distance > 3.0:
			interval = OFF_SCREEN_STEP
		else:
			for band: Vector2 in ANIM_STEPS:
				if distance > band.x:
					interval = band.y
	if _anim_time >= interval:
		_tree.advance(_anim_time)
		_anim_time = 0.0


func _update_unit(delta: float) -> void:
	_gear_check -= delta
	if _gear_check <= 0.0 and _profile:
		_gear_check = GEAR_CHECK
		var key := hash(_profile.equipment.values().map(func(s: Dictionary) -> int: return int(s.get("id", 0))))
		if key != _gear_key:
			_gear_key = key
			show_equipment(_profile.equipment)
	# The ranged weapon is out while shooting.
	var drawn := _combatant.shoot_target != null
	if drawn != _drawn:
		_drawn = drawn
		_apply_props()
		_material.set_shader_parameter("slot_colors", PackedColorArray(_colors.map(func(c: Color) -> Color: return c.srgb_to_linear())))
	_update_loco(delta)


func _update_loco(delta: float) -> void:
	var c := _combatant
	if not c.is_alive():
		_set_loco("dead")
		return
	_dead = false
	var velocity := _body.velocity
	var local := global_transform.basis.orthonormalized().inverse() * velocity
	var forward := -local.z
	var side := local.x
	var speed := Vector2(velocity.x, velocity.z).length()
	var on_floor := _body.is_on_floor()
	_airborne = 0.0 if on_floor else _airborne + delta
	var sitting := _unit != null and _unit.sitting
	if sitting != _was_sitting:
		_was_sitting = sitting
		_full("sit_down" if sitting else "stand_up")
	# A creature's spell going off.
	if not _unit:
		if _was_casting and not c.is_casting and c.is_alive():
			_upper("cast_release")
		_was_casting = c.is_casting
	if speed > 0.3 or not on_floor:
		_dancing = false
	var scale := 1.0
	var state := "idle"
	if c.is_stunned():
		state = "stunned"
	elif _airborne > 0.3:
		state = "fall"
	elif sitting:
		state = "sit"
	elif speed > 0.3:
		if forward >= absf(side) * 0.7:
			state = "walk" if speed < 4.0 else "run"
			scale = speed / (WALK_SPEED if speed < 4.0 else RUN_SPEED)
		elif forward < 0.0 and -forward >= absf(side) * 0.7:
			state = "backpedal"
			scale = speed / 3.2
		else:
			state = "strafe_left" if side < 0.0 else "strafe_right"
			scale = speed / RUN_SPEED
	elif _caster and not _caster.casting.is_empty():
		state = "channel" if _caster.channeling else "cast"
	elif not _unit and c.is_casting:
		state = "cast"
	elif _dancing:
		state = "dance"
	elif _drawn:
		var shots := str(RANGED_SHOTS.get(int(_item(Inventory.Slot.RANGED).get("subclass", 0)), ""))
		state = "aim_bow" if shots == "shoot_bow" else "aim_gun" if shots == "shoot_gun" else "ready"
	elif c.is_in_combat() or c.attack_target:
		state = "ready"
	_tree.set("parameters/speed/scale", clampf(scale, 0.3, 2.5))
	_set_loco(state)


func _set_loco(state: String) -> void:
	if state == _loco:
		return
	# Leaving the ground with a jump, and landing.
	if state == "fall" and _loco != "fall" and _body and _body.velocity.y > 0.0:
		_full("jump")
	if _loco == "fall" and state != "fall":
		_full("land")
	_loco = state
	_tree.set("parameters/loco/transition_request", state)


func _upper(anim: String, only_if_free := false) -> void:
	if only_if_free and _tree.get("parameters/upper/active"):
		return
	if _loco in ["dead", "sit", "stunned"]:
		return
	_tree.set("parameters/upper_pick/transition_request", anim)
	_tree.set("parameters/upper/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _full(anim: String) -> void:
	_tree.set("parameters/full_pick/transition_request", anim)
	_tree.set("parameters/full/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _attack(off_hand: bool) -> void:
	if off_hand:
		_upper("attack_off")
		return
	var main := _item(Inventory.Slot.MAIN_HAND)
	if not creature_gear.is_empty():
		_swing += 1
		_upper("punch" if creature_gear.get("main", "") == "" else "attack_1h" if _swing % 2 == 0 else "attack_1h_b")
	elif main.is_empty():
		_upper("punch")
	elif int(main.get("InventoryType", 0)) == Inventory.INVTYPE_TWO_HAND:
		_upper("attack_2h")
	else:
		_swing += 1
		_upper("attack_1h" if _swing % 2 == 0 else "attack_1h_b")


## A shot with the ranged weapon.
func _on_shot(_target: Combatant) -> void:
	var anim: String = RANGED_SHOTS.get(int(_item(Inventory.Slot.RANGED).get("subclass", 0)), "shoot_wand")
	_upper(anim)


func _on_avoided(text: String, _source: Combatant) -> void:
	match text.to_lower():
		"parry":
			_upper("parry")
		"block":
			_upper("block")
		"dodge":
			_upper("dodge")


func _on_spell(spell: Dictionary) -> void:
	# Melee abilities swing the weapon; other spells are thrown from the hands.
	if int(spell.get("DmgClass", 0)) == 2:
		_attack(false)
	elif not _caster.channeling:
		_upper("cast_release")


func _on_died() -> void:
	_full("death")
	_set_loco("dead")


## Shows the unit as already dead (a corpse restored from a save).
func show_dead() -> void:
	_set_loco("dead")


## Plays an emote ("wave", "dance"...) if there's an animation for it.
func emote(command: String) -> void:
	var anim: String = EMOTES.get(command, "")
	if anim == "dance":
		_dancing = true
	elif anim != "":
		_full(anim)
