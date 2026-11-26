class_name TradeSkillWindow
extends Control
## Classic's trade skill window (TradeSkillFrame), opened by a profession's
## spell (Smelting, Enchanting: SPELL_EFFECT_TRADE_SKILL): your skill, the
## recipes you know coloured by how likely they are to raise it (orange,
## yellow, green, grey), how many you can make of each, and the one picked:
## what it makes, the forge or tools it needs and its reagents (have / need).
## Create makes one (a cast of the recipe's spell, Crafting), Create All as
## many as the count says. "Have Materials" shows only what you can make.
## Sizes are in HUD units (1/270 of the window height), times ui_scale.

signal message(text: String, is_error: bool)
signal hovered(item: Dictionary)
## A recipe's own icon (an enchant's) is under the mouse: its spell tooltip.
signal spell_hovered(spell_id: int)
## An enchant recipe wants the item it goes on picked (the HUD has the bags).
signal pick_requested(recipe_id: int, times: int)

static var WIDTH := 190.0
const LIST_HEIGHT := 96.0
static var ROW := 10.0
static var FONT_SIZE := 6
const SELECTED := Color(1, 1, 1, 0.12)
static var ICON := 14.0
const COLORS := CombatHud.DIFFICULTY_COLORS

var profession := ""
var _player: Player
var _ui_scale := 1.0
var _selected := 0
var _have_materials := false
var _count := 1
## Recipes left to make in this Create All, and the one being made.
var _queue := 0
var _making := 0
var _rows: Array[int] = []
## What's drawn, kept to update in place rather than rebuilt: the skill bar,
## the recipe rows ({ id, row, label }), the details of the recipe picked
## (its own box, redone only when another is picked) and the labels in it
## that change with what's in the bags ([kind, id or pair, label]).
var _list_scroll: ScrollContainer
var _list: VBoxContainer
var _skill_fill: ColorRect
var _skill_text: Label
var _row_views: Array[Dictionary] = []
var _empty_text: Label
var _details_box: Control
var _live: Array = []
var _focus_check := 0.0


func open(name: String, player: Player, ui_scale: float) -> void:
	if visible and profession == name:
		close()
		return
	profession = name
	_player = player
	_ui_scale = ui_scale
	_selected = 0
	visible = true
	_build()


func close() -> void:
	visible = false
	_queue = 0
	hovered.emit({})


func _ready() -> void:
	# Bags and skill changing (a recipe made, a skill-up) only update what
	# shows them.
	GameState.inventory_changed.connect(func() -> void:
		if visible:
			_refresh.call_deferred())
	GameState.professions_changed.connect(func() -> void:
		if visible:
			_refresh.call_deferred())


func _process(delta: float) -> void:
	# Walking to or from a forge recolours its line.
	_focus_check -= delta
	if _focus_check <= 0.0 and visible:
		_focus_check = 0.5
		_update_live(true)


func _recipes() -> Array[int]:
	var found: Array[int] = []
	for id in ProfessionDB.recipes_of(profession):
		if id in GameState.known_spells:
			found.append(id)
	# By the skill they need, highest first, as classic lists them.
	found.sort_custom(func(a: int, b: int) -> bool:
		var sa := int(ProfessionDB.recipe(a).skill)
		var sb := int(ProfessionDB.recipe(b).skill)
		return sa > sb if sa != sb else a < b)
	return found


## The recipes the list shows: all known, or (Have Materials) those you can
## make.
func _shown() -> Array[int]:
	var shown: Array[int] = []
	for id in _recipes():
		if not _have_materials or Crafting.can_make(_player, id) > 0:
			shown.append(id)
	return shown


