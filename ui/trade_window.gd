class_name TradeWindow
extends Control
## Trading with another player (a playerbot), as in classic: six item slots
## and money on each side, and a Trade button. Your side takes items from
## your bags (right-click one, or drop it on a slot; right-click a slot to
## take it back) and money typed as "1g 2s 3c" or copper. Both sides accept,
## any change takes the acceptance back, and the trade happens when both
## have accepted. Soulbound items can't be traded, and the trade ends past
## 11 yards (TRADE_DISTANCE in CMaNGOS) or when either side is attacked.
##
## The bot's side starts with the item it was last trading about in chat
## (its ad, a quote, an agreed price), and your side with that item from your
## bags when it's the one buying. A panel to the right lists what it sells
## (from its BotBag) at its asking price: click one to have it put that in the
## trade, and click it in the trade to put it back. It buys what you offer at
## its own rate, puts in the difference when you offer more than you take,
## and accepts once your money covers the rest. Prices agreed in chat apply.

## A line for the chat ("Trade complete.") or an error.
signal message(text: String, is_error: bool)
signal hovered(item: Dictionary)
signal closed

const SLOTS := 6
## The bot's goods panel, beside the trade window.
const WARES_WIDTH := 110.0
const WARES_GAP := 3.0
const RANGE := 11.11
const WIDTH := 200.0
const COLUMN := 94.0
const ROW := 13.0
const FONT_SIZE := 6
const BACK := Color(0.08, 0.08, 0.1, 0.94)
const SLOT_BACK := Color(0.16, 0.16, 0.2)
const ACCEPTED := Color(0.15, 0.4, 0.15, 0.5)
const GOLD := Color(1, 0.85, 0.4)
const GREY := Color(0.6, 0.6, 0.6)
const ERR_SOULBOUND := "You can't trade a soulbound item."
const ERR_EQUIPPED := "Take it off before trading it."
const ERR_TOO_FAR := "Trade target is too far away."
const ERR_BUSY := "That player is busy."
const ERR_ROOM := "You don't have room for those items."
const ERR_MONEY := "You don't have that much money."

var bot: Bot

var _player: Player
var _inventory: InventoryUI
var _ui_scale := 1.0
## Your side: { "ref", "id", "count" } or {} per slot.
var _mine: Array[Dictionary] = []
var _my_money := 0
## The bot's side: { "id", "count", "price" } or {} per slot.
var _theirs: Array[Dictionary] = []
var _their_money := 0
## What the bot wants from you in money, after what it takes off for your items.
var _wanted := 0
var _i_accept := false
var _they_accept := false
## Item ids you picked from its goods, in the order picked.
var _picked: Array[int] = []
## How many of a picked item go in, when fewer than it has (the number talked
## about in chat); otherwise all of them.
var _counts: Dictionary = {}
var _money_field: LineEdit
var _rebuild_queued := false


func setup(player: Player, inventory: InventoryUI, ui_scale: float) -> void:
	add_to_group("trade_window")
	_player = player
	_inventory = inventory
	_ui_scale = ui_scale
	visible = false
	_inventory.trade_requested.connect(add_from_bag)


func is_open() -> bool:
	return visible and bot != null


## The bot quoted new prices in chat: its side of the trade follows them.
func refresh_terms() -> void:
	if not is_open():
		return
	for slot in _theirs:
		if not slot.is_empty():
			slot.price = bot.bag.asking_price(int(slot.id), int(slot.count))
	_changed()


## Opens a trade with a bot, if it's near, alive and free. A bot that opened
## it itself (walking over) has already said hello.
func open(with_bot: Bot, greet := true) -> void:
	if with_bot == null or not is_instance_valid(with_bot):
		return
	if _player.global_position.distance_to(with_bot.global_position) > RANGE:
		message.emit(ERR_TOO_FAR, true)
		return
	if not with_bot.combatant.is_alive() or with_bot.combatant.is_in_combat() or not _player.combatant.is_alive():
		message.emit(ERR_BUSY, true)
		return
	if is_open():
		cancel()
	bot = with_bot
	bot.trading = true
	_mine.clear()
	_theirs.clear()
	for i in SLOTS:
		_mine.append({})
		_theirs.append({})
	_my_money = 0
	_i_accept = false
	_they_accept = false
	_picked.clear()
	_counts.clear()
	visible = true
	_inventory.trading = true
	_inventory.open_bags()
	_put_in_topic()
	_bot_offers()
	if greet:
		_greet()
	_build()


