class_name SpellUI
extends Control
## The action bar (keys 1 to 0, -, =), the extra action bars turned on under
## Interface (two rows above the XP bar, two columns down the right side under
## the minimap), the spellbook (P) and the player's buff bar. Drag spells from
## the spellbook onto a bar, drag them between slots, or drag them off a bar to
## remove them. Clicking a slot or right-clicking a spellbook entry casts.
## Right-click a buff to cancel it.
## Slot boxes are redrawn in place, never freed while handling input.
## Sizes are in HUD units (1/270 of the window height), times ui_scale.

signal message(text: String, is_error: bool)

const SLOT := 20.0
const GAP := 2.0
## The spellbook: where it sits, its size, a spell's row height, spells per
## page (two columns), and the size of a tab.
const BOOK_AT := Vector2(4, 43)
const BOOK_SIZE := Vector2(190, 132)
const BOOK_ENTRY := 17.0
const BOOK_PER_PAGE := 12
const BOOK_TAB := Vector2(44, 11)
const BUFF := 14.0
const STANCE_SLOT := 16.0
## The XP bar sits between the action bar and the stance bar (drawn by the HUD).
const XP_BAR := 7.0
const DRAG_THRESHOLD := 6.0
const BACK := Color(0.08, 0.08, 0.1, 0.92)
const EMPTY := Color(0.16, 0.16, 0.2, 0.9)
const TITLE := Color(1, 0.85, 0.4)
const DESCRIPTION := Color("ffd100")
const SCHOOL_COLORS := [
	Color(0.75, 0.75, 0.75), Color(1, 0.9, 0.5), Color(1, 0.5, 0.2), Color(0.3, 1, 0.3),
	Color(0.5, 0.8, 1), Color(0.6, 0.4, 1), Color(1, 0.5, 1),
]

var _player: Player
var _ui_scale := 1.0
var _screen := Vector2.ZERO
var _tooltip: ItemTooltip
## Slot boxes of the bars shown, by GameState.action_bar index.
var _bar_slots: Dictionary = {}
## The stance bar: one fixed button per known aura or stance, highest rank.
var _stance_bar: Control
var _stance_slots: Array[ColorRect] = []
var _stance_ids: Array[int] = []
var _book: Control
var _book_rows: Control
var _buffs: Control
## The buff under the mouse, or {}, and the time its tooltip last showed.
var _hovered_aura: Dictionary = {}
var _buff_tooltip_text := ""
## The spell on the cursor, or 0.
var _held := 0
## The spellbook's open tab (0 General, then each talent tree) and page.
var _book_tab := 0
var _book_page := 0
var _spells_redraw_queued := false
var _held_icon: Control
var _press_slot := -1
var _press_position := Vector2.ZERO
## An open flyout menu (Boons, Greater Boons) and the button it came from.
var _flyout: Control
var _flyout_anchor: Control


func setup(player: Player, ui_scale: float, screen: Vector2, tooltip: ItemTooltip, book_open: bool) -> void:
	_player = player
	_ui_scale = ui_scale
	_screen = screen
	_tooltip = tooltip
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_bar()
	_build_stance_bar()
	_build_book()
	_book.visible = book_open
	_buffs = Control.new()
	_buffs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_buffs)
	_player.combatant.auras_changed.connect(_draw_buffs)
	_draw_buffs()
	_player.flyout_pressed.connect(func(slot: int) -> void: _toggle_flyout(GameState.action_bar[slot], _bar_slots[slot]))
	# Many changes at once (a whole build learned) redraw once.
	GameState.spells_changed.connect(func() -> void:
		if not _spells_redraw_queued:
			_spells_redraw_queued = true
			_on_spells_changed.call_deferred())


## New spells: the spellbook is rebuilt and bar slots redrawn (training can
## swap a slot to a replacing rank).
func _on_spells_changed() -> void:
	_spells_redraw_queued = false
	if not is_instance_valid(_book):
		return
	var was_open := _book.visible
	_book.queue_free()
	_build_book()
	_book.visible = was_open
	for i: int in _bar_slots:
		_draw_bar_slot(i)
	_stance_bar.queue_free()
	_build_stance_bar()


func is_book_open() -> bool:
	return _book.visible