## The whole window, once on opening (and on a new UI scale).
func _build() -> void:
	for child in get_children():
		child.queue_free()
	_row_views.clear()
	var height := 14 + 12 + LIST_HEIGHT + 96
	size = Vector2(WIDTH, height) * _ui_scale
	UiStyle.panel(self, Vector2(WIDTH, height), _ui_scale)
	var spell_name := str(SpellDB.get_spell(_window_spell()).get("SpellName", Professions.title(profession)))
	UiStyle.title(self, Vector2(5, 1.5), spell_name, _ui_scale)
	UiStyle.close_button(self, Vector2(WIDTH - 10, 2), _ui_scale, close)
	# The skill bar.
	var trough := ColorRect.new()
	trough.color = Color(0.05, 0.05, 0.08)
	trough.position = Vector2(6, 15) * _ui_scale
	trough.size = Vector2(WIDTH - 70, 7) * _ui_scale
	add_child(trough)
	_skill_fill = ColorRect.new()
	_skill_fill.color = Color(0.2, 0.35, 0.8)
	trough.add_child(_skill_fill)
	_skill_text = _text(trough, Vector2(0, -0.5), "", Color.WHITE, FONT_SIZE - 1)
	_skill_text.size.x = (WIDTH - 70) * _ui_scale
	_skill_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var filter := CheckBox.new()
	filter.text = "Have Materials"
	filter.button_pressed = _have_materials
	filter.add_theme_font_size_override("font_size", roundi((FONT_SIZE - 1) * _ui_scale))
	filter.position = Vector2(WIDTH - 62, 12) * _ui_scale
	filter.toggled.connect(func(on: bool) -> void:
		_have_materials = on
		_selected = 0
		_fill_list())
	add_child(filter)
	# The recipes.
	_list_scroll = ScrollContainer.new()
	_list_scroll.position = Vector2(2, 26) * _ui_scale
	_list_scroll.size = Vector2(WIDTH - 4, LIST_HEIGHT) * _ui_scale
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_list_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 0)
	_list.custom_minimum_size.x = (WIDTH - 12) * _ui_scale
	_list_scroll.add_child(_list)
	_empty_text = _text(self, Vector2(6, 30), "", Color(0.7, 0.7, 0.7), FONT_SIZE)
	_details_box = Control.new()
	_details_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_details_box)
	_build_buttons()
	_update_skill()
	_fill_list()


## The recipe rows, made again only when which recipes show changes (one
## learned, the Have Materials filter).
func _fill_list() -> void:
	for view: Dictionary in _row_views:
		(view.row as Node).queue_free()
	_row_views.clear()
	_rows = _shown()
	for index in _rows.size():
		var id := _rows[index]
		var row := ColorRect.new()
		row.color = Color.TRANSPARENT
		row.custom_minimum_size = Vector2(WIDTH - 12, ROW) * _ui_scale
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		_list.add_child(row)
		var label := _text(row, Vector2(3, 0.5), "", Color.WHITE, FONT_SIZE)
		_row_views.append({ "id": id, "row": row, "label": label })
		row.gui_input.connect(func(event: InputEvent) -> void:
			var button := event as InputEventMouseButton
			if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
				_select(index))
	_empty_text.text = "" if not _rows.is_empty() else ("You know no recipes you can make." if _have_materials else "You know no recipes.")
	_update_rows()
	_select(clampi(_selected, 0, maxi(_rows.size() - 1, 0)))


## Bags or skill changed: the skill bar, each row's colour and count, and
## the picked recipe's have/need, in place; the rows again only if which
## recipes show has changed.
func _refresh() -> void:
	if _list == null or not is_instance_valid(_list):
		return
	_update_skill()
	if _shown() != _rows:
		var picked := _rows[_selected] if _selected < _rows.size() else 0
		_fill_list()
		if picked in _rows:
			_select(_rows.find(picked))
		return
	_update_rows()
	_update_live(false)


func _update_skill() -> void:
	var value := Professions.value(GameState, profession)
	var most := Professions.max_value(GameState, profession)
	_skill_fill.size = Vector2((WIDTH - 70) * clampf(value / float(maxi(most, 1)), 0, 1), 7) * _ui_scale
	_skill_text.text = "%s %d/%d" % [Professions.title(profession), value, most]


func _update_rows() -> void:
	var value := Professions.value(GameState, profession)
	for view: Dictionary in _row_views:
		var id: int = view.id
		var can := Crafting.can_make(_player, id)
		var label: Label = view.label
		label.text = SpellDB.full_name(SpellDB.get_spell(id)) + (" [%d]" % can if can > 0 else "")
		label.add_theme_color_override("font_color", COLORS[Professions.recipe_color(value, ProfessionDB.recipe(id))])