func cancel() -> void:
	if bot:
		message.emit("Trade cancelled.", false)
	_end()


func _end() -> void:
	if bot and is_instance_valid(bot):
		bot.trading = false
	bot = null
	visible = false
	_inventory.trading = false
	hovered.emit({})
	closed.emit()


func _process(_delta: float) -> void:
	if not is_open():
		return
	if not is_instance_valid(bot) or not bot.combatant.is_alive() or bot.combatant.is_in_combat() \
			or not _player.combatant.is_alive() or _player.combatant.is_in_combat():
		cancel()
	elif _player.global_position.distance_to(bot.global_position) > RANGE:
		message.emit(ERR_TOO_FAR, true)
		cancel()


# Your side.

## Puts a bag item up for trade (right-click in the bags).
func add_from_bag(ref: Dictionary) -> void:
	if not is_open():
		return
	if ref.get("kind") != "bag":
		message.emit(ERR_EQUIPPED, true)
		return
	var stack := Inventory.stack_at(ref)
	if stack.is_empty() or _mine.any(func(slot: Dictionary) -> bool: return slot.get("ref") == ref):
		return
	if stack.get("bound", false) or not BotBag.can_trade(int(stack.id)):
		message.emit(ERR_SOULBOUND, true)
		return
	var free := _mine.find({})
	if free < 0:
		return
	_mine[free] = { "ref": ref, "id": int(stack.id), "count": int(stack.count) }
	_changed()


func _take_back(slot: int) -> void:
	_mine[slot] = {}
	_changed()


func _set_money(text: String) -> void:
	_my_money = parse_money(text)
	_changed(false)


## "1g 2s 3c", "2s", or plain copper.
static func parse_money(text: String) -> int:
	text = text.to_lower().replace(" ", "")
	if text.is_valid_int():
		return maxi(int(text), 0)
	var total := 0
	var regex := RegEx.create_from_string("(\\d+)([gsc])")
	for found in regex.search_all(text):
		total += int(found.get_string(1)) * { "g": 10000, "s": 100, "c": 1 }[found.get_string(2)]
	return total


func accept() -> void:
	if _my_money > GameState.money:
		message.emit(ERR_MONEY, true)
		return
	_i_accept = true
	if _they_accept:
		_complete()
	else:
		_queue_rebuild()


## The item the trade was talked about for goes in: on the bot's side when
## it's selling, from your bags (as many as were talked about) when it's
## buying.
func _put_in_topic() -> void:
	var talk := BotChatter.trade_topic(bot)
	if talk.is_empty():
		return
	var id := int(talk.id)
	if not bool(talk.buying):
		if bot.bag.count_of(id) > 0:
			_picked.append(id)
			if int(talk.count) > 0:
				_counts[id] = int(talk.count)
		return
	var wanted := maxi(int(talk.count), 1)
	for b in GameState.containers.size():
		var container: Array = GameState.containers[b]
		for i in container.size():
			var stack: Dictionary = container[i]
			if wanted <= 0 or stack.is_empty() or int(stack.id) != id:
				continue
			var free := _mine.find({})
			if free < 0 or stack.get("bound", false) or not BotBag.can_trade(id):
				return
			_mine[free] = { "ref": Inventory.bag_ref(b, i), "id": id, "count": int(stack.count) }
			wanted -= int(stack.count)


# The bot's side.

## Puts the goods you picked on its side, up to six stacks, at its prices.
func _bot_offers() -> void:
	for i in SLOTS:
		_theirs[i] = {}
	var i := 0
	for id in _picked:
		var count := mini(bot.bag.count_of(id), int(_counts.get(id, 1 << 30)))
		if i >= SLOTS or count <= 0:
			continue
		_theirs[i] = { "id": id, "count": count, "price": bot.bag.asking_price(id, count) }
		i += 1
	_bot_thinks()


