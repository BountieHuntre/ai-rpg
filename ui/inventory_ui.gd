class_name InventoryUI
extends Control
## The bags window (B) and the character window (C) with equipment slots and
## stats. Classic controls: drag an item to another slot, or click to pick it
## up and click again to put it down or swap. Right-click equips or uses an
## item from the bags, unequips equipped items, and cancels a held item.
## Dropping a held item over the world, away from every window, asks
## "Do you want to destroy ...?" as classic does.
## Slot boxes are built once and redrawn in place. Freeing a slot while it
## handles a mouse press crashes Godot, so windows are only rebuilt (deferred)
## when bags are added or removed.
## Sizes are in HUD units (1/270 of the window height), times ui_scale.

signal message(text: String, is_error: bool)
## Shift-click on an item: link it in the chat.
signal link_requested(item_id: int)
## Right-click on a bag item while trading: put it up for trade.
signal trade_requested(ref: Dictionary)
## Right-click on a bag item while a party bot's bags are open: give it.
signal give_requested(ref: Dictionary)
## An item that starts a quest was used: the HUD offers its quest.
signal quest_item_used(item_id: int)

const SLOT := 16.0
const GAP := 2.0
const FONT_SIZE := 6
const BAG_COLUMNS := 4
const BACK := Color(0.08, 0.08, 0.1, 0.92)
const EMPTY_SLOT := Color(0.16, 0.16, 0.2)
const TITLE := Color(1, 0.85, 0.4)
const LEFT_SLOTS := [
	Inventory.Slot.HEAD, Inventory.Slot.NECK, Inventory.Slot.SHOULDER, Inventory.Slot.BACK,
	Inventory.Slot.CHEST, Inventory.Slot.SHIRT, Inventory.Slot.TABARD, Inventory.Slot.WRIST,
]
const RIGHT_SLOTS := [
	Inventory.Slot.HANDS, Inventory.Slot.WAIST, Inventory.Slot.LEGS, Inventory.Slot.FEET,
	Inventory.Slot.FINGER_1, Inventory.Slot.FINGER_2, Inventory.Slot.TRINKET_1, Inventory.Slot.TRINKET_2,
]
const WEAPON_SLOTS := [Inventory.Slot.MAIN_HAND, Inventory.Slot.OFF_HAND, Inventory.Slot.RANGED]

var _player: Player
var _ui_scale := 1.0
var _screen := Vector2.ZERO
var _tooltip: ItemTooltip
var _bags_window: Control
var _character_window: Control
var _stats_text: Label
## The character window's pages: its gear and stats, and Skills.
var _character_page: Control
var _skills_page: Control
var _skills_shown := false
var _money_text: Label
## One entry per slot box: { "box": ColorRect, "ref": inventory ref }.
var _views: Array[Dictionary] = []
## Container sizes the windows were built for. A change means a rebuild.
var _layout := ""
## Where the item on the cursor came from, or {} when nothing is held.
var _held: Dictionary = {}
var _held_icon: Control
## True while a vendor window is open: right-clicking bag items sells them.
var selling := false
## A trade window is open: right-clicked bag items go into the trade.
var trading := false
## A party bot's bags are open (BotBagWindow): right-clicked bag items go to it.
var giving := false
var _rebuild_queued := false
## Whether a window point is over the HUD (any window, bar or frame), set by
## the HUD. Releasing a dragged item anywhere else offers to destroy it.
var is_over_ui := func(_point: Vector2) -> bool: return false
var _destroy_prompt: Control
## While set, clicking an item calls it with the item's ref (begin_pick).
var picking := Callable()
var _pick_hint: Label


## Waits for the player to pick an item in the bags or character window for
## a spell (Disenchant, an enchant), as classic's cursor does: `picked` is
## called with its ref. The bags open, and a hint follows the cursor.
func begin_pick(hint: String, picked: Callable) -> void:
	end_pick()
	picking = picked
	open_bags()
	_pick_hint = _text(self, Vector2.ZERO, hint, Color(1, 0.82, 0.3), FONT_SIZE)
	_pick_hint.z_index = 3


