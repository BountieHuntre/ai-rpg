class_name BotChatter
extends Node
## Gives the playerbots a voice in the chat, like the players of a classic
## server. Everything a bot says comes from what it's doing: the quest it's
## on and where that takes it, the place it's in (the zone's PLACES) and the
## creatures there, what just killed it, the quest it just handed in, what it
## has to sell from its kills. Now and then one talks in General, Trade,
## LocalDefense or LookingForGroup; bots say "ding" when they level, greet
## the party when they join, and answer the player in /say, party chat and
## whispers, telling where places, creatures and quest givers are. Party bots also take
## "follow" and "stay" from party chat, as playerbots do. How often comes from
## the "Bot Chat" option. Child of the BotManager.

## Seconds between lines in the channels at Normal; Quiet doubles them,
## Chatty halves them.
const AMBIENT_MIN := 25.0
const AMBIENT_MAX := 70.0
const PACE := { "Quiet": 2.0, "Normal": 1.0, "Chatty": 0.5 }
## Seconds a bot takes to "type" an answer.
const REPLY_MIN := 1.2
const REPLY_MAX := 3.5
## A party bot says it's out of mana at most this often.
const OOM_COOLDOWN := 60.0
## Seconds a bot keeps talking about something that just happened.
const RECENT := 120.0
## Yards around a bot that count as "here" for crowds of creatures and bots.
const NEARBY := 25.0

const GREETINGS := ["hey", "hi!", "hello there", "o/", "heya", "well met", "hey :)", "hi"]
const THANKS := ["np", "no problem", "anytime", "yw", "sure thing"]
## Answers to questions it can't place.
const SHRUGS := ["not sure, sorry", "no idea, i'm new too", "quest areas show on the minimap", "try the priory, someone there will know"]
const INVITE_YES := ["sure, send an invite", "ok, inv me", "yeah, invite me", "sure!"]
const INVITE_NO := ["sorry, soloing for now", "no thanks", "maybe later"]
const JOIN := ["hi all", "hey", "thanks for the invite", "o/ ready when you are", "hello!", "hey, let's go"]
const DING_SAY := ["ding!", "ding {level}", "finally {level}", "ding :)"]
const DING_PARTY := ["ding {level}!", "ding :)", "{level}!", "ding, finally"]
const OOM := ["oom", "low mana", "need a sec to drink", "oom, careful"]
const RAISED := ["ty for the rez", "thanks!", "thanks for the rez", "ty"]
const FOLLOW := ["following", "on my way", "ok", "coming"]
const STAY := ["staying here", "ok, waiting", "holding here", "ok"]
const LAUGH := ["haha", "lol", ":)", "hah"]
const EMOTE_BACK := {
	"wave": "waves at you.", "hello": "waves at you.", "bow": "bows.", "cheer": "cheers!",
	"dance": "dances with you.", "thank": "nods.", "bye": "waves goodbye.", "laugh": "laughs.",
}

var _manager: BotManager
var _next_line := 0.0
var _oom_said: Dictionary = {}


func setup(manager: BotManager) -> void:
	_manager = manager
	_next_line = _gap()
	Chat.player_spoke.connect(_on_player_spoke)
	Party.member_joined.connect(_on_joined)


## How chatty bots are: 0 for Off.
func _pace() -> float:
	return PACE.get(Settings.get_value("bot_chat"), 0.0)


func _gap() -> float:
	return randf_range(AMBIENT_MIN, AMBIENT_MAX) * _pace()


func _process(delta: float) -> void:
	if _pace() <= 0.0:
		return
	_next_line = minf(_next_line - delta, _gap())
	if _next_line <= 0.0:
		_next_line = _gap()
		_ambient()
	_check_mana()


## One bot says something about what it's doing, in a channel or (when the
## player is near) out loud.
func _ambient() -> void:
	var bots := _manager.bots().filter(func(bot: Bot) -> bool: return bot.combatant.is_alive() and not Party.is_member(bot))
	bots.shuffle()
	for bot: Bot in bots:
		var options := _things_to_say(bot)
		if not options.is_empty():
			var said: Array = options.pick_random()
			_say(bot, said[0], said[1], said[2])
			# An ad makes its item what a whispered price is about.
			if said.size() > 3:
				var topic: Array = said[3]
				_set_topic(bot, topic[0], false, topic[1])
				bot.set_meta("offered_to_come", true)
			return


