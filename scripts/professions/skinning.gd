class_name Skinning
extends RefCounted
## Skinning a corpse, as classic's SPELL_EFFECT_SKINNING (CMaNGOS Spell.cpp):
## a creature with skinning loot (its SkinningLootId), dead and looted, a
## Skinning Knife in the bags, and the skill its level needs (CheckCast:
## (level - 10) x 10 while the skill is under 100, else level x 5); a cast
## of the Skinning rank spell; then its skinning loot opens, and the skill may
## rise, counted against level < 10: 0, < 20: (level - 10) x 10, else
## level x 5 (EffectSkinning). A skinned corpse can't be skinned again, and
## is gone once emptied.

static var REACH := 5.0


## The skill a creature of `level` needs, for someone with `skill`
## (CMaNGOS CheckCast's SPELL_FAILED_LOW_CASTLEVEL).
static func needed(level: int, skill: int) -> int:
	return maxi((level - 10) * 10 if skill < 100 else level * 5, 0)


## The skill the skill-up is counted against (EffectSkinning).
static func skill_up_level(level: int) -> int:
	if level < 10:
		return 0
	if level < 20:
		return (level - 10) * 10
	return level * 5


## Why `unit` can't skin `enemy` now, or "".
static func problem(unit: PlayerUnit, enemy: Enemy) -> String:
	if not is_instance_valid(enemy) or not enemy.skinnable():
		return "That can't be skinned."
	var profile := unit.profile
	if not Professions.knows(profile, "skinning"):
		return "Requires Skinning"
	var skill := Professions.value(profile, "skinning")
	var need := needed(enemy.level, skill)
	if skill < need:
		return "Requires Skinning %d" % need
	if profile == GameState:
		for tool: Variant in ProfessionDB.profession("skinning").get("tools", []):
			if Inventory.count_item(int(tool)) == 0:
				return "Requires %s" % str(ItemDB.get_item(int(tool)).get("name", "a tool"))
	if unit.global_position.distance_to(enemy.global_position) > REACH:
		return "You are too far away."
	return ""


## Starts skinning: a cast, then `opened` is called with the corpse when its
## skinning loot is out. Returns a problem, or "".
static func start(unit: PlayerUnit, enemy: Enemy, opened: Callable) -> String:
	var why := problem(unit, enemy)
	if not why.is_empty():
		return why
	var spell := Gathering.gather_spell(unit.profile, "skinning")
	var caster: SpellCaster = unit.get_node("SpellCaster")
	return caster.cast_action(spell, func() -> void:
		if finish(unit, enemy):
			opened.call(enemy))


static func finish(unit: PlayerUnit, enemy: Enemy) -> bool:
	if not problem(unit, enemy).is_empty():
		return false
	var chance := Professions.gather_chance(Professions.pure_value(unit.profile, "skinning"), skill_up_level(enemy.level))
	if Professions.try_raise(unit.profile, "skinning", chance) and unit.profile == GameState:
		Chat.system("Your skill in Skinning has increased to %d." % Professions.value(unit.profile, "skinning"))
		Sfx.play("level_up")
	enemy.skin()
	return enemy.has_loot()