func _select(index: int) -> void:
	_selected = index
	for i in _row_views.size():
		(_row_views[i].row as ColorRect).color = SELECTED if i == index else Color.TRANSPARENT
	_show_details()


## The picked recipe: what it makes, what it needs. Only this box is made
## again when another recipe is picked.
func _show_details() -> void:
	for child in _details_box.get_children():
		child.queue_free()
	_live.clear()
	if _rows.is_empty():
		return
	var id := _rows[_selected]
	var top := 28 + LIST_HEIGHT
	var recipe := ProfessionDB.recipe(id)
	var spell := SpellDB.get_spell(id)
	var makes: Array = recipe.get("makes", [])
	var icon := ColorRect.new()
	icon.position = Vector2(6, top + 2) * _ui_scale
	icon.size = Vector2.ONE * ICON * _ui_scale
	_details_box.add_child(icon)
	if not makes.is_empty():
		var item := ItemDB.get_item(int(makes[0]))
		UiStyle.item_icon(icon, item, _ui_scale)
		if int(makes[1]) > 1:
			UiStyle.count_label(icon, int(makes[1]), _ui_scale)
		icon.mouse_entered.connect(func() -> void: hovered.emit(item))
		icon.mouse_exited.connect(func() -> void: hovered.emit({}))
	else:
		# An enchant's icon: the recipe's tooltip, what it does.
		UiStyle.spell_icon(icon, id, _ui_scale)
		icon.mouse_entered.connect(func() -> void: spell_hovered.emit(id))
		icon.mouse_exited.connect(func() -> void: hovered.emit({}))
	_text(_details_box, Vector2(24, top + 1), SpellDB.full_name(spell), Color(1, 0.82, 0.3), FONT_SIZE)
	var y := top + 9.0
	var focus := int(recipe.get("focus", 0))
	if focus != 0:
		var focus_label := _text(_details_box, Vector2(24, y), "Requires: %s" % str(ProfessionDesigns.FOCUS.get(focus, "Forge")).capitalize(), Color.WHITE, FONT_SIZE - 1)
		_live.append(["focus", focus, focus_label])
		y += 8.0
	for tool: Variant in recipe.get("tools", []):
		var tool_label := _text(_details_box, Vector2(24, y), "Requires: %s" % ItemDB.get_item(int(tool)).get("name", "a tool"), Color.WHITE, FONT_SIZE - 1)
		_live.append(["tool", int(tool), tool_label])
		y += 8.0
	if recipe.has("enchant"):
		_text(_details_box, Vector2(24, y), Enchanting.line(int(recipe.enchant)), Enchanting.ENCHANT_COLOR, FONT_SIZE - 1)
		y += 8.0
	y = maxf(y, top + 20.0)
	_text(_details_box, Vector2(6, y), "Reagents:", Color(1, 0.82, 0.3), FONT_SIZE - 1)
	y += 8.0
	var reagents: Array = recipe.get("reagents", [])
	for i in reagents.size():
		var pair: Array = reagents[i]
		var item := ItemDB.get_item(int(pair[0]))
		var at := Vector2(6 + (i % 2) * (WIDTH / 2.0 - 4), y + floori(i / 2.0) * (ICON + 2))
		var box := ColorRect.new()
		box.position = at * _ui_scale
		box.size = Vector2.ONE * ICON * _ui_scale
		_details_box.add_child(box)
		UiStyle.item_icon(box, item, _ui_scale)
		box.mouse_entered.connect(func() -> void: hovered.emit(item))
		box.mouse_exited.connect(func() -> void: hovered.emit({}))
		_text(_details_box, at + Vector2(ICON + 2, 0), str(item.get("name", "?")), Color.WHITE, FONT_SIZE - 1)
		var have_label := _text(_details_box, at + Vector2(ICON + 2, 7), "", Color.WHITE, FONT_SIZE - 1)
		_live.append(["reagent", pair, have_label])
	_update_live(true)