## Everything true enough for this bot to say right now: [kind, channel, text]
## and, for a sales ad, [item id, count] of what it's selling. Kinds are
## "channel" (with its number) and "say".
func _things_to_say(bot: Bot) -> Array:
	var options := []
	var now := _now()
	var at := bot.global_position
	var place := _manager.place_at(at)
	var title := bot.quests.current_title()
	var quest := "[%s]" % title if not title.is_empty() else ""
	var level := bot.profile.level
	var fighting := bot.enemy_target()
	var fought := str(fighting.display_name) if fighting else ""
	# Its quest, and where the quest takes it.
	if not quest.is_empty():
		options.append(["channel", 4, "LFG %s" % quest])
		options.append(["channel", 4, "%s LFG %s" % [ClassicData.CLASS_NAMES[bot.profile.char_class], quest]])
		var wanted := bot.quests.wanted_creatures(_manager.spawn_entries())
		if not wanted.is_empty():
			var entry: int = wanted.pick_random()
			var creature := _creature_name(entry)
			var there := _manager.spawn_place(entry, at)
			if not there.is_empty() and there != place and fighting == null:
				options.append(["channel", 1, "heading to %s for %s" % [there, quest]])
				options.append(["channel", 4, "anyone at %s? doing %s" % [there, quest]])
			elif there == place:
				options.append(["channel", 1, "need more %s for %s" % [_plural(creature), quest]])
		var progress := bot.quests.progress(bot.quests.active.keys()[0])
		if progress >= 0.7 and progress < 1.0:
			options.append(["channel", 1, "almost done with %s" % quest])
		for item_id: int in bot.quests.items_needed():
			var item_name := str(ItemDB.get_item(item_id).name)
			options.append(["channel", 1, "anyone know what drops [%s]?" % item_name])
	elif bot.quests.done.is_empty():
		options.append(["channel", 1, "where do i find quests around here?"])
	# Where it is, and what's there.
	if not place.is_empty():
		var crowd := _creatures_near(at)
		if not crowd.is_empty():
			var most: int = crowd.keys().reduce(func(a: int, b: int) -> int: return a if crowd[a] >= crowd[b] else b)
			if crowd[most] >= 3:
				options.append(["channel", 1, "%s all over %s" % [_plural(_creature_name(most)), place]])
				if not Enemy.creature_data(most).is_empty() and _aggressive(most):
					options.append(["channel", 3, "careful at %s, lots of %s" % [place, _plural(_creature_name(most))]])
		var rivals := _bots_hunting_near(bot)
		if rivals > 0 and fighting:
			options.append(["channel", 1, "%s is so crowded, everyone's after the %s" % [place, _plural(fought)]])
		if place == "the bridge":
			options.append(["channel", 1, "just fell off the bridge lol"])
			options.append(["say", 0, "nice view from the bridge"])
	# How it's doing.
	if fighting and bot.combatant.health < bot.combatant.max_health * 0.4:
		options.append(["say", 0, "%s hits hard..." % fought.to_lower()])
	if not bot.last_death.is_empty() and now - float(bot.last_death.time) < RECENT:
		var killer := str(bot.last_death.killer)
		var where := str(bot.last_death.place)
		if not killer.is_empty():
			options.append(["channel", 1, "died to a %s%s, ugh" % [killer, " at " + where if not where.is_empty() else ""]])
			if not where.is_empty() and _aggressive_name(killer):
				options.append(["channel", 3, "watch out for the %s at %s" % [_plural(killer), where]])
	if not bot.last_quest_done.is_empty() and now - float(bot.last_quest_done.time) < RECENT:
		options.append(["channel", 1, "finally done with [%s]" % bot.last_quest_done.title])
	# Selling what's in its bag, at its price; trade it to buy.
	var goods := bot.bag.for_sale()
	if not goods.is_empty():
		var stack: Dictionary = goods.pick_random()
		var item_name := str(ItemDB.get_item(int(stack.id)).name)
		var count := int(stack.count)
		var price := ItemDB.money_text(bot.bag.asking_price(int(stack.id), 1))
		var topic := [int(stack.id), count]
		options.append(["channel", 2, "WTS [%s]%s %s%s" % [item_name, " x%d" % count if count > 1 else "", price, " each" if count > 1 else ""], topic])
		options.append(["channel", 2, "selling [%s], pst or open trade" % item_name, topic])
	# New players' questions.
	if level <= 2:
		options.append(["channel", 1, "first character, any tips?"])
	if level < 10 and randf() < 0.3:
		options.append(["channel", 1, "how long does it take to hit 10?"])
	if bot.profile.char_class != ClassicData.CharClass.PALADIN and randf() < 0.3:
		options.append(["channel", 1, "is there a %s trainer anywhere around here?" % ClassicData.CLASS_NAMES[bot.profile.char_class].to_lower()])
	return options