func end_pick() -> void:
	picking = Callable()
	if _pick_hint and is_instance_valid(_pick_hint):
		_pick_hint.queue_free()
	_pick_hint = null


func setup(player: Player, ui_scale: float, screen: Vector2, tooltip: ItemTooltip, open: Dictionary) -> void:
	_player = player
	_ui_scale = ui_scale
	_screen = screen
	_tooltip = tooltip
	z_index = 1
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.inventory_changed.connect(_on_inventory_changed)
	Settings.changed.connect(func(key: String) -> void:
		if key == "bags_display":
			_rebuild())
	GameState.money_changed.connect(func() -> void: _money_text.text = ItemDB.money_text(GameState.money))
	GameState.professions_changed.connect(func() -> void:
		if _skills_page and is_instance_valid(_skills_page):
			_update_skills())
	_rebuild()
	_bags_window.visible = open.get("bags", false)
	_character_window.visible = open.get("character", false)


func open_bags() -> void:
	_bags_window.visible = true
	for bag: int in _bag_frames:
		(_bag_frames[bag] as Control).visible = _bag_shown.get(bag, true)


## Where the bags window is on screen, or an empty rect when it's closed.
func bags_rect() -> Rect2:
	if not _bags_window or not _bags_window.visible:
		return Rect2()
	# The Separate layout: every open frame together.
	if not _bag_frames.is_empty():
		var rect := Rect2()
		for bag: int in _bag_frames:
			var frame := _bag_frames[bag] as Control
			if frame.visible:
				rect = frame.get_global_rect() if rect.size == Vector2.ZERO else rect.merge(frame.get_global_rect())
		return rect
	return _bags_window.get_global_rect()


func open_state() -> Dictionary:
	return { "bags": _bags_window.visible, "character": _character_window.visible }


## Esc: drops the held item, or closes open windows. Returns whether it did anything.
func close_one() -> bool:
	if _destroy_prompt:
		_answer_destroy(false)
		return true
	if not _held.is_empty():
		_set_held({})
		return true
	if _bags_window.visible or _character_window.visible:
		_bags_window.visible = false
		_character_window.visible = false
		_tooltip.show_item({})
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if Settings.pressed(event, "bags"):
		_bags_window.visible = not _bags_window.visible
		# All of them, in the Separate layout.
		for bag: int in _bag_frames:
			_bag_shown[bag] = true
			(_bag_frames[bag] as Control).visible = true
		get_viewport().set_input_as_handled()
	elif Settings.pressed(event, "character_window"):
		_character_window.visible = not _character_window.visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _character_window.visible and _character_page.visible:
		_stats_text.text = _character_sheet()
	if _held_icon:
		_held_icon.position = get_viewport().get_mouse_position() + Vector2(4, 4) * _ui_scale
	if _pick_hint and is_instance_valid(_pick_hint):
		_pick_hint.position = get_viewport().get_mouse_position() + Vector2(8, 10) * _ui_scale


func _on_inventory_changed() -> void:
	if _current_layout() != _layout:
		_queue_rebuild()
	else:
		_refresh()


func _current_layout() -> String:
	return str(GameState.containers.map(func(container: Array) -> int: return container.size()))


func _queue_rebuild() -> void:
	if not _rebuild_queued:
		_rebuild_queued = true
		_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	var open := open_state() if _bags_window else {}
	for child in get_children():
		child.queue_free()
	_views.clear()
	_held_icon = null
	_destroy_prompt = null
	_build_character_window()
	_build_bags_window()
	_layout = _current_layout()
	if not open.is_empty():
		_bags_window.visible = open.bags
		_character_window.visible = open.character
	_set_held(_held if not _held.is_empty() and not Inventory.stack_at(_held).is_empty() else {})