## Esc: closes a flyout, drops a held spell or closes the spellbook. Returns
## whether it did anything.
func close_one() -> bool:
	if _flyout:
		_close_flyout()
		return true
	if _held != 0:
		_set_held(0)
		return true
	if _book.visible:
		_book.visible = false
		_tooltip.show_lines([])
		return true
	return false


## A click anywhere but the open flyout (or its button) closes it.
func _input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if _flyout and click and click.pressed:
		var inside := _flyout.get_global_rect().has_point(click.global_position)
		var on_anchor := is_instance_valid(_flyout_anchor) and _flyout_anchor.get_global_rect().has_point(click.global_position)
		if not inside and not on_anchor:
			_close_flyout()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("spellbook"):
		_book.visible = not _book.visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	for i: int in _bar_slots:
		_update_slot_state(i)
	for i in _stance_slots.size():
		_update_stance_state(i)
	if _held_icon:
		_held_icon.position = get_viewport().get_mouse_position() + Vector2(4, 4) * _ui_scale
	for icon in _buffs.get_children():
		var aura: Dictionary = icon.get_meta("aura")
		var time: Label = icon.get_meta("time")
		time.text = _short_time(aura.remaining)
	_update_buff_tooltip()


# Action bar.

## The main bar along the bottom, the bottom extra bars stacked above the XP
## bar, and the right ones as columns from the screen's right edge.
func _build_bar() -> void:
	var width := GameState.ACTION_SLOTS * (SLOT + GAP) - GAP
	var left := (_screen.x - width) / 2.0
	var row := 0
	var column := 0
	var right := right_bars_layout(_screen)
	for bar in 1 + GameState.EXTRA_BARS.size():
		if not GameState.bar_shown(bar):
			continue
		var vertical := bar >= 3
		for i in GameState.ACTION_SLOTS:
			var at: Vector2
			var unit := SLOT
			if vertical:
				unit = right.unit
				at = Vector2(_screen.x - Minimap.MARGIN - (column + 1) * (unit + GAP) + GAP, right.top + i * (unit + GAP))
			else:
				at = Vector2(left + i * (SLOT + GAP), bottom_row_y(_screen.y, row))
			_add_slot(bar * GameState.ACTION_SLOTS + i, at, unit)
		if vertical:
			column += 1
		else:
			row += 1


## The top of a bottom bar row: 0 is the main bar, then rows stack upward from
## above the XP bar (straight above the main bar at the level cap).
static func bottom_row_y(screen_height: float, row: int) -> float:
	var y := screen_height - SLOT - 4
	if row == 0:
		return y
	var xp_room := XP_BAR + GAP if GameState.level < ClassicData.MAX_LEVEL else 0.0
	return y - xp_room - row * (SLOT + GAP)


## The stance bar's top: above the XP bar and any bottom extra bars. The cast
## bar sits above it.
static func stance_top(screen_height: float) -> float:
	var rows := bottom_bars()
	var top := bottom_row_y(screen_height, rows) if rows > 0 else bottom_row_y(screen_height, 1) + SLOT + GAP
	return top - GAP - STANCE_SLOT


## How many bottom extra bars are shown.
static func bottom_bars() -> int:
	return int(GameState.bar_shown(1)) + int(GameState.bar_shown(2))


## The right bars: slot size (smaller when twelve don't fit under the
## minimap), their top, and the width they take from the right edge (0 with
## none shown). They're centered in the room between the minimap and the
## bottom bars.
static func right_bars_layout(screen: Vector2) -> Dictionary:
	var columns := int(GameState.bar_shown(3)) + int(GameState.bar_shown(4))
	var top := Minimap.corner(screen.x).y + Minimap.SIZE + 6
	var room := screen.y - SLOT - 8 - top
	var unit := minf(SLOT, room / GameState.ACTION_SLOTS - GAP)
	var height := GameState.ACTION_SLOTS * (unit + GAP) - GAP
	return {
		"unit": unit, "top": top + maxf((room - height) / 2.0, 0.0),
		"width": columns * (unit + GAP) if columns > 0 else 0.0,
	}