## A bot levelled: "ding" out loud on its own, in party chat in the party.
func on_level(level: int, bot: Bot) -> void:
	if _pace() <= 0.0 or not is_instance_valid(bot):
		return
	if Party.is_member(bot):
		_later(bot, "party", DING_PARTY)
	elif randf() < 0.6:
		_later(bot, "say", DING_SAY)


func on_revived(raised: bool, bot: Bot) -> void:
	if raised and Party.is_member(bot) and _pace() > 0.0:
		_later(bot, "party", RAISED)


func _on_joined(bot: Bot) -> void:
	if _pace() > 0.0:
		_later(bot, "party", JOIN)


## Party Templars and spellcasters short on mana in a fight say so.
func _check_mana() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for bot in Party.members:
		var c := bot.combatant
		if c.max_mana > 0 and c.is_alive() and c.is_in_combat() and c.mana < c.max_mana * 0.15:
			if now >= float(_oom_said.get(bot, -OOM_COOLDOWN)) + OOM_COOLDOWN:
				_oom_said[bot] = now
				_later(bot, "party", OOM)


# Answering the player.

func _on_player_spoke(kind: String, text: String, target: String) -> void:
	var lower := text.to_lower()
	match kind:
		"say", "yell":
			if _trade_call(text, lower):
				return
			for bot in _within(Chat.YELL_RANGE if kind == "yell" else Chat.SAY_RANGE).slice(0, 2):
				if randf() < 0.6:
					_answer(bot, "say", lower)
		"party":
			_party_order(lower)
			if not Party.members.is_empty() and randf() < 0.7:
				_answer(Party.members.pick_random(), "party", lower)
		"whisper":
			var bot := _manager.find_bot(target)
			if bot and not _trade_whisper(bot, text, lower):
				_whisper_back(bot, lower)
		"channel":
			if _trade_call(text, lower):
				return
			# Most questions in a channel get an answer from someone.
			if "?" in lower and randf() < 0.8:
				var bots := _manager.bots().filter(func(b: Bot) -> bool: return not Party.is_member(b) and b.combatant.is_alive())
				if not bots.is_empty():
					_answer(bots.pick_random(), "channel", lower, int(target))
		"emote":
			var bot := _manager.find_bot(target)
			if bot and EMOTE_BACK.has(text) and bot.global_position.distance_to(_player_position()) <= Chat.SAY_RANGE:
				var reply: String = EMOTE_BACK[text]
				get_tree().create_timer(randf_range(REPLY_MIN, REPLY_MAX)).timeout.connect(func() -> void:
					if is_instance_valid(bot):
						Chat.add("emote", reply, bot.profile.char_name)
				)


## Greetings, thanks, laughter and questions get an answer.
func _answer(bot: Bot, kind: String, lower: String, channel := 0) -> void:
	if _greeting(lower):
		_later(bot, kind, GREETINGS, channel)
	elif _has_any(lower, ["thanks", "thank you", "ty", "thx"]):
		_later(bot, kind, THANKS, channel)
	elif _has_any(lower, ["lol", "haha", "lmao"]):
		_later(bot, kind, LAUGH, channel)
	elif "?" in lower:
		_later_text(bot, kind, _reply_to_question(bot, lower), channel)


