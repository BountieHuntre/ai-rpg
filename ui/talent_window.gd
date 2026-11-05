class_name TalentWindow
extends Control
## The talent window (N): the class's three trees side by side, each a grid of
## 7 tiers by 4 columns, with each talent's rank, lines to the talents it
## needs, points spent per tree and points left. Click a talent to put a
## point in it. Talents you can learn have a green frame, maxed ones gold,
## out-of-reach ones are dimmed. Hover for the current and next rank.
## Layout is in HUD units (1/270 of the window height, times UI Scale).

const ICON := 14.0
const CELL := 19.0
const TREE_GAP := 8.0
const TOP := 26.0
const SIDE := 6.0
const TIERS := 7
const COLUMNS := 4
const BACK := Color(0.08, 0.08, 0.1, 0.94)
const TREE_BACK := Color(0.12, 0.12, 0.16, 0.9)
const TITLE := Color(1, 0.85, 0.4)
const CAN_LEARN := Color(0.3, 0.9, 0.3)
const MAXED := Color(1, 0.82, 0.25)
const LOCKED := Color(0.45, 0.45, 0.45)
const LINE := Color(0.75, 0.7, 0.5, 0.8)
const RED := Color(1, 0.35, 0.3)
const GREY := Color(0.65, 0.65, 0.65)
const DESCRIPTION := Color("ffd100")
const SCHOOL_COLORS := SpellUI.SCHOOL_COLORS

var _player: Player
var _ui_scale := 1.0
var _screen := Vector2.ZERO
var _tooltip: ItemTooltip
var _panel: Control
var _hovered := 0
var _rebuild_queued := false


func setup(player: Player, ui_scale: float, screen: Vector2, tooltip: ItemTooltip, open: bool) -> void:
	_player = player
	_ui_scale = ui_scale
	_screen = screen
	_tooltip = tooltip
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_panel.visible = open
	# Many changes at once (a whole build learned) rebuild once.
	GameState.spells_changed.connect(_queue_rebuild)
	if _player.has_node("Progression"):
		var progression := _player.get_node("Progression")
		if progression.has_signal("leveled_up"):
			progression.leveled_up.connect(func(_level: int) -> void: _queue_rebuild())


func is_open() -> bool:
	return _panel != null and _panel.visible


func toggle() -> void:
	_panel.visible = not _panel.visible
	if not _panel.visible:
		_tooltip.show_lines([])


## Esc closes it. Returns whether it was open.
func close_one() -> bool:
	if not is_open():
		return false
	toggle()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("talents"):
		toggle()
		get_viewport().set_input_as_handled()


func _queue_rebuild() -> void:
	if not _rebuild_queued:
		_rebuild_queued = true
		_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	if _panel == null:
		return
	var was_open := _panel.visible
	_panel.queue_free()
	_build()
	_panel.visible = was_open
	if _hovered != 0 and was_open:
		_show_tooltip(_hovered)


func _build() -> void:
	var trees := Talents.trees(GameState.char_class)
	var tree_width := COLUMNS * CELL + 6.0
	var width := SIDE * 2 + maxf(trees.size(), 1) * tree_width + maxf(trees.size() - 1, 0) * TREE_GAP
	var height := TOP + TIERS * CELL + 22.0
	_panel = ColorRect.new()
	(_panel as ColorRect).color = BACK
	_panel.position = Vector2((_screen.x - width) / 2.0, maxf((_screen.y - height) / 2.0 - 20.0, 4.0)) * _ui_scale
	_panel.size = Vector2(width, height) * _ui_scale
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	_text(_panel, Vector2(SIDE, 2), "Talents", TITLE, 8)
	var close := _text(_panel, Vector2(width - 9, 2), "x", Color(0.9, 0.4, 0.4), 8)
	close.mouse_filter = Control.MOUSE_FILTER_STOP
	close.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			toggle())
	if trees.is_empty():
		_text(_panel, Vector2(SIDE, TOP), "Your class has no talents yet.", GREY, 7)
		return
	for index in trees.size():
		var tree: Dictionary = trees[index]
		var left := SIDE + index * (tree_width + TREE_GAP)
		var back := ColorRect.new()
		back.color = TREE_BACK
		back.position = Vector2(left, TOP - 12) * _ui_scale
		back.size = Vector2(tree_width, TIERS * CELL + 14) * _ui_scale
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.add_child(back)
		_text(_panel, Vector2(left + 3, TOP - 12), "%s (%d)" % [tree.name, Talents.spent_in(GameState, tree)], TITLE, 6)
		_draw_lines(tree, left)
		for talent: Dictionary in tree.talents:
			_draw_talent(talent, Vector2(left + 3 + int(talent.column) * CELL, TOP + int(talent.tier) * CELL))
	var left_points := Talents.points_left(GameState)
	var footer := "Talent points: %d" % left_points if GameState.level >= Talents.FIRST_LEVEL else "Talents start at level %d." % Talents.FIRST_LEVEL
	_text(_panel, Vector2(SIDE, height - 11), footer, CAN_LEARN if left_points > 0 else GREY, 7)


