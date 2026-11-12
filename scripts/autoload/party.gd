extends Node
## The player's party of playerbots, up to five members with the player, as
## in classic. Members are saved by name with the character (GameState.party)
## and come back beside the player when the world loads. Kill rewards follow
## Group::RewardGroupAtKill in CMaNGOS: members alive and within 74 yards
## share the XP by level, with a bonus for three or more, and the player's
## group splits money when looting (HandleLootMoneyOpcode).

signal changed
## Party lines for the HUD: "Aldric joins the party."
signal message(text: String)
## A bot accepted an invitation (it greets the party).
signal member_joined(bot: Bot)

const MAX_SIZE := 5
## CONFIG_FLOAT_GROUP_XP_DISTANCE: members further away get no share.
const REWARD_DISTANCE := 74.0
## "Near My Level" invitations: within this many levels.
const NEAR_LEVELS := 5

## The bots in the party, in the order they joined.
var members: Array[Bot] = []


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func is_member(bot: Bot) -> bool:
	return bot in members


## Whether a unit is the player or one of the party's bots.
func has_unit(unit: Combatant) -> bool:
	if unit == null:
		return false
	var player := _player()
	if player and unit == player.combatant:
		return true
	return members.any(func(bot: Bot) -> bool: return bot.combatant == unit)


## The player first, then the members.
func units() -> Array[PlayerUnit]:
	var list: Array[PlayerUnit] = []
	var player := _player()
	if player:
		list.append(player)
	list.append_array(members)
	return list


## Asks a bot to join. Bots answer straight away, by the Playerbots options.
func invite(bot: Bot) -> void:
	if bot == null or not is_instance_valid(bot):
		return
	if is_member(bot):
		message.emit("%s is already in your group." % bot.profile.char_name)
		return
	if members.size() + 1 >= MAX_SIZE:
		message.emit("Your party is full.")
		return
	message.emit("You have invited %s to join your group." % bot.profile.char_name)
	if not _accepts(bot):
		message.emit("%s declines your group invitation." % bot.profile.char_name)
		return
	members.append(bot)
	bot.joined_party()
	message.emit("%s joins the party." % bot.profile.char_name)
	member_joined.emit(bot)
	_save()
	changed.emit()


func _accepts(bot: Bot) -> bool:
	match Settings.get_value("bot_accept_invites"):
		"Never":
			return false
		"Near My Level":
			return absi(bot.profile.level - GameState.level) <= NEAR_LEVELS
	return true


func remove(bot: Bot) -> void:
	if not is_member(bot):
		return
	members.erase(bot)
	if is_instance_valid(bot):
		bot.left_party()
		message.emit("%s leaves the party." % bot.profile.char_name)
	if members.is_empty():
		message.emit("Your group has been disbanded.")
	_save()
	changed.emit()


func disband() -> void:
	for bot in members.duplicate():
		remove(bot)


## Forgets members whose bots are gone (the world reloading) without saving,
## so they can be put back.
func clear_for_reload() -> void:
	members.clear()
	changed.emit()


## Puts back a saved member as the world loads.
func restore(bot: Bot) -> void:
	if not is_member(bot) and members.size() + 1 < MAX_SIZE:
		members.append(bot)
		bot.joined_party(false)
		changed.emit()


func _save() -> void:
	GameState.party.assign(members.map(func(bot: Bot) -> String: return bot.profile.char_name))


## Gives out the rewards for a kill to the tapping unit's group. Returns true
## when that's the player's group, which then gets the loot.
func reward_kill(enemy: Enemy, tapper: Combatant) -> bool:
	var player := _player()
	var group: Array[PlayerUnit] = []
	var players_group := tapper == null or has_unit(tapper)
	if players_group:
		group = units()
	elif tapper.body is Bot:
		group.append(tapper.body)
	# Group::GetDataForXPAtKill: alive members within reach, their level sum,
	# and the highest level among those for whom the kill isn't grey.
	var near: Array[PlayerUnit] = []
	var sum_level := 0
	var top_level := 0
	var top_not_grey := 0
	for unit in group:
		if unit.combatant.is_alive() and unit.global_position.distance_to(enemy.global_position) <= REWARD_DISTANCE:
			near.append(unit)
			sum_level += unit.profile.level
			top_level = maxi(top_level, unit.profile.level)
			if enemy.level > CombatRules.gray_level(unit.profile.level):
				top_not_grey = maxi(top_not_grey, unit.profile.level)
	if not near.is_empty() and top_not_grey > 0:
		var xp := CombatRules.kill_xp(top_not_grey, enemy.level, enemy.elite)
		var rate := group_rate(near.size())
		for unit in near:
			# RewardGroupAtKill_helper: members above the top non-grey level
			# get nothing; when a higher member made the kill grey, the rest
			# get half.
			if unit.profile.level > top_not_grey:
				continue
			var share := rate * unit.profile.level / sum_level
			var amount := int(xp * share) if top_level == top_not_grey else int(xp * share / 2.0) + 1
			_progression(unit).add_xp(amount)
			# A Ranger's pet earns the same (Pet::GivePetXP).
			if unit.pet and is_instance_valid(unit.pet):
				unit.pet.give_xp(amount)
	if player and player in near:
		QuestLog.on_kill(enemy.creature_entry)
	# A bot on its own counts the kill for its own quests.
	if not players_group and not near.is_empty() and near[0] is Bot:
		(near[0] as Bot).quests.on_kill(enemy.creature_entry)
		(near[0] as Bot).last_kill = enemy.creature_entry
		(near[0] as Bot).bag.loot(enemy)
	return players_group


## Quest XP the player earned goes to every bot in the party too, the same
## amount, wherever they are. Classic gave it only to the player.
func share_quest_xp(amount: int) -> void:
	if amount <= 0:
		return
	for bot in members:
		if is_instance_valid(bot):
			bot.progression.add_xp(amount)


## MaNGOS::XP::xp_in_group_rate: up to two share evenly, three get 116.6%
## between them, four 130%, five 140%.
static func group_rate(count: int) -> float:
	match count:
		0, 1, 2:
			return 1.0
		3:
			return 1.166
		4:
			return 1.3
	return 1.4


static func _progression(unit: PlayerUnit) -> Progression:
	return unit.get_node("Progression") as Progression


## The player's share of looted money: split evenly between the party members
## near the corpse. The copper that doesn't divide evenly goes to the player
## looting, so a few copper split five ways is never a share of nothing.
func money_share(amount: int, at: Vector3) -> int:
	var near := units().filter(func(unit: PlayerUnit) -> bool:
		return unit.global_position.distance_to(at) <= REWARD_DISTANCE
	)
	var count := maxi(near.size(), 1)
	return amount / count + amount % count