## Redraws every slot and the money from the current inventory.
func _refresh() -> void:
	for view in _views:
		_draw_view(view)
	_money_text.text = ItemDB.money_text(GameState.money)


# Windows.

func _build_character_window() -> void:
	var width := SLOT * 2 + GAP * 4 + 118.0
	var rows := LEFT_SLOTS.size()
	var height := 14.0 + rows * (SLOT + GAP) + SLOT + GAP * 3
	_character_window = _panel(Vector2(4, 50), Vector2(width, height))
	UiStyle.title(_character_window, Vector2(5, 1.5), "Character (C)", _ui_scale)
	_character_page = Control.new()
	_character_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_character_window.add_child(_character_page)
	for i in rows:
		var y := 14.0 + i * (SLOT + GAP)
		_slot(_character_page, Vector2(GAP, y), Inventory.equip_ref(LEFT_SLOTS[i]))
		_slot(_character_page, Vector2(width - SLOT - GAP, y), Inventory.equip_ref(RIGHT_SLOTS[i]))
	var weapons_y := 14.0 + rows * (SLOT + GAP)
	var weapons_x := (width - 3 * SLOT - 2 * GAP) / 2.0
	for i in WEAPON_SLOTS.size():
		_slot(_character_page, Vector2(weapons_x + i * (SLOT + GAP), weapons_y), Inventory.equip_ref(WEAPON_SLOTS[i]))
	_stats_text = _text(_character_page, Vector2(SLOT + GAP * 3, 13), "", Color.WHITE, FONT_SIZE)
	_skills_page = Control.new()
	_skills_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skills_page.size = Vector2(width, height) * _ui_scale
	_character_window.add_child(_skills_page)
	_fill_skills()
	_build_character_tabs(width, height)
	_show_character_page(_skills_shown)
	_character_window.visible = false


## Classic's tabs under the character frame: Character and Skills.
func _build_character_tabs(width: float, height: float) -> void:
	var names := ["Character", "Skills"]
	for i in names.size():
		var index := i
		UiStyle.tab(_character_window, Vector2(6 + i * 44, height - 1), Vector2(42, 11), names[i], (i == 1) == _skills_shown, _ui_scale, func() -> void:
			_skills_shown = index == 1
			_rebuild())


func _show_character_page(skills: bool) -> void:
	_character_page.visible = not skills
	_skills_page.visible = skills


## The Skills page: each profession's skill as classic's skill bars (value
## over its rank's cap), its rank, and Unlearn (a second click confirms).
## A skill-up only moves its bar and numbers (_update_skills); the page is
## filled again only when a profession is learned or forgotten.
func _update_skills() -> void:
	if Professions.known(GameState) != _skills_shown_for:
		_fill_skills()
		return
	var width := _skills_page.size.x / _ui_scale
	for name: String in _skill_views:
		var view: Dictionary = _skill_views[name]
		var value := Professions.value(GameState, name)
		var most := Professions.max_value(GameState, name)
		var bonus := Professions.racial_bonus(GameState, name)
		(view.fill as ColorRect).size = Vector2((width - 52) * clampf(value / float(maxi(most, 1)), 0.0, 1.0), 7) * _ui_scale
		(view.numbers as Label).text = "%d/%d%s" % [value, most, " (+%d)" % bonus if bonus > 0 else ""]
		(view.rank as Label).text = Professions.rank_name(name, Professions.rank_of(GameState, name))

var _skill_views: Dictionary = {}
var _skills_shown_for: Array[String] = []