func _add_slot(slot: int, at: Vector2, unit: float) -> void:
	var box := ColorRect.new()
	box.position = at * _ui_scale
	box.size = Vector2.ONE * unit * _ui_scale
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(box)
	_bar_slots[slot] = box
	box.gui_input.connect(func(event: InputEvent) -> void: _on_bar_input(event, slot))
	box.mouse_entered.connect(func() -> void: _tooltip.show_lines(spell_tooltip(GameState.action_bar[slot])))
	box.mouse_exited.connect(func() -> void: _tooltip.show_lines([]))
	_draw_bar_slot(slot)


func _draw_bar_slot(i: int) -> void:
	var box: ColorRect = _bar_slots[i]
	var unit := box.size.x / _ui_scale
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var id := GameState.action_bar[i]
	if id == 0:
		box.color = Color.TRANSPARENT
		UiStyle.frame_box(box, _ui_scale)
	else:
		_draw_icon(box, id)
	# Overlays, updated every frame: out of mana, cooldown, key label.
	var no_mana := _rect(box, Vector2.ZERO, Vector2.ONE * unit, Color(0.1, 0.1, 0.6, 0.5))
	no_mana.name = "NoMana"
	var cooldown := _rect(box, Vector2.ZERO, Vector2(unit, 0), Color(0, 0, 0, 0.65))
	cooldown.name = "Cooldown"
	var key := _text(box, Vector2(0, -0.5), Settings.key_label(GameState.slot_action(i)), Color(0.9, 0.9, 0.9), 6)
	key.add_theme_color_override("font_outline_color", Color.BLACK)
	key.add_theme_constant_override("outline_size", maxi(roundi(_ui_scale * 1.2), 2))
	key.size.x = (unit - 1.5) * _ui_scale
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	key.name = "Key"


func _update_slot_state(i: int) -> void:
	var box: ColorRect = _bar_slots[i]
	var id := GameState.action_bar[i]
	var no_mana: Control = box.get_node_or_null("NoMana")
	var cooldown: Control = box.get_node_or_null("Cooldown")
	var key: Label = box.get_node_or_null("Key")
	if no_mana == null:
		return
	var caster := _player.spells
	if SpellDB.is_flyout(id):
		no_mana.visible = false
		cooldown.size.y = 0.0
		key.text = Settings.key_label(GameState.slot_action(i))
		key.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		box.modulate = Color.WHITE
		return
	var spell := SpellDB.get_spell(id) if id != 0 else {}
	no_mana.visible = not spell.is_empty() and _player.combatant.mana < caster.mana_cost(spell)
	var fraction := caster.cooldown_fraction(id) if id != 0 else 0.0
	cooldown.size.y = box.size.y * fraction
	cooldown.position.y = box.size.y - cooldown.size.y
	# Follows the key bindings. Classic shows it red when the target is out of range.
	key.text = Settings.key_label(GameState.slot_action(i))
	key.add_theme_color_override("font_color", Color(1, 0.2, 0.2) if id != 0 and caster.out_of_range(id) else Color(0.9, 0.9, 0.9))
	# Attack glows while auto-attacking, Mighty Blow while it waits for the swing.
	var glowing := (id == SpellDB.ATTACK and _player.combatant.attack_target) or (id != 0 and int(caster.queued_swing().get("Id", 0)) == id)
	box.modulate = Color(1.4, 1.2, 0.7) if glowing else Color.WHITE


func _on_bar_input(event: InputEvent, i: int) -> void:
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			if _held != 0:
				_drop_on_slot(i)
			else:
				_press_slot = i
				_press_position = button.global_position
		else:
			if _held != 0 and _press_slot >= 0:
				# Finishing a drag that started on the bar.
				var target := _slot_at(button.global_position)
				if target >= 0:
					_drop_on_slot(target)
				else:
					_set_held(0)  # Dragged off the bar: removed.
			elif _press_slot == i and SpellDB.is_flyout(GameState.action_bar[i]):
				_toggle_flyout(GameState.action_bar[i], _bar_slots[i])
			elif _press_slot == i and GameState.action_bar[i] != 0:
				_player.spells.cast(GameState.action_bar[i])
			_press_slot = -1
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _press_slot >= 0 and _held == 0:
		var motion := event as InputEventMouseMotion
		if motion.global_position.distance_to(_press_position) > DRAG_THRESHOLD * _ui_scale and GameState.action_bar[_press_slot] != 0:
			# Picking a spell up off the bar removes it from the slot.
			var id := GameState.action_bar[_press_slot]
			GameState.action_bar[_press_slot] = 0
			_draw_bar_slot(_press_slot)
			_set_held(id)