## A question about a place, a creature, a quest or a trainer gets a real
## answer from the zone's layout; anything else a shrug.
func _reply_to_question(bot: Bot, lower: String) -> String:
	# "trainer", "trains", "train", "training".
	if "train" in lower:
		return _trainer_answer(lower)
	for place_name: String in _manager.place_names():
		var key := place_name.trim_prefix("the ")
		if key in lower or key.split(" ")[-1] in lower.split(" "):
			if place_name == "the priory":
				return "the priory's in the middle of the vale, follow any road"
			return "%s is %s of the priory" % [place_name, _manager.direction_of(place_name)]
	for entry: int in _manager.spawn_entries():
		var creature := _creature_name(entry)
		for word in creature.to_lower().split(" "):
			if word.length() > 3 and word in lower:
				var there := _manager.spawn_place(entry, bot.global_position)
				return "%s are around %s" % [_plural(creature).to_lower(), there] if not there.is_empty() else "seen %s around, not sure where" % _plural(creature).to_lower()
	for id: int in QuestDB.all_ids():
		var quest := QuestDB.get_quest(id)
		var title := str(quest.title).to_lower()
		if title in lower or _shares_words(title, lower):
			var giver := _npc_name(str(quest.get("giver", "")))
			return "%s at the priory gives [%s]" % [giver, quest.title] if not giver.is_empty() else "not sure who gives that"
	return SHRUGS.pick_random()


## Which class's trainer was asked about, and whether there is one: the NPCs
## titled "<Class> Trainer" are the only trainers there are.
func _trainer_answer(lower: String) -> String:
	var trainers := {}
	for node in get_tree().get_nodes_in_group("npcs"):
		var title := str(node.subname)
		if title.ends_with(" Trainer"):
			trainers[title.trim_suffix(" Trainer").to_lower()] = node
	var asked := ""
	for class_title: String in ClassicData.CLASS_NAMES.values():
		if class_title.to_lower() in lower:
			asked = class_title
	if not asked.is_empty() and not trainers.has(asked.to_lower()):
		if trainers.is_empty():
			return "haven't seen a %s trainer anywhere around here" % asked.to_lower()
		var known: String = trainers.keys()[0]
		return "no %s trainer around here that i've seen, only %s for %s" % [asked.to_lower(), trainers[known].npc_name, _class_plural(known)]
	var wanted: String = asked.to_lower() if not asked.is_empty() else (trainers.keys()[0] if trainers.size() == 1 else "")
	if wanted.is_empty():
		return "which class? i only know where the %s trainer is" % trainers.keys()[0] if not trainers.is_empty() else SHRUGS.pick_random()
	var npc: Node3D = trainers[wanted]
	var place := _manager.place_at(npc.global_position)
	return "%s trains %s%s" % [npc.npc_name, _class_plural(wanted), (", in " if place == "the priory" else ", at ") + place if not place.is_empty() else ""]


## "templars", "men-at-arms", "magi".
static func _class_plural(class_title: String) -> String:
	match class_title.to_lower():
		"man-at-arms":
			return "men-at-arms"
		"magus":
			return "magi"
	return class_title.to_lower() + "s"


func _whisper_back(bot: Bot, lower: String) -> void:
	if _has_any(lower, ["inv", "group", "party", "join"]):
		_later(bot, "whisper", INVITE_NO if Settings.get_value("bot_accept_invites") == "Never" or Party.is_member(bot) else INVITE_YES)
	elif _greeting(lower):
		_later(bot, "whisper", GREETINGS)
	elif _has_any(lower, ["thanks", "thank you", "ty", "thx"]):
		_later(bot, "whisper", THANKS)
	elif "?" in lower and not _has_any(lower, ["doing", "up", "lvl", "level"]):
		_later_text(bot, "whisper", _reply_to_question(bot, lower))
	else:
		_later_text(bot, "whisper", _what_im_doing(bot))


# Trade talk.