func _fill_skills() -> void:
	for child in _skills_page.get_children():
		child.queue_free()
	_skill_views.clear()
	_skills_shown_for = Professions.known(GameState)
	var width := _skills_page.size.x / _ui_scale
	_text(_skills_page, Vector2(6, 14), "Professions", Color(1, 0.82, 0.3), FONT_SIZE)
	var known := Professions.known(GameState)
	if known.is_empty():
		var none := _text(_skills_page, Vector2(6, 24), "You know no professions. Their trainers are in the towns past the starting lands.", Color(0.7, 0.7, 0.7), FONT_SIZE)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.size.x = (width - 12) * _ui_scale
		return
	var y := 24.0
	for name in known:
		var value := Professions.value(GameState, name)
		var most := Professions.max_value(GameState, name)
		var rank := Professions.rank_name(name, Professions.rank_of(GameState, name))
		_text(_skills_page, Vector2(6, y), Professions.title(name), Color.WHITE, FONT_SIZE)
		var rank_label := _text(_skills_page, Vector2(60, y), rank, Color(0.7, 0.7, 0.7), FONT_SIZE - 1)
		# The bar: a dark trough and a blue fill, the numbers over it.
		var trough := ColorRect.new()
		trough.color = Color(0.05, 0.05, 0.08)
		trough.position = Vector2(6, y + 9) * _ui_scale
		trough.size = Vector2(width - 52, 7) * _ui_scale
		trough.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_skills_page.add_child(trough)
		var fill := ColorRect.new()
		fill.color = Color(0.2, 0.35, 0.8)
		fill.size = Vector2((width - 52) * clampf(value / float(maxi(most, 1)), 0.0, 1.0), 7) * _ui_scale
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trough.add_child(fill)
		var bonus := Professions.racial_bonus(GameState, name)
		var numbers := _text(trough, Vector2(0, -0.5), "%d/%d%s" % [value, most, " (+%d)" % bonus if bonus > 0 else ""], Color.WHITE, FONT_SIZE - 1)
		numbers.size.x = (width - 52) * _ui_scale
		numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_skill_views[name] = { "fill": fill, "numbers": numbers, "rank": rank_label }
		var unlearn := Button.new()
		unlearn.text = "Unlearn"
		unlearn.add_theme_font_size_override("font_size", roundi((FONT_SIZE - 1) * _ui_scale))
		unlearn.position = Vector2(width - 42, y + 7) * _ui_scale
		unlearn.size = Vector2(36, 10) * _ui_scale
		var profession := name
		unlearn.pressed.connect(func() -> void:
			if not unlearn.has_meta("confirm"):
				unlearn.set_meta("confirm", true)
				unlearn.text = "Sure?"
				return
			Professions.unlearn(GameState, profession)
			GameState.inventory_changed.emit())
		_skills_page.add_child(unlearn)
		y += 22.0


func _build_bags_window() -> void:
	_bag_frames.clear()
	if str(Settings.get_value("bags_display")) == "Separate":
		_build_bag_frames()
	else:
		_build_combined_bags()


## How many columns a bag's slots are laid out in: 4, or 8 for a big bag.
static func _bag_columns(size: int) -> int:
	return BAG_COLUMNS if size <= 16 else BAG_COLUMNS * 2


## A bag's height of slots, in units.
static func _bag_rows_height(size: int) -> float:
	return ceili(size / float(_bag_columns(size))) * (SLOT + GAP)


## The tallest a column of bags may be: the screen above the action bars.
func _bags_max_height() -> float:
	return _screen.y - 40.0 - 24.0


## The right edge for bag windows: left of the right action bars, when shown.
func _bags_right() -> float:
	return _screen.x - 4.0 - SpellUI.right_bars_layout(_screen).width


## Lays out the bag slots of `container` (bag index `bag`) from `at`.
func _bag_slots(parent: Control, bag: int, at: Vector2) -> void:
	var container: Array = GameState.containers[bag]
	var columns := _bag_columns(container.size())
	for i in container.size():
		_slot(parent, at + Vector2((i % columns) * (SLOT + GAP), floori(i / float(columns)) * (SLOT + GAP)), Inventory.bag_ref(bag, i))