func _drop_on_slot(i: int) -> void:
	var previous := GameState.action_bar[i]
	GameState.action_bar[i] = _held
	_draw_bar_slot(i)
	_set_held(previous)
	if previous == 0:
		_press_slot = -1


func _slot_at(point: Vector2) -> int:
	for i: int in _bar_slots:
		if (_bar_slots[i] as ColorRect).get_global_rect().has_point(point):
			return i
	return -1


func _set_held(id: int) -> void:
	_held = id
	if _held_icon:
		_held_icon.queue_free()
		_held_icon = null
	if id != 0:
		_held_icon = ColorRect.new()
		_held_icon.size = Vector2.ONE * SLOT * _ui_scale
		_held_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_draw_icon(_held_icon, id)
		add_child(_held_icon)
		_held_icon.position = get_viewport().get_mouse_position() + Vector2(4, 4) * _ui_scale


# Stance bar.

## Spells that live on the stance bar instead of the action bar: Templar
## Presences, Man-at-Arms stances and Shroud of Shadow. Only the highest known
## rank of each.
func stance_spells() -> Array[int]:
	var best := {}
	for id: int in GameState.known_spells:
		var spell := SpellDB.get_spell(id)
		if id == SpellDB.ATTACK or not SpellDB.is_stance_bar_spell(spell):
			continue
		var name: String = spell.SpellName
		if not best.has(name) or int(spell.SpellLevel) > int(SpellDB.get_spell(best[name]).SpellLevel):
			best[name] = id
	# In the order each Presence was first learned (known_spells keeps learning
	# order, and the dictionary keeps the order names were first seen), so a
	# new rank never moves a button.
	var ids: Array[int] = []
	ids.assign(best.values())
	return ids


## Sits just above the left end of the action bar (and any bottom extra bars),
## and only shows when it has something in it. Its buttons cast but can't be
## dragged.
func _build_stance_bar() -> void:
	_stance_slots.clear()
	_stance_ids = stance_spells()
	_stance_bar = Control.new()
	_stance_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stance_bar)
	_stance_bar.visible = not _stance_ids.is_empty()
	var bar_left := (_screen.x - (GameState.ACTION_SLOTS * (SLOT + GAP) - GAP)) / 2.0
	# Above the XP bar and the bottom extra bars (straight above the action
	# bar at the level cap with none).
	var top := stance_top(_screen.y)
	for i in _stance_ids.size():
		var id := _stance_ids[i]
		var box := ColorRect.new()
		box.position = Vector2(bar_left + i * (STANCE_SLOT + GAP), top) * _ui_scale
		box.size = Vector2.ONE * STANCE_SLOT * _ui_scale
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		_stance_bar.add_child(box)
		_stance_slots.append(box)
		_draw_icon(box, id)
		var cooldown := _rect(box, Vector2.ZERO, Vector2(STANCE_SLOT, 0), Color(0, 0, 0, 0.65))
		cooldown.name = "Cooldown"
		# A gold frame marks the stance or Presence you're in.
		var lit := ReferenceRect.new()
		lit.name = "Active"
		lit.border_color = Color(1, 0.85, 0.3)
		lit.border_width = maxf(2.0 * _ui_scale, 2.0)
		lit.editor_only = false
		lit.size = box.size
		lit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(lit)
		box.mouse_entered.connect(func() -> void: _tooltip.show_lines(spell_tooltip(id)))
		box.mouse_exited.connect(func() -> void: _tooltip.show_lines([]))
		box.gui_input.connect(func(event: InputEvent) -> void:
			var button := event as InputEventMouseButton
			if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
				_player.spells.cast(id)
				get_viewport().set_input_as_handled()
		)


## The active aura's button is lit, the others dimmed, as on the classic bar.
func _update_stance_state(i: int) -> void:
	var box := _stance_slots[i]
	var id := _stance_ids[i]
	var name: String = SpellDB.get_spell(id).SpellName
	var active := not _player.combatant.find_aura(func(spell: Dictionary) -> bool: return spell.SpellName == name).is_empty()
	box.modulate = Color(1.3, 1.3, 1.1) if active else Color(0.6, 0.6, 0.6)
	(box.get_node("Active") as Control).visible = active
	var cooldown: Control = box.get_node("Cooldown")
	cooldown.size.y = STANCE_SLOT * _ui_scale * _player.spells.cooldown_fraction(id)
	cooldown.position.y = STANCE_SLOT * _ui_scale - cooldown.size.y