## Someone selling or wanting items in a channel or out loud: "WTS [Item]"
## brings whispered offers from a couple of bots with the money; "WTB [Item]"
## brings prices from bots that have it. Returns whether it was trade talk.
func _trade_call(text: String, lower: String) -> bool:
	var items := _linked_items(text)
	if items.is_empty():
		return false
	var selling := _has_any(lower, ["wts", "selling", "sell", "offers", "offer", "buying?"]) or "anyone buying" in lower or "how much" in lower
	var wanting := _has_any(lower, ["wtb", "buying", "need", "lf"]) and not selling
	if not selling and not wanting:
		return false
	var bots := _manager.bots().filter(func(b: Bot) -> bool: return b.combatant.is_alive() and not Party.is_member(b))
	bots.shuffle()
	for id: int in items:
		var count := _count_in(lower, id)
		if selling:
			var bidders := 0
			for bot: Bot in bots:
				if bidders >= 2 or BotBag._vendor(id) <= 0:
					break
				var price := bot.bag.buying_price(id, 1)
				if bot.bag.money < price * count or randf() < 0.3:
					continue
				bidders += 1
				bot.bag.quotes.buy[id] = price
				_set_topic(bot, id, true, count)
				bot.set_meta("offered_to_come", true)
				_later_text(bot, "whisper", "i'll give you %s for [%s]%s, want me to come to you?" % [ItemDB.money_text(price * count), ItemDB.get_item(id).name, " x%d" % count if count > 1 else ""])
		else:
			for bot: Bot in bots:
				var have := bot.bag.count_of(id)
				if have <= 0:
					continue
				var price := bot.bag.asking_price(id, 1)
				bot.bag.quotes.sell[id] = price
				_set_topic(bot, id, false, mini(count, have))
				_offer_to_come(bot, "got [%s] x%d, %s each" % [ItemDB.get_item(id).name, have, ItemDB.money_text(price)])
				break
	return true


## A whisper about trading: asking its price for an item ("how much for
## [Item]?", "what would you pay for [Item]?"), what it has ("what do you
## have?"), or naming a price to haggle ("3s?"). Quoted and agreed prices are
## remembered, and an open trade with it updates. Returns whether it was.
func _trade_whisper(bot: Bot, text: String, lower: String) -> bool:
	var items := _linked_items(text)
	var amount := _amount_in(lower)
	if items.is_empty() and _has_any(lower, ["have", "selling", "sell", "wares", "goods", "wts"]) and ("?" in lower or "what" in lower):
		var goods := bot.bag.for_sale()
		if goods.is_empty():
			_later_text(bot, "whisper", "nothing to sell right now, sorry")
		else:
			var parts := goods.slice(0, 4).map(func(stack: Dictionary) -> String:
				return "[%s]%s %s" % [ItemDB.get_item(int(stack.id)).name, " x%d" % int(stack.count) if int(stack.count) > 1 else "", ItemDB.money_text(bot.bag.asking_price(int(stack.id), 1))]
			)
			_offer_to_come(bot, "got " + ", ".join(parts))
		return true
	if not items.is_empty():
		var id: int = items[0]
		var count := _count_in(lower, id)
		var buying_from_me := bot.bag.count_of(id) <= 0 or _has_any(lower, ["pay", "give", "buy", "offer", "worth"]) and not _has_any(lower, ["your", "sell me"])
		_set_topic(bot, id, buying_from_me, count)
		if amount > 0:
			_haggle(bot, amount, lower)
		elif buying_from_me:
			var price := bot.bag.buying_price(id, 1)
			if price <= 0:
				_later_text(bot, "whisper", "not much use to me, sorry")
			else:
				bot.bag.quotes.buy[id] = price
				_offer_to_come(bot, "i'd pay %s for [%s]%s" % [ItemDB.money_text(price * count), ItemDB.get_item(id).name, " x%d" % count if count > 1 else ""])
		else:
			var price := bot.bag.asking_price(id, 1)
			bot.bag.quotes.sell[id] = price
			_offer_to_come(bot, "[%s] is %s each, got %d" % [ItemDB.get_item(id).name, ItemDB.money_text(price), bot.bag.count_of(id)])
		_refresh_trade(bot)
		return true
	if amount > 0 and _topic(bot).size() > 0:
		# "I'll buy" and "I'll sell" say who's buying, whatever was said before.
		var talk := _topic(bot)
		if _has_any(lower, ["buy", "take", "want"]) and bot.bag.count_of(int(talk.id)) > 0:
			talk.buying = false
		elif _has_any(lower, ["sell", "give"]) and not _has_any(lower, ["buy"]):
			talk.buying = true
		_haggle(bot, amount, lower)
		return true
	if amount > 0:
		_later_text(bot, "whisper", "for what? link the item")
		return true
	# "yes", "sure", "come over": a bot that offered to come, buying or
	# selling, comes to you.
	if bot.get_meta("offered_to_come", false) and _has_any(lower, YES):
		bot.set_meta("offered_to_come", false)
		if _near_player(bot):
			_later_text(bot, "whisper", "i'm right here, open trade")
		else:
			_later_text(bot, "whisper", ["omw", "on my way", "coming, one sec", "be right there"].pick_random())
			bot.come_to_player()
		return true
	return false