## Combined: the backpack and every bag in one window, as one grid: each bag's
## slots carry on where the last bag's end, wrapping, the grid as square as it
## can be (at least the bag bar's width), and wider only if it would be
## taller than the screen.
func _build_combined_bags() -> void:
	var header := 13.0 + SLOT + GAP + 4.0
	var footer := 12.0
	var refs: Array[Dictionary] = []
	for bag in GameState.containers.size():
		for i in GameState.containers[bag].size():
			refs.append(Inventory.bag_ref(bag, i))
	var columns := maxi(GameState.BAG_SLOTS, ceili(sqrt(float(refs.size()))))
	var limit := _bags_max_height()
	while header + footer + ceili(refs.size() / float(columns)) * (SLOT + GAP) > limit and columns < refs.size():
		columns += 1
	var rows := ceili(refs.size() / float(columns))
	var width := columns * (SLOT + GAP) + GAP
	var height := header + rows * (SLOT + GAP) + footer
	var at := Vector2(_bags_right() - width, _screen.y - height - 40)
	_bags_window = _panel(at, Vector2(width, height))
	UiStyle.title(_bags_window, Vector2(5, 1.5), "Bags (B)", _ui_scale)
	for slot in GameState.BAG_SLOTS:
		_slot(_bags_window, Vector2(GAP + slot * (SLOT + GAP), 13), Inventory.bag_slot_ref(slot))
	for i in refs.size():
		_slot(_bags_window, Vector2(GAP + (i % columns) * (SLOT + GAP), header + floori(i / float(columns)) * (SLOT + GAP)), refs[i])
	_money_text = _text(_bags_window, Vector2(4, header + rows * (SLOT + GAP)), ItemDB.money_text(GameState.money), Color(1, 0.85, 0.4), FONT_SIZE)
	_bags_window.visible = false


## Which bags' frames are open in the Separate layout, by bag index (all of
## them unless closed one by one).
var _bag_shown := {}
var _bag_frames := {}


## Separate: each bag its own frame, as classic's, titled with the bag's
## name; the backpack's holds the bag bar and the money. Frames stack up from
## the bottom right and wrap into further columns leftward.
func _build_bag_frames() -> void:
	_bag_frames.clear()
	_bags_window = Control.new()
	_bags_window.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bags_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bags_window)
	var right := _bags_right()
	var bottom := _screen.y - 40.0
	var column_width := 0.0
	for bag in GameState.containers.size():
		var size: int = GameState.containers[bag].size()
		if size == 0:
			continue
		var width := _bag_columns(size) * (SLOT + GAP) + GAP
		if bag == 0:
			width = maxf(width, BAG_COLUMNS * (SLOT + GAP) + GAP)
		var height := 14.0 + _bag_rows_height(size) + 2.0
		if bag == 0:
			height += SLOT + GAP + 4.0 + 12.0
		if bottom - height < 24.0 and column_width > 0.0:
			right -= column_width + 4.0
			bottom = _screen.y - 40.0
			column_width = 0.0
		var frame := UiStyle.panel(_bags_window, Vector2(width, height), _ui_scale, true)
		frame.position = Vector2(right - width, bottom - height) * _ui_scale
		var title := "Backpack" if bag == 0 else str(ItemDB.get_item(int(GameState.bags[bag - 1].get("id", 0))).get("name", "Bag"))
		UiStyle.title(frame, Vector2(5, 1.5), title, _ui_scale)
		var y := 14.0
		if bag == 0:
			for slot in GameState.BAG_SLOTS:
				_slot(frame, Vector2(GAP + slot * (SLOT + GAP), 13), Inventory.bag_slot_ref(slot))
			y = 13.0 + SLOT + GAP + 4.0
		_bag_slots(frame, bag, Vector2(GAP, y))
		if bag == 0:
			_money_text = _text(frame, Vector2(4, y + _bag_rows_height(size)), ItemDB.money_text(GameState.money), Color(1, 0.85, 0.4), FONT_SIZE)
		frame.visible = _bag_shown.get(bag, true)
		_bag_frames[bag] = frame
		bottom -= height + 4.0
		column_width = maxf(column_width, width)
	_bags_window.visible = false