# Spellbook.

## The spellbook, as classic's: a page of twelve spells in two columns,
## with tabs down its right edge, General first and then one per talent tree
## (a spell's tab is its skill line's tree, SpellDB.book_tab), and page
## arrows when a tab has more.
func _build_book() -> void:
	var trees := Talents.trees(GameState.char_class)
	_book_tab = clampi(_book_tab, 0, trees.size())
	var hide_old := bool(Settings.get_value("spellbook_hide_old_ranks"))
	var spells: Array[int] = []
	for id in GameState.known_spells:
		if SpellDB.book_tab(GameState.char_class, id) + 1 != _book_tab or SpellDB.is_weapon_skill(id):
			continue
		if hide_old and GameState.best_rank(str(SpellDB.get_spell(id).get("SpellName", ""))) != id:
			continue
		spells.append(id)
	spells.sort_custom(func(a: int, b: int) -> bool:
		var sa := SpellDB.get_spell(a)
		var sb := SpellDB.get_spell(b)
		if int(sa.get("SpellLevel", 0)) != int(sb.get("SpellLevel", 0)):
			return int(sa.get("SpellLevel", 0)) < int(sb.get("SpellLevel", 0))
		return str(sa.get("SpellName", "")) < str(sb.get("SpellName", "")))
	# Flyouts (Boons, Greater Boons) lead the tab their spells are in.
	for flyout: int in [SpellDB.GREATER_BOONS, SpellDB.BOONS]:
		var inside := SpellDB.flyout_spells(flyout, GameState)
		if not inside.is_empty() and SpellDB.book_tab(GameState.char_class, inside[0]) + 1 == _book_tab:
			spells.push_front(flyout)
	var pages := maxi(ceili(spells.size() / float(BOOK_PER_PAGE)), 1)
	_book_page = clampi(_book_page, 0, pages - 1)
	_book = _panel(BOOK_AT, BOOK_SIZE)
	var tab_name := "General" if _book_tab == 0 else str(trees[_book_tab - 1].name)
	UiStyle.title(_book, Vector2(5, 1.5), "Spellbook (P) - %s" % tab_name, _ui_scale)
	UiStyle.close_button(_book, Vector2(BOOK_SIZE.x - 10, 2), _ui_scale, func() -> void:
		_book.visible = false
		_tooltip.show_lines([]))
	var column_width := (BOOK_SIZE.x - 6) / 2.0
	for i in range(_book_page * BOOK_PER_PAGE, mini((_book_page + 1) * BOOK_PER_PAGE, spells.size())):
		var place := i - _book_page * BOOK_PER_PAGE
		var at := Vector2(3 + (place % 2) * column_width, 16 + (place / 2) * BOOK_ENTRY)
		_book_entry(spells[i], at, column_width - 2)
	if spells.is_empty():
		_text(_book, Vector2(6, 18), "No spells here yet.", Color(0.6, 0.6, 0.6), 6)
	# Page arrows.
	if pages > 1:
		_text(_book, Vector2(BOOK_SIZE.x / 2.0 - 14, BOOK_SIZE.y - 11), "Page %d/%d" % [_book_page + 1, pages], Color(0.75, 0.75, 0.75), 6)
		for step: int in [-1, 1]:
			var enabled: bool = _book_page + step >= 0 and _book_page + step < pages
			var arrow := _text(_book, Vector2(BOOK_SIZE.x / 2.0 + (24 if step > 0 else -30), BOOK_SIZE.y - 12), ">" if step > 0 else "<", TITLE if enabled else Color(0.4, 0.4, 0.4), 8)
			if enabled:
				arrow.mouse_filter = Control.MOUSE_FILTER_STOP
				arrow.gui_input.connect(func(event: InputEvent) -> void:
					if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
						_book_page += step
						_redraw_book())
	# "Hide old ranks": only each spell's highest known rank (saved).
	var box := ColorRect.new()
	box.color = Color(0.1, 0.1, 0.12)
	box.position = Vector2(4, BOOK_SIZE.y - 10) * _ui_scale
	box.size = Vector2.ONE * 7 * _ui_scale
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	_book.add_child(box)
	var box_border := ReferenceRect.new()
	box_border.border_color = Color(0.7, 0.65, 0.45)
	box_border.border_width = maxf(_ui_scale, 1.0)
	box_border.editor_only = false
	box_border.size = box.size
	box_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(box_border)
	if hide_old:
		_text(box, Vector2(1.2, -1.5), "x", TITLE, 7)
	var box_label := _text(_book, Vector2(13, BOOK_SIZE.y - 11), "Hide old ranks", Color(0.8, 0.8, 0.8), 6)
	box_label.mouse_filter = Control.MOUSE_FILTER_STOP
	for clickable: Control in [box, box_label]:
		clickable.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				Settings.set_value("spellbook_hide_old_ranks", not hide_old)
				Settings.save()
				_redraw_book())
	# Tabs down the right edge, outside the page.
	var names: Array[String] = ["General"]
	for tree: Dictionary in trees:
		names.append(str(tree.name))
	for i in names.size():
		var index := i
		UiStyle.tab(_book, Vector2(BOOK_SIZE.x + 1, 8 + i * (BOOK_TAB.y + 2)), BOOK_TAB, names[i], i == _book_tab, _ui_scale, func() -> void:
			_book_tab = index
			_book_page = 0
			_redraw_book())
	_book.visible = false


