class_name SpellUI
extends Control
## The action bar (keys 1 to 0, -, =), the spellbook (P) and the player's buff
## bar. Drag spells from the spellbook onto the bar, drag them between slots,
## or drag them off the bar to remove them. Clicking a slot or right-clicking
## a spellbook entry casts. Right-click a buff to cancel it.
## Slot boxes are redrawn in place, never freed while handling input.
## Sizes are in HUD units (1/270 of the window height), times ui_scale.

signal message(text: String, is_error: bool)

const SLOT := 20.0
const GAP := 2.0
const BOOK_ROW := 16.0
const BUFF := 14.0
const DRAG_THRESHOLD := 6.0
const KEY_LABELS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="]
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
var _bar_slots: Array[ColorRect] = []
var _book: Control
var _book_rows: Control
var _buffs: Control
## The spell on the cursor, or 0.
var _held := 0
var _held_icon: Control
var _press_slot := -1
var _press_position := Vector2.ZERO


func setup(player: Player, ui_scale: float, screen: Vector2, tooltip: ItemTooltip, book_open: bool) -> void:
	_player = player
	_ui_scale = ui_scale
	_screen = screen
	_tooltip = tooltip
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_bar()
	_build_book()
	_book.visible = book_open
	_buffs = Control.new()
	_buffs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_buffs)
	_player.combatant.auras_changed.connect(_draw_buffs)
	_draw_buffs()
	GameState.spells_changed.connect(_on_spells_changed)


## New spells: the spellbook is rebuilt and bar slots redrawn (training can
## swap a slot to a replacing rank).
func _on_spells_changed() -> void:
	var was_open := _book.visible
	_book.queue_free()
	_build_book()
	_book.visible = was_open
	for i in _bar_slots.size():
		_draw_bar_slot(i)


func is_book_open() -> bool:
	return _book.visible


## Esc: drops a held spell or closes the spellbook. Returns whether it did anything.
func close_one() -> bool:
	if _held != 0:
		_set_held(0)
		return true
	if _book.visible:
		_book.visible = false
		_tooltip.show_lines([])
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("spellbook"):
		_book.visible = not _book.visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	for i in _bar_slots.size():
		_update_slot_state(i)
	if _held_icon:
		_held_icon.position = get_viewport().get_mouse_position() + Vector2(4, 4) * _ui_scale
	for icon in _buffs.get_children():
		var aura: Dictionary = icon.get_meta("aura")
		var time: Label = icon.get_meta("time")
		time.text = _short_time(aura.remaining)


# Action bar.

func _build_bar() -> void:
	var width := GameState.ACTION_SLOTS * (SLOT + GAP) - GAP
	var left := (_screen.x - width) / 2.0
	for i in GameState.ACTION_SLOTS:
		var box := ColorRect.new()
		box.position = Vector2(left + i * (SLOT + GAP), _screen.y - SLOT - 4) * _ui_scale
		box.size = Vector2.ONE * SLOT * _ui_scale
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(box)
		_bar_slots.append(box)
		var index := i
		box.gui_input.connect(func(event: InputEvent) -> void: _on_bar_input(event, index))
		box.mouse_entered.connect(func() -> void: _tooltip.show_lines(spell_tooltip(GameState.action_bar[index])))
		box.mouse_exited.connect(func() -> void: _tooltip.show_lines([]))
		_draw_bar_slot(i)


func _draw_bar_slot(i: int) -> void:
	var box := _bar_slots[i]
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var id := GameState.action_bar[i]
	if id == 0:
		box.color = EMPTY
	else:
		_draw_icon(box, id)
	# Overlays, updated every frame: out of mana, cooldown, key label.
	var no_mana := _rect(box, Vector2.ZERO, Vector2.ONE * SLOT, Color(0.1, 0.1, 0.6, 0.5))
	no_mana.name = "NoMana"
	var cooldown := _rect(box, Vector2.ZERO, Vector2(SLOT, 0), Color(0, 0, 0, 0.65))
	cooldown.name = "Cooldown"
	var key := _text(box, Vector2(SLOT - 6, -1), KEY_LABELS[i], Color(0.9, 0.9, 0.9), 6)
	key.name = "Key"


func _update_slot_state(i: int) -> void:
	var box := _bar_slots[i]
	var id := GameState.action_bar[i]
	var no_mana: Control = box.get_node_or_null("NoMana")
	var cooldown: Control = box.get_node_or_null("Cooldown")
	var key: Label = box.get_node_or_null("Key")
	if no_mana == null:
		return
	var caster := _player.spells
	var spell := SpellDB.get_spell(id) if id != 0 else {}
	no_mana.visible = not spell.is_empty() and _player.combatant.mana < caster.mana_cost(spell)
	var fraction := caster.cooldown_fraction(id) if id != 0 else 0.0
	cooldown.size.y = SLOT * _ui_scale * fraction
	cooldown.position.y = SLOT * _ui_scale - cooldown.size.y
	# Classic shows the key in red when the target is out of range.
	key.add_theme_color_override("font_color", Color(1, 0.2, 0.2) if id != 0 and caster.out_of_range(id) else Color(0.9, 0.9, 0.9))
	# Attack glows while auto-attacking.
	box.modulate = Color(1.4, 1.2, 0.7) if id == SpellDB.ATTACK and _player.combatant.attack_target else Color.WHITE


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
	for i in _bar_slots.size():
		if _bar_slots[i].get_global_rect().has_point(point):
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


# Spellbook.