## Lines from each talent to the talents that need it.
func _draw_lines(tree: Dictionary, left: float) -> void:
	var by_id := {}
	for talent: Dictionary in tree.talents:
		by_id[int(talent.id)] = talent
	for talent: Dictionary in tree.talents:
		for pair: Array in talent.prereq:
			var from: Dictionary = by_id.get(int(pair[0]), {})
			if from.is_empty():
				continue
			var a := Vector2(left + 3 + int(from.column) * CELL + ICON / 2.0, TOP + int(from.tier) * CELL + ICON / 2.0)
			var b := Vector2(left + 3 + int(talent.column) * CELL + ICON / 2.0, TOP + int(talent.tier) * CELL + ICON / 2.0)
			# Down then across, behind the icons.
			_line(Vector2(a.x, a.y), Vector2(a.x, b.y))
			_line(Vector2(a.x, b.y), Vector2(b.x, b.y))


func _line(from: Vector2, to: Vector2) -> void:
	var rect := ColorRect.new()
	rect.color = LINE
	var thickness := 1.5
	rect.position = Vector2(minf(from.x, to.x) - thickness / 2.0, minf(from.y, to.y) - thickness / 2.0) * _ui_scale
	rect.size = Vector2(absf(to.x - from.x) + thickness, absf(to.y - from.y) + thickness) * _ui_scale
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(rect)


func _draw_talent(talent: Dictionary, at: Vector2) -> void:
	var id := int(talent.id)
	var rank := Talents.rank(GameState, id)
	var most: int = talent.ranks.size()
	var spell := SpellDB.get_spell(int(talent.ranks[maxi(rank - 1, 0)]))
	var learnable := Talents.problem(GameState, id).is_empty()
	var color: Color = SCHOOL_COLORS[clampi(int(spell.get("School", 0)), 0, SCHOOL_COLORS.size() - 1)]
	var box := ColorRect.new()
	box.position = at * _ui_scale
	box.size = Vector2.ONE * ICON * _ui_scale
	box.color = color.darkened(0.55)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_child(box)
	var border := ReferenceRect.new()
	border.border_color = MAXED if rank >= most else CAN_LEARN if learnable else color
	border.border_width = maxf(_ui_scale * (1.5 if rank >= most or learnable else 1.0), 1.0)
	border.editor_only = false
	border.size = box.size
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(border)
	var letters := ""
	for word in str(spell.SpellName).split(" ", false):
		if word[0] == word[0].to_upper():
			letters += word[0]
	_text(box, Vector2(1, 0.5), letters.substr(0, 3), Color.WHITE, 5)
	if rank == 0 and not learnable:
		box.modulate = Color(0.5, 0.5, 0.5)
	var rank_label := _text(_panel, at + Vector2(ICON - 5, ICON - 5), "%d/%d" % [rank, most], MAXED if rank >= most else CAN_LEARN if rank > 0 or learnable else LOCKED, 5)
	box.mouse_entered.connect(func() -> void:
		_hovered = id
		_show_tooltip(id))
	box.mouse_exited.connect(func() -> void:
		if _hovered == id:
			_hovered = 0
		_tooltip.show_lines([]))
	box.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_learn(id)
			get_viewport().set_input_as_handled())


func _learn(id: int) -> void:
	var problem := Talents.problem(GameState, id)
	if not problem.is_empty():
		Sfx.play("error")
		return
	var learned := Talents.learn(GameState, id)
	if learned.is_empty():
		return
	Sfx.play("level_up")
	Chat.system("You have learned %s." % learned)
	GameState.inventory_changed.emit()
	_queue_rebuild()


## The tooltip: name, rank, what the current rank does, what the next would,
## and what's still needed.
func _show_tooltip(id: int) -> void:
	var found := Talents.find(GameState.char_class, id)
	if found.is_empty():
		return
	var talent: Dictionary = found.talent
	var rank := Talents.rank(GameState, id)
	var most: int = talent.ranks.size()
	var lines: Array = [[Talents.name_of(talent), "Rank %d/%d" % [rank, most], Color.WHITE]]
	var problem := Talents.problem(GameState, id)
	if rank < most and not problem.is_empty() and problem != "No talent points left.":
		lines.append([problem, "", RED])
	if rank > 0:
		lines.append([_describe(int(talent.ranks[rank - 1])), "", DESCRIPTION])
	if rank < most:
		if rank > 0:
			lines.append(["Next rank:", "", Color.WHITE])
		lines.append([_describe(int(talent.ranks[rank])), "", DESCRIPTION])
		if problem.is_empty():
			lines.append(["Click to learn", "", CAN_LEARN])
	if not SpellDB.is_passive(SpellDB.get_spell(int(talent.ranks[0]))):
		lines.append(["Teaches an ability.", "", GREY])
	_tooltip.show_lines(lines)


func _describe(spell_id: int) -> String:
	var spell := SpellDB.get_spell(spell_id)
	var text := SpellText.describe(spell, GameState.level, _player.spells)
	return text if not text.is_empty() else "(No description yet.)"


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