## One spell on the page: icon, name and rank. Hover for its tooltip,
## right-click to cast, drag onto a bar.
func _book_entry(id: int, at: Vector2, width: float) -> void:
	var spell := SpellDB.get_spell(id)
	var row := ColorRect.new()
	row.color = Color.TRANSPARENT
	row.position = at * _ui_scale
	row.size = Vector2(width, BOOK_ENTRY - 1) * _ui_scale
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	_book.add_child(row)
	var icon := ColorRect.new()
	icon.size = Vector2.ONE * (BOOK_ENTRY - 3) * _ui_scale
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	_draw_icon(icon, id)
	var name := _text(row, Vector2(BOOK_ENTRY, 1), spell.SpellName, Color.WHITE, 6)
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.size.x = (width - BOOK_ENTRY) * _ui_scale
	_text(row, Vector2(BOOK_ENTRY, 8), "Choose one" if SpellDB.is_flyout(id) else str(spell.Rank1), Color(0.6, 0.6, 0.6), 5)
	row.mouse_entered.connect(func() -> void:
		row.color = Color(1, 1, 1, 0.08)
		_tooltip.show_lines(spell_tooltip(id))
	)
	row.mouse_exited.connect(func() -> void:
		row.color = Color.TRANSPARENT
		_tooltip.show_lines([])
	)
	row.gui_input.connect(func(event: InputEvent) -> void: _on_book_input(event, id, row))


## Rebuilds the book in place (a new tab or page), keeping it open.
func _redraw_book() -> void:
	var was_open := _book.visible
	_book.queue_free()
	_build_book()
	_book.visible = was_open
	_tooltip.show_lines([])


func _on_book_input(event: InputEvent, id: int, row: Control = null) -> void:
	var button := event as InputEventMouseButton
	if button and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT and SpellDB.is_flyout(id):
		_toggle_flyout(id, row)
	elif button and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
		_player.spells.cast(id)
	elif button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		_set_held(id)
		_press_slot = -1
	elif button and not button.pressed and button.button_index == MOUSE_BUTTON_LEFT and _held != 0:
		# A drag from the book ends where the mouse is released.
		var target := _slot_at(button.global_position)
		if target >= 0:
			_drop_on_slot(target)
	else:
		return
	get_viewport().set_input_as_handled()


# Flyouts.