## The details' labels that follow the bags (have/need, tools) and, with
## `focus`, where you stand (the forge).
func _update_live(focus: bool) -> void:
	for entry: Array in _live:
		var label: Label = entry[2]
		if not is_instance_valid(label):
			continue
		match str(entry[0]):
			"reagent":
				var pair: Array = entry[1]
				var have := Inventory.count_item(int(pair[0]))
				label.text = "%d/%d" % [have, int(pair[1])]
				label.add_theme_color_override("font_color", Color.WHITE if have >= int(pair[1]) else COLORS.red)
			"tool":
				label.add_theme_color_override("font_color", Color.WHITE if Inventory.count_item(int(entry[1])) > 0 else COLORS.red)
			"focus":
				if focus:
					var near := World.current != null and World.current.spell_focus_near(int(entry[1]), _player.global_position)
					label.add_theme_color_override("font_color", Color.WHITE if near else COLORS.red)


## Create, the count and Create All along the bottom, made once; they act on
## whichever recipe is picked.
func _build_buttons() -> void:
	var bottom := size.y / _ui_scale - 14.0
	var picked := func() -> int: return _rows[_selected] if _selected < _rows.size() else 0
	var create_all := _button("Create All", Vector2(6, bottom), Vector2(40, 11))
	var count := LineEdit.new()
	create_all.pressed.connect(func() -> void:
		if picked.call() == 0:
			return
		_count = maxi(Crafting.can_make(_player, picked.call()), 1)
		count.text = str(_count)
		_make(picked.call(), _count))
	var minus := _button("-", Vector2(WIDTH - 94, bottom), Vector2(10, 11))
	count.text = str(_count)
	count.alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override("font_size", roundi((FONT_SIZE - 1) * _ui_scale))
	count.position = Vector2(WIDTH - 83, bottom) * _ui_scale
	count.size = Vector2(20, 11) * _ui_scale
	count.text_changed.connect(func(text: String) -> void: _count = clampi(int(text), 1, 999) if text.is_valid_int() else 1)
	count.focus_entered.connect(func() -> void: _player.typing = true)
	count.focus_exited.connect(func() -> void: _player.typing = false)
	add_child(count)
	var plus := _button("+", Vector2(WIDTH - 62, bottom), Vector2(10, 11))
	minus.pressed.connect(func() -> void:
		_count = maxi(_count - 1, 1)
		count.text = str(_count))
	plus.pressed.connect(func() -> void:
		_count = mini(_count + 1, 999)
		count.text = str(_count))
	var create := _button("Create", Vector2(WIDTH - 48, bottom), Vector2(42, 11))
	create.pressed.connect(func() -> void:
		if picked.call() != 0:
			_make(picked.call(), _count))


## Makes `times` of a recipe, one cast after another; any problem stops it.
func _make(id: int, times: int) -> void:
	# An enchant goes on an item the player picks first.
	if ProfessionDB.recipe(id).has("enchant"):
		var why := Crafting.problem(_player, id, {})
		if why != "You must pick an item.":
			message.emit(why, true)
			return
		pick_requested.emit(id, times)
		return
	_queue = times
	_making = id
	_next()


func _next() -> void:
	if _queue <= 0 or not is_instance_valid(_player):
		return
	_queue -= 1
	var problem := Crafting.start(_player, _making, func() -> void:
		_next.call_deferred())
	if not problem.is_empty():
		_queue = 0
		message.emit(problem, true)


## The spell this profession's window is named for: Smelting for Mining,
## the profession itself for Enchanting.
func _window_spell() -> int:
	for id: Variant in ProfessionDB.profession(profession).get("start", []):
		if SpellDB.has_effect(SpellDB.get_spell(int(id)), Crafting.EFFECT_TRADE_SKILL):
			return int(id)
	var rank := Professions.rank_of(GameState, profession)
	return int(Professions.ranks(profession)[maxi(rank, 1) - 1].spell)


func _button(text: String, at: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", roundi((FONT_SIZE - 1) * _ui_scale))
	button.position = at * _ui_scale
	button.size = button_size * _ui_scale
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