func _build_book() -> void:
	var known := GameState.known_spells
	var height := 14.0 + known.size() * BOOK_ROW + 4.0
	_book = _panel(Vector2(130, 50), Vector2(130, height))
	_text(_book, Vector2(4, 1), "Spellbook (P)", TITLE, 7)
	for i in known.size():
		var id := known[i]
		var spell := SpellDB.get_spell(id)
		var row := ColorRect.new()
		row.color = Color.TRANSPARENT
		row.position = Vector2(2, 14 + i * BOOK_ROW) * _ui_scale
		row.size = Vector2(126, BOOK_ROW - 1) * _ui_scale
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		_book.add_child(row)
		var icon := ColorRect.new()
		icon.size = Vector2.ONE * (BOOK_ROW - 2) * _ui_scale
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		_draw_icon(icon, id)
		_text(row, Vector2(BOOK_ROW + 2, 0), spell.SpellName, Color.WHITE, 6)
		_text(row, Vector2(BOOK_ROW + 2, 7), str(spell.Rank1), Color(0.6, 0.6, 0.6), 5)
		row.mouse_entered.connect(func() -> void:
			row.color = Color(1, 1, 1, 0.08)
			_tooltip.show_lines(spell_tooltip(id))
		)
		row.mouse_exited.connect(func() -> void:
			row.color = Color.TRANSPARENT
			_tooltip.show_lines([])
		)
		row.gui_input.connect(func(event: InputEvent) -> void: _on_book_input(event, id))
	_book.visible = false


func _on_book_input(event: InputEvent, id: int) -> void:
	var button := event as InputEventMouseButton
	if button and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
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


# Buffs.

func _draw_buffs() -> void:
	for child in _buffs.get_children():
		child.queue_free()
	var right := _screen.x - 4
	var i := 0
	for aura in _player.combatant.auras:
		var spell: Dictionary = aura.spell
		var icon := ColorRect.new()
		icon.position = Vector2(right - (i + 1) * (BUFF + 3), 4) * _ui_scale
		icon.size = Vector2.ONE * BUFF * _ui_scale
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		_buffs.add_child(icon)
		_draw_icon(icon, int(spell.Id))
		var time := _text(icon, Vector2(-2, BUFF), "", Color.WHITE, 5)
		icon.set_meta("aura", aura)
		icon.set_meta("time", time)
		var id := int(spell.Id)
		icon.mouse_entered.connect(func() -> void:
			_tooltip.show_lines([[SpellDB.full_name(spell), "", Color.WHITE], [_long_time(aura.remaining), "", DESCRIPTION]])
		)
		icon.mouse_exited.connect(func() -> void: _tooltip.show_lines([]))
		icon.gui_input.connect(func(event: InputEvent) -> void:
			var button := event as InputEventMouseButton
			if button and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
				_tooltip.show_lines([])
				_player.combatant.remove_aura(id)
		)
		i += 1


# Tooltips.

## The classic spell tooltip as rows of [left, right, color].
func spell_tooltip(id: int) -> Array:
	if id == 0:
		return []
	var spell := SpellDB.get_spell(id)
	var lines: Array = [[spell.SpellName, str(spell.Rank1), Color.WHITE]]
	if id == SpellDB.ATTACK:
		lines.append(["Toggles melee attack on your target.", "", DESCRIPTION])
		return lines
	var cost := _player.spells.mana_cost(spell)
	var reach := SpellDB.spell_range(spell)
	var range_text := "" if reach <= 0.0 or reach >= 50000.0 else "%d yd range" % reach
	lines.append(["%d Mana" % cost if cost > 0 else "", range_text, Color.WHITE])
	var time := SpellDB.cast_time(spell)
	var cooldown := SpellDB.cooldown(spell)
	lines.append(["Instant" if time <= 0.0 else "%s sec cast" % _number(time), "%s cooldown" % _long_time(cooldown) if cooldown > 0.0 else "", Color.WHITE])
	var description := _describe(spell)
	if not description.is_empty():
		lines.append([description, "", DESCRIPTION])
	return lines


func _describe(spell: Dictionary) -> String:
	var level := GameState.level
	if spell.SpellName == "Holy Light":
		var heal := SpellDB.effect_range(spell, 0, level)
		return "Heals a friendly target for %d to %d." % [heal.x, heal.y]
	if SpellDB.seal_of_righteousness_proc(int(spell.Id)) != 0:
		return "Fills the Paladin with holy spirit for 30 sec, granting each melee attack %d additional Holy damage. Only one Seal can be active on the Paladin at any one time." % _player.spells.seal_of_righteousness_damage(spell)
	return ""


# Drawing helpers.

func _draw_icon(box: ColorRect, id: int) -> void:
	var spell := SpellDB.get_spell(id)
	var color: Color = SCHOOL_COLORS[clampi(int(spell.get("School", 0)), 0, SCHOOL_COLORS.size() - 1)]
	box.color = color.darkened(0.55)
	var border := ReferenceRect.new()
	border.border_color = color
	border.border_width = maxf(_ui_scale, 1.0)
	border.editor_only = false
	border.size = box.size
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(border)
	var letters := ""
	for word in str(spell.SpellName).split(" ", false):
		if word[0] == word[0].to_upper():
			letters += word[0]
	_text(box, Vector2(1, 1), letters.substr(0, 3), Color.WHITE, 6)


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


func _panel(at: Vector2, panel_size: Vector2) -> Control:
	var panel := ColorRect.new()
	panel.color = BACK
	panel.position = at * _ui_scale
	panel.size = panel_size * _ui_scale
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
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