## Works out the money: what it asks for its items, less what yours are worth
## to it. Owing you, it puts in the difference (as much as it has); otherwise
## it wants that much from you, and accepts once you've put it in.
func _bot_thinks() -> void:
	var asking := 0
	for slot in _theirs:
		asking += int(slot.get("price", 0))
	var offered := 0
	for slot in _mine:
		if not slot.is_empty():
			offered += bot.bag.buying_price(int(slot.id), int(slot.count))
	_their_money = mini(maxi(offered - asking, 0), bot.bag.money)
	_wanted = maxi(asking - offered, 0)
	var something := _mine.any(func(slot: Dictionary) -> bool: return not slot.is_empty()) \
			or _theirs.any(func(slot: Dictionary) -> bool: return not slot.is_empty()) or _my_money > 0
	_they_accept = something and _my_money >= _wanted


func _greet() -> void:
	var goods := bot.bag.for_sale()
	var bot_name := bot.profile.char_name
	if not _picked.is_empty():
		Chat.add("whisper", "put the [%s] in, anything else from my list?" % ItemDB.get_item(_picked[0]).name, bot_name)
	elif _mine.any(func(slot: Dictionary) -> bool: return not slot.is_empty()):
		Chat.add("whisper", "got your [%s] in there, see what i'm paying" % ItemDB.get_item(int(_mine[_mine.find_custom(func(slot: Dictionary) -> bool: return not slot.is_empty())].id)).name, bot_name)
	elif goods.is_empty():
		Chat.add("whisper", "not much to sell, but i'll buy stuff", bot_name)
	else:
		Chat.add("whisper", "pick anything you want from my list", bot_name)


## Picks one of its goods from the panel, to go in the trade.
func _pick(id: int) -> void:
	if not is_open() or id in _picked or _picked.size() >= SLOTS:
		return
	_picked.append(id)
	_bot_offers()
	_i_accept = false
	_queue_rebuild()


## Puts an item of its back (clicked in the trade).
func _put_back(slot: int) -> void:
	if not is_open():
		return
	var stack := _theirs[slot]
	if stack.is_empty():
		return
	_picked.erase(int(stack.id))
	_counts.erase(int(stack.id))
	_bot_offers()
	_i_accept = false
	_queue_rebuild()


## Any change takes your acceptance back; the bot thinks again.
func _changed(rebuild := true) -> void:
	_i_accept = false
	_bot_thinks()
	if rebuild:
		_queue_rebuild()
	else:
		_update_status()


# Trading.

## Both accepted: items and money change hands, if everything's still there
## and fits.
func _complete() -> void:
	for slot in _mine:
		if not slot.is_empty():
			var stack := Inventory.stack_at(slot.ref)
			if stack.is_empty() or int(stack.id) != int(slot.id) or int(stack.count) != int(slot.count):
				message.emit("Your items changed. Trade cancelled.", true)
				_end()
				return
	if _my_money > GameState.money:
		message.emit(ERR_MONEY, true)
		_i_accept = false
		_queue_rebuild()
		return
	var incoming := []
	for slot in _theirs:
		if not slot.is_empty():
			incoming.append([int(slot.id), int(slot.count)])
	var freed := _mine.filter(func(slot: Dictionary) -> bool: return not slot.is_empty()).size()
	if Inventory.free_slots() + freed < incoming.size() and not Inventory.has_room_for_all(incoming):
		message.emit(ERR_ROOM, true)
		_i_accept = false
		_queue_rebuild()
		return
	for slot in _mine:
		if not slot.is_empty():
			var stack := Inventory.take_stack(slot.ref)
			bot.bag.add(int(stack.id), int(stack.count))
	for entry: Array in incoming:
		bot.bag.remove(int(entry[0]), int(entry[1]))
		Inventory.add_item(int(entry[0]), int(entry[1]))
		bot.bag.quotes.sell.erase(int(entry[0]))
	for slot in _mine:
		if not slot.is_empty():
			bot.bag.quotes.buy.erase(int(slot.id))
	GameState.money += _their_money - _my_money
	bot.bag.money += _my_money - _their_money
	Sfx.play("coins")
	message.emit("Trade complete.", false)
	Chat.add("whisper", ["thanks!", "ty, pleasure", "thanks, good luck out there", "ty"].pick_random(), bot.profile.char_name)
	_end()