## Seconds a trade topic stays live for a whispered price without an item.
const TOPIC_TIME := 300.0


## What a whispered price is about: the item last talked about or advertised,
## who's buying, and how many.
func _set_topic(bot: Bot, id: int, buying: bool, count: int) -> void:
	bot.set_meta("haggling", { "id": id, "buying": buying, "count": count, "time": _now() })


## The live topic, or {} once it's gone stale.
func _topic(bot: Bot) -> Dictionary:
	var talk: Dictionary = bot.get_meta("haggling", {})
	if talk.is_empty() or _now() - float(talk.get("time", 0.0)) > TOPIC_TIME:
		return {}
	return talk


## Words that say yes to "want me to come to you?".
const YES := ["yes", "yeah", "yep", "sure", "ok", "okay", "k", "please", "pls", "come", "y", "deal"]


## Says a trade offer, asking whether to come over when it isn't near.
func _offer_to_come(bot: Bot, text: String) -> void:
	if _near_player(bot):
		_later_text(bot, "whisper", text + ", open trade if you want")
	else:
		bot.set_meta("offered_to_come", true)
		_later_text(bot, "whisper", text + ", want me to come to you?")


func _near_player(bot: Bot) -> bool:
	return bot.global_position.distance_to(_player_position()) <= TradeWindow.RANGE


## A bot that walked over to trade: it opens the trade, unless one's already
## going.
func on_arrived(bot: Bot) -> void:
	var window := get_tree().get_first_node_in_group("trade_window") as TradeWindow
	if window and not window.is_open():
		Chat.add("whisper", ["here, opened trade", "here you go", "hi, opened trade"].pick_random(), bot.profile.char_name)
		window.open(bot, false)
	else:
		Chat.add("whisper", "here, trade me when you're ready", bot.profile.char_name)


## A price named for the item being talked about: it takes anything up to its
## ceiling when buying (down to its floor when selling) and otherwise counters
## with its limit. Agreed prices go into the trade.
func _haggle(bot: Bot, amount: int, lower := "") -> void:
	var talk := _topic(bot)
	if talk.is_empty():
		return
	var id := int(talk.id)
	var count := maxi(int(talk.count), 1)
	var item_name := str(ItemDB.get_item(id).name)
	# A price is for the lot, unless it says "each", or only makes sense per
	# item: at least its limit for one, but under it for the lot.
	var limit: int = bot.bag.top_bid(id) if talk.buying else bot.bag.lowest_ask(id)
	var per_item: bool = count > 1 and (_has_any(lower, ["each", "ea", "per", "apiece"]) or (not talk.buying and amount >= limit and amount < limit * count))
	var each := amount if per_item else maxi(amount / count, 1)
	var total := each * count
	var what := "[%s]%s" % [item_name, " x%d" % count if count > 1 else ""]
	var price := "%s each (%s)" % [ItemDB.money_text(each), ItemDB.money_text(total)] if count > 1 else ItemDB.money_text(total)
	if talk.buying:
		if each <= limit and bot.bag.money >= total:
			bot.bag.quotes.buy[id] = each
			_agreed(bot, "deal, %s for %s" % [price, what])
		else:
			var best := mini(limit, bot.bag.money / count)
			bot.bag.quotes.buy[id] = best
			_later_text(bot, "whisper", "too rich for me, %s each is the most i can do" % ItemDB.money_text(best))
	else:
		if each >= limit:
			bot.bag.quotes.sell[id] = each
			_agreed(bot, "ok, %s for %s" % [price, what])
		else:
			bot.bag.quotes.sell[id] = limit
			_later_text(bot, "whisper", "can't go lower than %s each" % ItemDB.money_text(limit))
	_refresh_trade(bot)