## Opens a flyout's menu by its button (or closes it if it's open there):
## a row of its spells, upward from a bottom bar, leftward from a right one,
## rightward from the spellbook. Click one to cast it.
func _toggle_flyout(id: int, anchor: Control) -> void:
	var same := _flyout != null and _flyout_anchor == anchor
	_close_flyout()
	if same or anchor == null:
		return
	var spells := SpellDB.flyout_spells(id, GameState)
	if spells.is_empty():
		message.emit("You don't know any %s yet." % str(SpellDB.FLYOUTS[id].name).to_lower(), true)
		return
	var unit := SLOT * _ui_scale
	var gap := GAP * _ui_scale
	var at := anchor.get_global_rect()
	var view := get_viewport_rect().size
	var step := Vector2(0, -(unit + gap))
	var start := Vector2(at.position.x + (at.size.x - unit) / 2.0, at.position.y - unit - gap)
	if _book.is_ancestor_of(anchor):
		step = Vector2(unit + gap, 0)
		start = Vector2(_book.get_global_rect().end.x + gap + BOOK_TAB.x * _ui_scale, at.position.y)
	elif at.end.x > view.x * 0.8 and at.position.y < view.y * 0.7:
		step = Vector2(-(unit + gap), 0)
		start = Vector2(at.position.x - unit - gap, at.position.y + (at.size.y - unit) / 2.0)
	_flyout = Control.new()
	_flyout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flyout_anchor = anchor
	add_child(_flyout)
	var first := start
	for spell_id in spells:
		var box := ColorRect.new()
		box.position = start
		box.size = Vector2.ONE * unit
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		_flyout.add_child(box)
		_draw_icon(box, spell_id)
		box.mouse_entered.connect(func() -> void: _tooltip.show_lines(spell_tooltip(spell_id)))
		box.mouse_exited.connect(func() -> void: _tooltip.show_lines([]))
		box.gui_input.connect(func(event: InputEvent) -> void:
			var click := event as InputEventMouseButton
			if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
				_tooltip.show_lines([])
				_close_flyout()
				_player.spells.cast(spell_id)
				get_viewport().set_input_as_handled())
		start += step
	# The menu's control spans its buttons, for telling clicks outside it.
	var last := start - step
	_flyout.position = Vector2(minf(first.x, last.x), minf(first.y, last.y))
	_flyout.size = Vector2(absf(last.x - first.x), absf(last.y - first.y)) + Vector2.ONE * unit
	for box in _flyout.get_children():
		(box as Control).position -= _flyout.position


func _close_flyout() -> void:
	if _flyout:
		_flyout.queue_free()
	_flyout = null
	_flyout_anchor = null


# Buffs.

func _draw_buffs() -> void:
	for child in _buffs.get_children():
		child.queue_free()
	# Right to left from the minimap's left edge, level with its top.
	var corner := Minimap.corner(_screen.x)
	var right := corner.x - 4
	var i := 0
	for aura in _player.combatant.auras:
		var spell: Dictionary = aura.spell
		# Every buff shows, stances and forms included. Only passive spells'
		# auras (a stance's hidden passive part) aren't buffs, as in classic.
		if SpellDB.is_passive(spell):
			continue
		var icon := ColorRect.new()
		icon.position = Vector2(right - (i + 1) * (BUFF + 3), corner.y) * _ui_scale
		icon.size = Vector2.ONE * BUFF * _ui_scale
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		_buffs.add_child(icon)
		_draw_icon(icon, int(spell.Id))
		var time := _text(icon, Vector2(-2, BUFF), "", Color.WHITE, 5)
		icon.set_meta("aura", aura)
		icon.set_meta("time", time)
		var id := int(spell.Id)
		icon.mouse_entered.connect(func() -> void:
			_hovered_aura = aura
			_buff_tooltip_text = ""
		)
		icon.mouse_exited.connect(func() -> void:
			_hovered_aura = {}
			_tooltip.show_lines([])
		)
		icon.gui_input.connect(func(event: InputEvent) -> void:
			var button := event as InputEventMouseButton
			if button and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
				_hovered_aura = {}
				_tooltip.show_lines([])
				_player.combatant.remove_aura(id)
		)
		i += 1