# Drawing.

func _queue_rebuild() -> void:
	if visible and not _rebuild_queued:
		_rebuild_queued = true
		_build.call_deferred()


func _build() -> void:
	_rebuild_queued = false
	for child in get_children():
		child.queue_free()
	if not is_open():
		return
	var rows_bottom := 24.0 + SLOTS * (ROW + 1)
	size = Vector2(WIDTH, rows_bottom + 46) * _ui_scale
	UiStyle.panel(self, size / _ui_scale, _ui_scale)
	_build_wares()
	UiStyle.title(self, Vector2(5, 1.5), "Trade", _ui_scale)
	UiStyle.close_button(self, Vector2(WIDTH - 10, 2), _ui_scale, cancel)
	var left := 4.0
	var right := WIDTH - 4 - COLUMN
	_column(left, rows_bottom, _i_accept)
	_column(right, rows_bottom, _they_accept)
	_text(self, Vector2(left + 2, 13), GameState.char_name, Targeting.PLAYER_COLOR, FONT_SIZE)
	_text(self, Vector2(right + 2, 13), bot.profile.char_name, Targeting.PLAYER_COLOR, FONT_SIZE)
	for i in SLOTS:
		var y := 24.0 + i * (ROW + 1)
		_slot(Vector2(left, y), _mine[i], func(event: InputEvent) -> void: _on_my_slot(event, i))
		_slot(Vector2(right, y), _theirs[i], func(event: InputEvent) -> void: _on_their_slot(event, i))
	# Money: yours typed in, theirs shown.
	_text(self, Vector2(left + 2, rows_bottom + 2), "Money:", GOLD, FONT_SIZE)
	_money_field = LineEdit.new()
	_money_field.placeholder_text = "e.g. 1s 50c"
	_money_field.text = "" if _my_money == 0 else ItemDB.money_text(_my_money)
	_money_field.position = Vector2(left + 26, rows_bottom) * _ui_scale
	_money_field.size = Vector2(COLUMN - 26, 11) * _ui_scale
	_money_field.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	_money_field.text_changed.connect(_set_money)
	_money_field.focus_entered.connect(func() -> void: _player.typing = true)
	_money_field.focus_exited.connect(func() -> void: _player.typing = false)
	add_child(_money_field)
	_text(self, Vector2(right + 2, rows_bottom + 2), "Money: %s" % ItemDB.money_text(_their_money), GOLD, FONT_SIZE)
	_status = _text(self, Vector2(right + 2, rows_bottom + 14), "", GREY, FONT_SIZE)
	_update_status()
	_text(self, Vector2(left + 2, rows_bottom + 14), "You have %s" % ItemDB.money_text(GameState.money), GREY, FONT_SIZE)
	var trade := _button("Trade", Vector2(WIDTH - 90, rows_bottom + 30), accept)
	trade.disabled = _i_accept
	_button("Cancel", Vector2(WIDTH - 44, rows_bottom + 30), cancel)


var _status: Label


## What the bot is waiting on, or that it has accepted.
func _update_status() -> void:
	if _status == null or not is_instance_valid(_status):
		return
	if _they_accept:
		_status.text = "%s has accepted" % bot.profile.char_name
		_status.add_theme_color_override("font_color", Color(0.45, 0.9, 0.45))
	elif _wanted > 0:
		_status.text = "Wants %s" % ItemDB.money_text(_wanted)
		_status.add_theme_color_override("font_color", GOLD)
	else:
		_status.text = "Put something in to trade"
		_status.add_theme_color_override("font_color", GREY)


func _column(x: float, bottom: float, accepted: bool) -> void:
	if accepted:
		var shade := ColorRect.new()
		shade.color = ACCEPTED
		shade.position = Vector2(x, 12) * _ui_scale
		shade.size = Vector2(COLUMN, bottom - 12) * _ui_scale
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shade)