## Right-clicking a bag slot in the Separate layout: that bag's frame opens or
## closes (opening the bags if they were closed).
func _toggle_bag_frame(slot: int) -> void:
	var bag := slot + 1
	if not _bag_frames.has(bag):
		return
	if not _bags_window.visible:
		_bags_window.visible = true
		for other: int in _bag_frames:
			_bag_shown[other] = other == bag or other == 0
	else:
		_bag_shown[bag] = not _bag_shown.get(bag, true)
	for other: int in _bag_frames:
		(_bag_frames[other] as Control).visible = _bag_shown.get(other, true)


func _character_sheet() -> String:
	var c := _player.combatant
	var s := _player.stats
	var lines := PackedStringArray()
	lines.append("Level %d %s %s" % [c.level, ClassicData.RACE_NAMES[s.race], ClassicData.CLASS_NAMES[s.char_class]])
	for i in ClassicData.STAT_NAMES.size():
		var bonus := int(s.gear_stats[i])
		lines.append("%s: %d%s" % [ClassicData.STAT_NAMES[i], s.stats[i], " (+%d)" % bonus if bonus > 0 else ""])
	lines.append("Health %d  %s %d" % [c.max_health, "Rage" if c.uses_rage() else "Mana", c.max_mana])
	lines.append("Armor %d (%.1f%%)" % [c.armor, CombatRules.armor_reduction(c.armor, c.level) * 100.0])
	lines.append("Attack Power %d" % c.attack_power)
	var bonus_damage := c.attack_power / 14.0 * c.swing_interval
	lines.append("Damage %d-%d  Speed %.2f" % [floori(c.min_damage + bonus_damage), floori(c.max_damage + bonus_damage), c.swing_interval])
	lines.append("Crit %.2f%%  Spell %.2f%%" % [c.melee_crit, c.spell_crit])
	lines.append("Dodge %.2f%%  Parry %.2f%%" % [c.dodge, c.parry])
	lines.append("Block %.2f%% (%d)" % [c.block, c.block_value])
	lines.append("Mana regen %.1f / 2s" % s.current_mana_per_tick())
	lines.append("Health regen %.1f / 2s" % (0.0 if c.is_in_combat() else s.health_per_tick))
	return "\n".join(lines)


# Slots, clicks and dragging.

func _slot(parent: Control, at: Vector2, ref: Dictionary) -> void:
	var box := ColorRect.new()
	box.position = at * _ui_scale
	box.size = Vector2.ONE * SLOT * _ui_scale
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(box)
	var view := { "box": box, "ref": ref }
	_views.append(view)
	_draw_view(view)
	box.mouse_entered.connect(func() -> void:
		var current := Inventory.stack_at(ref)
		var shown := {} if current.is_empty() else ItemDB.get_item(current.id)
		# Its enchant shows on the tooltip (Enchanting).
		if current.has("enchant"):
			shown = shown.merged({ "_enchant": int(current.enchant) })
		_tooltip.show_item(shown, current.get("bound", false), int(current.get("durability", -1)), ref.kind == "bag", int(current.get("count", 1)))
	)
	box.mouse_exited.connect(func() -> void: _tooltip.show_item({}))
	box.gui_input.connect(func(event: InputEvent) -> void: _on_slot_input(event, ref))


## Draws a slot's contents. Only the box's decorations are replaced, never the
## box itself, which may be handling input right now.
func _draw_view(view: Dictionary) -> void:
	var box: ColorRect = view.box
	var ref: Dictionary = view.ref
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var stack := Inventory.stack_at(ref)
	box.color = Color.TRANSPARENT
	UiStyle.frame_box(box, _ui_scale)
	if stack.is_empty():
		if ref.kind == "equip":
			_text(box, Vector2(1, 4), str(Inventory.SLOT_LABELS[ref.slot]).substr(0, 3), Color(0.45, 0.45, 0.5), 5)
		elif ref.kind == "bag_slot":
			_text(box, Vector2(1, 4), "Bag", Color(0.45, 0.45, 0.5), 5)
	else:
		_draw_item(box, ItemDB.get_item(stack.id), stack.count)
	box.modulate = Color(1, 1, 1, 0.35) if _held == ref else Color.WHITE