## A price agreed: open trade if it's near, otherwise it comes over.
func _agreed(bot: Bot, text: String) -> void:
	if _near_player(bot):
		_later_text(bot, "whisper", text + ", open trade")
	else:
		_later_text(bot, "whisper", text + ", coming to you")
		bot.come_to_player()


## An open trade with this bot takes up its new prices once it has said them.
func _refresh_trade(bot: Bot) -> void:
	get_tree().create_timer(REPLY_MAX).timeout.connect(func() -> void:
		var window := get_tree().get_first_node_in_group("trade_window") as TradeWindow
		if window and window.is_open() and window.bot == bot:
			window.refresh_terms()
	)


## The item ids linked in a line, in order.
static func _linked_items(text: String) -> Array[int]:
	var ids: Array[int] = []
	for meta: String in Chat.link_text(text).links.values():
		if meta.begins_with("item:"):
			ids.append(int(meta.substr(5)))
	return ids


## How many: "x5" or "5x" in the line, or as many as the player carries, or 1.
static func _count_in(lower: String, id: int) -> int:
	var found := RegEx.create_from_string("(?:\\bx(\\d+)|(\\d+)x\\b)").search(lower)
	if found:
		return maxi(int(found.get_string(1) if found.get_string(1) != "" else found.get_string(2)), 1)
	return maxi(Inventory.count_item(id), 1)


## A money amount named in a line ("3s", "1g 50s", "75c"), or 0.
static func _amount_in(lower: String) -> int:
	var cleaned: String = Chat.link_text(lower).text
	var regex := RegEx.create_from_string("(\\d+)\\s*([gsc])\\b")
	var total := 0
	for found in regex.search_all(cleaned):
		total += int(found.get_string(1)) * { "g": 10000, "s": 100, "c": 1 }[found.get_string(2)]
	return total


## What it's up to, in a few words.
func _what_im_doing(bot: Bot) -> String:
	var place := _manager.place_at(bot.global_position)
	var title := bot.quests.current_title()
	var quest := "[%s]" % title if not title.is_empty() else ""
	var where := " at " + place if not place.is_empty() else ""
	if bot.enemy_target():
		return "fighting a %s%s, one sec" % [bot.enemy_target().display_name.to_lower(), where]
	if not quest.is_empty():
		return "doing %s%s" % [quest, where]
	return "just leveling%s, level %d now" % [where, bot.profile.level]


## Party chat orders, as playerbots take them: "follow" and "stay".
func _party_order(lower: String) -> void:
	var words := lower.split(" ", false)
	if "follow" in words:
		for bot in Party.members:
			bot.follow()
		if not Party.members.is_empty():
			_later(Party.members.pick_random(), "party", FOLLOW)
	elif "stay" in words or "wait" in words:
		for bot in Party.members:
			bot.stay()
		if not Party.members.is_empty():
			_later(Party.members.pick_random(), "party", STAY)


func _greeting(lower: String) -> bool:
	return _has_any(lower, ["hi", "hello", "hey", "yo", "greetings", "o/", "sup", "heya", "well met"])


static func _has_any(lower: String, words: Array) -> bool:
	var said := lower.replace("?", " ").replace("!", " ").replace(",", " ").replace(".", " ").split(" ", false)
	for word: String in words:
		if " " in word or "/" in word:
			if word in lower:
				return true
		elif word in said:
			return true
	return false


# Saying things.