## A slot row: the item's name in its quality color, the count, and a price
## on the bot's side.
func _slot(at: Vector2, stack: Dictionary, on_input: Callable) -> void:
	var row := ColorRect.new()
	row.color = SLOT_BACK
	row.position = at * _ui_scale
	row.size = Vector2(COLUMN, ROW) * _ui_scale
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(on_input)
	add_child(row)
	if stack.is_empty():
		return
	var item := ItemDB.get_item(int(stack.id))
	var icon := Control.new()
	icon.position = Vector2(1, 1) * _ui_scale
	icon.size = Vector2.ONE * (ROW - 2) * _ui_scale
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	UiStyle.item_icon(icon, item, _ui_scale)
	var label := "%s%s" % [item.name, " x%d" % int(stack.count) if int(stack.count) > 1 else ""]
	_text(row, Vector2(ROW + 1, 2), label, ItemDB.quality_color(item), FONT_SIZE)
	if stack.has("price"):
		var price := _text(row, Vector2(0, 2), ItemDB.money_text(int(stack.price)), GOLD, FONT_SIZE)
		price.size.x = (COLUMN - 2) * _ui_scale
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.mouse_entered.connect(func() -> void: hovered.emit(item))
	row.mouse_exited.connect(func() -> void: hovered.emit({}))


## Your slot: drop the held item in, right-click to take one back.
func _on_my_slot(event: InputEvent, slot: int) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	if click.button_index == MOUSE_BUTTON_LEFT and not _inventory.held_ref().is_empty():
		var ref := _inventory.held_ref()
		_inventory.clear_held()
		add_from_bag.call_deferred(ref)
	elif click.button_index == MOUSE_BUTTON_RIGHT and not _mine[slot].is_empty():
		_take_back.call_deferred(slot)
	accept_event()


## The bot's slot: click to put that item back.
func _on_their_slot(event: InputEvent, slot: int) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_put_back.call_deferred(slot)
		accept_event()


## The panel beside the window: everything it sells, with the price each
## and for the stack. Click a row to have it put in the trade; picked rows
## show as in the trade.
func _build_wares() -> void:
	var goods := bot.bag.for_sale()
	var x := WIDTH + WARES_GAP
	var height := 16.0 + maxf(goods.size(), 1) * (ROW + 1) + 4
	var back := UiStyle.panel(self, Vector2(WARES_WIDTH, height), _ui_scale)
	back.position = Vector2(x, 0) * _ui_scale
	UiStyle.title(self, Vector2(x + 5, 2), "%s's goods" % bot.profile.char_name, _ui_scale, FONT_SIZE)
	if goods.is_empty():
		_text(self, Vector2(x + 4, 16), "Nothing for sale.", GREY, FONT_SIZE)
		return
	for i in goods.size():
		var stack: Dictionary = goods[i]
		var id := int(stack.id)
		var count := int(stack.count)
		var item := ItemDB.get_item(id)
		var picked := id in _picked
		var row := ColorRect.new()
		row.color = ACCEPTED if picked else SLOT_BACK
		row.position = Vector2(x + 3, 14 + i * (ROW + 1)) * _ui_scale
		row.size = Vector2(WARES_WIDTH - 6, ROW) * _ui_scale
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(row)
		_text(row, Vector2(2, 2), "%s%s" % [item.name, " x%d" % count if count > 1 else ""], ItemDB.quality_color(item), FONT_SIZE)
		var price := _text(row, Vector2(0, 2), "in trade" if picked else ItemDB.money_text(bot.bag.asking_price(id, 1)) + (" ea" if count > 1 else ""), GREY if picked else GOLD, FONT_SIZE)
		price.size.x = (WARES_WIDTH - 8) * _ui_scale
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.gui_input.connect(func(event: InputEvent) -> void:
			var click := event as InputEventMouseButton
			if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
				_pick.call_deferred(id)
				accept_event()
		)
		row.mouse_entered.connect(func() -> void: hovered.emit(item))
		row.mouse_exited.connect(func() -> void: hovered.emit({}))


func _button(text: String, at: Vector2, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at * _ui_scale
	button.size = Vector2(40, 12) * _ui_scale
	button.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(pressed)
	add_child(button)
	return button


func _text(parent: Node, at: Vector2, text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.position = at * _ui_scale
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", roundi(font_size * _ui_scale))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", maxi(roundi(_ui_scale), 1))
	label.add_theme_constant_override("shadow_offset_y", maxi(roundi(_ui_scale), 1))
	parent.add_child(label)
	return label