func _on_slot_input(event: InputEvent, ref: Dictionary) -> void:
	var button := event as InputEventMouseButton
	if button == null or _destroy_prompt:
		return
	var error := ""
	# Picking an item for a spell (Disenchant, an enchant): a left click picks
	# it, a right click gives up.
	if picking.is_valid() and button.pressed:
		if button.button_index == MOUSE_BUTTON_LEFT and not Inventory.stack_at(ref).is_empty():
			var pick := picking
			end_pick()
			pick.call(ref)
		elif button.button_index == MOUSE_BUTTON_RIGHT:
			end_pick()
		get_viewport().set_input_as_handled()
		return
	if button.button_index == MOUSE_BUTTON_LEFT and button.pressed and button.shift_pressed and _held.is_empty():
		var stack := Inventory.stack_at(ref)
		if not stack.is_empty():
			link_requested.emit(int(stack.id))
		return
	if button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
		if _held.is_empty():
			if not Inventory.stack_at(ref).is_empty():
				_set_held(ref)
				Sfx.play("loot")
			return
		var from := _held
		_set_held({})
		error = Inventory.move(from, ref)
	elif button.button_index == MOUSE_BUTTON_LEFT:
		# Godot sends the release to the slot that was pressed. A release over
		# a different slot finishes a drag; over the same slot the item stays
		# on the cursor for click-to-place.
		var target := _view_at(button.global_position)
		if not _held.is_empty() and target.is_empty() and not is_over_ui.call(button.global_position):
			drop_held_on_world()
			get_viewport().set_input_as_handled()
			return
		if _held.is_empty() or target.is_empty() or target.ref == _held:
			return
		var from := _held
		_set_held({})
		error = Inventory.move(from, target.ref)
	elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
		if not _held.is_empty():
			_set_held({})
			return
		match ref.kind:
			"bag":
				error = _right_click_bag_item(ref)
			"bag_slot":
				if str(Settings.get_value("bags_display")) == "Separate":
					_toggle_bag_frame(int(ref.index))
				return
			"equip":
				error = Inventory.unequip(ref.slot)
	else:
		return
	_tooltip.show_item({})
	if not error.is_empty():
		message.emit(error, true)
	get_viewport().set_input_as_handled()


## Puts the item up for trade, sells to an open vendor, uses consumables, or
## equips gear and bags.
func _right_click_bag_item(ref: Dictionary) -> String:
	if trading:
		trade_requested.emit(ref)
		return ""
	if giving:
		give_requested.emit(ref)
		return ""
	if selling:
		var sold := Inventory.sell(ref)
		if sold.is_empty():
			Sfx.play("sell")
		return sold
	var stack := Inventory.stack_at(ref)
	if not stack.is_empty() and QuestLog.quest_from_item(int(stack.id)) > 0:
		var error := QuestLog.item_quest_error(QuestLog.quest_from_item(int(stack.id)))
		if error.is_empty():
			quest_item_used.emit(int(stack.id))
		return error
	# A Formula teaches its recipe (Enchanting).
	if not stack.is_empty() and Enchanting.formula_recipe(int(stack.id)) != 0:
		return Enchanting.use_formula(ref)
	if not stack.is_empty() and int(ItemDB.get_item(stack.id).get("spellid_1", 0)) > 0:
		return _player.spells.use_item(ref)
	return Inventory.use_from_bag(ref)


## Asks to destroy the held item, for a drop or click over the world. Returns
## whether an item was held. Bags in the bag slots are just put back.
## The bag or equipment slot of the item on the cursor, or {}.
func held_ref() -> Dictionary:
	return _held


func clear_held() -> void:
	_set_held({})