## Keeps the hovered buff's tooltip counting down, redrawing only when the
## shown time changes.
func _update_buff_tooltip() -> void:
	if _hovered_aura.is_empty():
		return
	if not _hovered_aura in _player.combatant.auras:
		_hovered_aura = {}
		_tooltip.show_lines([])
		return
	var remaining := _long_time(ceilf(_hovered_aura.remaining))
	if remaining == _buff_tooltip_text and _tooltip.visible:
		return
	_buff_tooltip_text = remaining
	var spell: Dictionary = _hovered_aura.spell
	var lines: Array = [[SpellDB.full_name(spell), "", Color.WHITE]]
	# What the buff does, as its spell describes it.
	var description := SpellText.describe(spell, GameState.level, _player.spells)
	if not description.is_empty():
		lines.append([description, "", DESCRIPTION])
	if not remaining.is_empty():
		lines.append([remaining + " remaining", "", DESCRIPTION])
	_tooltip.show_lines(lines)


# Tooltips.

## The classic spell tooltip as rows of [left, right, color].
func spell_tooltip(id: int) -> Array:
	if id == 0:
		return []
	var spell := SpellDB.get_spell(id)
	var lines: Array = [[spell.SpellName, str(spell.Rank1), Color.WHITE]]
	if SpellDB.is_flyout(id):
		var names: Array[String] = []
		for inside in SpellDB.flyout_spells(id, GameState):
			names.append(str(SpellDB.get_spell(inside).SpellName))
		lines.append(["Click to choose one to cast.", "", DESCRIPTION])
		if not names.is_empty():
			lines.append([", ".join(names), "", Color(0.75, 0.75, 0.75)])
		return lines
	if id == SpellDB.ATTACK:
		lines.append([SpellText.describe(spell, GameState.level), "", DESCRIPTION])
		return lines
	var cost := _player.spells.mana_cost(spell)
	# Talents change these: the tooltip shows what they come to.
	var reach := SpellDB.spell_range(spell, _player.combatant)
	var range_text := "" if reach <= 0.0 or reach >= 50000.0 else "%d yd range" % reach
	var cost_text := ("%d Rage" if SpellDB.uses_rage(spell) else "%d Mana") % cost
	lines.append([cost_text if cost > 0 else "", range_text, Color.WHITE])
	var time := SpellDB.cast_time(spell, _player.combatant)
	var cooldown := SpellDB.cooldown(spell, _player.combatant)
	lines.append(["Instant" if time <= 0.0 else "%s sec cast" % _number(time), "%s cooldown" % _long_time(cooldown) if cooldown > 0.0 else "", Color.WHITE])
	var description := _describe(spell)
	if not description.is_empty():
		lines.append([description, "", DESCRIPTION])
	return lines


func _describe(spell: Dictionary) -> String:
	return SpellText.describe(spell, GameState.level, _player.spells)


# Drawing helpers.

## A spell's painted icon (Icons) in its slot frame. Greater boons get a gold
## edge, so a flyout's two rows differ.
func _draw_icon(box: ColorRect, id: int) -> void:
	var spell := SpellDB.get_spell(id)
	box.color = Color.TRANSPARENT
	UiStyle.frame_box(box, _ui_scale)
	var inset := maxf(roundf(_ui_scale * 1.2), 2.0)
	UiStyle.icon(box, Icons.texture(Icons.spell_key(spell)), inset)
	if str(spell.get("SpellName", "")).begins_with("Greater"):
		var border := ReferenceRect.new()
		border.border_color = UiStyle.GOLD_BRIGHT
		border.border_width = maxf(_ui_scale * 0.7, 1.0)
		border.editor_only = false
		border.position = Vector2.ONE * inset
		border.size = box.size - border.position * 2.0
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(border)


func _short_time(seconds: float) -> String:
	if seconds < 0.0:
		return ""
	if seconds >= 60.0:
		return "%dm" % ceili(seconds / 60.0)
	return "%ds" % ceili(seconds)


func _long_time(seconds: float) -> String:
	if seconds < 0.0:
		return ""
	if seconds >= 3600.0:
		return "%s hr" % _number(seconds / 3600.0)
	if seconds >= 60.0:
		return "%s min" % _number(seconds / 60.0)
	return "%s sec" % _number(seconds)


func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value


## A gilt window (UiStyle), with a title band unless `band` is false.
func _panel(at: Vector2, panel_size: Vector2, band := true) -> Control:
	var panel := UiStyle.panel(self, panel_size, _ui_scale, band)
	panel.position = at * _ui_scale
	move_child(panel, -1)
	return panel


func _rect(parent: Node, at: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = at * _ui_scale
	rect.size = rect_size * _ui_scale
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


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