## Says a line from a pool after a moment, as if typing it.
func _later(bot: Bot, kind: String, pool: Array, channel := 0) -> void:
	get_tree().create_timer(randf_range(REPLY_MIN, REPLY_MAX)).timeout.connect(func() -> void:
		if is_instance_valid(bot) and bot.combatant.is_alive():
			_line(bot, kind, pool, channel)
	)


func _line(bot: Bot, kind: String, pool: Array, channel := 0) -> void:
	_say(bot, kind, channel, _fill(str(pool.pick_random()), bot))


## Says a line, linking any items and quests named in brackets.
func _say(bot: Bot, kind: String, channel: int, text: String, _items := {}) -> void:
	var linked := Chat.link_text(text)
	text = linked.text
	var items: Dictionary = linked.links
	var bot_name := bot.profile.char_name
	match kind:
		"say":
			Chat.say(bot_name, text, bot.global_position, false, items)
		"party":
			if Party.is_member(bot):
				Chat.add("party", text, bot_name, 0, "", items)
		"whisper":
			Chat.add("whisper", text, bot_name, 0, "", items)
		"channel":
			Chat.add("channel", text, bot_name, channel, "", items)


## Says a given line after a moment, as if typing it.
func _later_text(bot: Bot, kind: String, text: String, channel := 0) -> void:
	get_tree().create_timer(randf_range(REPLY_MIN, REPLY_MAX)).timeout.connect(func() -> void:
		if is_instance_valid(bot) and bot.combatant.is_alive():
			_say(bot, kind, channel, text)
	)


## Fills a pool line's blanks: the bot's level.
func _fill(text: String, bot: Bot) -> String:
	return text.replace("{level}", str(bot.profile.level))


func _creature_name(entry: int) -> String:
	return str(Enemy.creature_data(entry).get("Name", "creature"))


static func _plural(creature: String) -> String:
	if creature.ends_with("f"):
		return creature.trim_suffix("f") + "ves"
	if creature.ends_with("s"):
		return creature
	return creature + "s"


## Living creatures around a point, counted by entry.
func _creatures_near(at: Vector3) -> Dictionary:
	var counts := {}
	for node in _manager.creatures():
		var enemy := node as Enemy
		if enemy.combatant.is_alive() and enemy.global_position.distance_to(at) <= NEARBY:
			counts[enemy.creature_entry] = counts.get(enemy.creature_entry, 0) + 1
	return counts


## Other bots nearby fighting the same kind of creature.
func _bots_hunting_near(bot: Bot) -> int:
	var target := bot.enemy_target()
	if target == null or not target.body is Enemy:
		return 0
	var entry := (target.body as Enemy).creature_entry
	var count := 0
	for other in _manager.bots():
		var theirs := other.enemy_target()
		if other != bot and theirs and theirs.body is Enemy and (theirs.body as Enemy).creature_entry == entry \
				and other.global_position.distance_to(bot.global_position) <= NEARBY:
			count += 1
	return count


func _aggressive(entry: int) -> bool:
	for node in _manager.creatures():
		var enemy := node as Enemy
		if enemy.creature_entry == entry:
			return enemy.is_aggressive()
	return false


func _aggressive_name(creature: String) -> bool:
	for entry: int in _manager.spawn_entries():
		if _creature_name(entry) == creature:
			return _aggressive(entry)
	return false


func _npc_name(npc_id: String) -> String:
	for node in get_tree().get_nodes_in_group("npcs"):
		if node.npc_id() == npc_id:
			return str(node.npc_name)
	return ""


## Whether two texts share two or more words of four letters or more.
static func _shares_words(a: String, b: String) -> bool:
	var shared := 0
	var words := b.split(" ", false)
	for word in a.split(" ", false):
		if word.length() >= 4 and word in words:
			shared += 1
	return shared >= 2


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _within(reach: float) -> Array[Bot]:
	var at := _player_position()
	var near: Array[Bot] = []
	for bot in _manager.bots():
		if bot.combatant.is_alive() and bot.global_position.distance_to(at) <= reach:
			near.append(bot)
	near.shuffle()
	return near


func _player_position() -> Vector3:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	return player.global_position if player else Vector3.ZERO