func drop_held_on_world() -> bool:
	if _held.is_empty() or _destroy_prompt:
		return not _held.is_empty()
	if _held.kind == "bag_slot":
		_set_held({})
		return true
	var stack := Inventory.stack_at(_held)
	if not Inventory.can_destroy(int(stack.id)):
		# Put back where it came from.
		_set_held({})
		message.emit(Inventory.ERR_CANT_DESTROY, true)
		return true
	var item := ItemDB.get_item(stack.id)
	var what: String = item.name if int(stack.count) <= 1 else "%d %s" % [stack.count, item.name]
	_tooltip.show_item({})
	_destroy_prompt = _panel(Vector2.ZERO, Vector2(150, 40), false)
	_destroy_prompt.name = "DestroyPrompt"
	_destroy_prompt.position = (get_viewport_rect().size - _destroy_prompt.size) / 2 - Vector2(0, 40) * _ui_scale
	var question := _text(_destroy_prompt, Vector2(4, 4), "Do you want to destroy %s?" % what, Color.WHITE, FONT_SIZE)
	question.size.x = 142 * _ui_scale
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in 2:
		var choice := Button.new()
		choice.text = ["Yes", "No"][i]
		choice.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
		choice.position = Vector2(30 + i * 52, 24) * _ui_scale
		choice.size = Vector2(38, 12) * _ui_scale
		var destroy := i == 0
		# Deferred: the prompt is freed in answer, and a button can't be freed
		# while it handles its own press.
		choice.pressed.connect(func() -> void: _answer_destroy.call_deferred(destroy))
		_destroy_prompt.add_child(choice)
	return true


func _answer_destroy(destroy: bool) -> void:
	if not _destroy_prompt:
		return
	_destroy_prompt.queue_free()
	_destroy_prompt = null
	var ref := _held
	_set_held({})
	if destroy and not ref.is_empty():
		Inventory.destroy(ref)


func _view_at(point: Vector2) -> Dictionary:
	for view in _views:
		var box: ColorRect = view.box
		if box.is_visible_in_tree() and box.get_global_rect().has_point(point):
			return view
	return {}


func _set_held(ref: Dictionary) -> void:
	_held = ref
	if _held_icon:
		_held_icon.queue_free()
		_held_icon = null
	if not ref.is_empty():
		var stack := Inventory.stack_at(ref)
		_held_icon = ColorRect.new()
		_held_icon.size = Vector2.ONE * SLOT * _ui_scale
		_held_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_draw_item(_held_icon, ItemDB.get_item(stack.id), stack.count)
		add_child(_held_icon)
		_held_icon.position = get_viewport().get_mouse_position() + Vector2(4, 4) * _ui_scale
	_refresh()


## An item in a slot: its painted icon (Icons), a thin edge in its quality
## color for uncommon and better, and its count.
func _draw_item(box: ColorRect, item: Dictionary, count: int) -> void:
	# The box under the icon shows nothing of its own (the item held on the
	# cursor has no slot frame).
	box.color = Color.TRANSPARENT
	UiStyle.icon(box, Icons.texture(Icons.item_key(item)), maxf(roundf(_ui_scale * 1.2), 2.0))
	if int(item.get("Quality", 1)) >= 2:
		var border := ReferenceRect.new()
		border.border_color = ItemDB.quality_color(item)
		border.border_width = maxf(_ui_scale * 0.6, 1.0)
		border.editor_only = false
		border.position = Vector2.ONE * maxf(roundf(_ui_scale * 1.2), 2.0)
		border.size = box.size - border.position * 2.0
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(border)
	if count > 1:
		UiStyle.count_label(box, count, _ui_scale)


## A gilt window (UiStyle), with a title band unless `band` is false.
func _panel(at: Vector2, panel_size: Vector2, band := true) -> Control:
	var panel := UiStyle.panel(self, panel_size, _ui_scale, band)
	panel.position = at * _ui_scale
	move_child(panel, -1)
	return panel


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
