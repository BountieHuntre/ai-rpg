class_name FrontEnd
extends Control
## The screens before the game: a pretend account login, character select and
## character creation. There's no server: any account name and password log in,
## and characters are the save files in the profile's characters/ folder.
## Layout is in units of 1/270 of the window height, like the HUD.

const GAME_SCENE := "res://scenes/main/main.tscn"
## Classic allows 10 characters per realm.
const MAX_CHARACTERS := 10
const REALM := "Greywater"
## Patch notes, newest first; the login screen shows the newest.
const PATCH_NOTES_PATH := "res://data/patch_notes.json"
const PATCH_NOTES_WIDTH := 140.0
const FONT_SIZE := 8
const TITLE_SIZE := 28
const GOLD := Color("ffd100")
const PANEL_COLOR := UiStyle.BACK
const BORDER_COLOR := UiStyle.GOLD
## Pretend server steps after Login, with how long each shows.
const LOGIN_STEPS := [["Connecting", 0.5], ["Authenticating", 0.6], ["Retrieving character list", 0.4]]

const RACE_TEXT := {
	ClassicData.Race.HUMAN: "Adaptable folk of the river kingdoms, at home in field and keep.",
	ClassicData.Race.ORC: "Hardy fighters from the badlands, proud and fierce in battle.",
	ClassicData.Race.DWARF: "Stout miners and smiths from the deep mountain halls.",
	ClassicData.Race.NIGHT_ELF: "Long-lived forest dwellers, quick and quiet.",
	ClassicData.Race.UNDEAD: "The risen dead who kept their wills, and walk on.",
	ClassicData.Race.TAUREN: "Tall, horned folk of the plains, strong and patient.",
	ClassicData.Race.GNOME: "Small tinkerers with sharp minds and quick hands.",
	ClassicData.Race.TROLL: "Lanky jungle hunters who heal fast and strike faster.",
}
const CLASS_TEXT := {
	ClassicData.CharClass.WARRIOR: "Fights up close in heavy armor, with weapon and shield.",
	ClassicData.CharClass.PALADIN: "A holy knight who heals, protects and smites.",
	ClassicData.CharClass.HUNTER: "Fights from range with bow or gun.",
	ClassicData.CharClass.ROGUE: "Strikes from the shadows with quick blades.",
	ClassicData.CharClass.PRIEST: "Heals allies with holy magic, or harms with shadow.",
	ClassicData.CharClass.SHAMAN: "Calls on earth, fire, water and air to heal and harm.",
	ClassicData.CharClass.MAGE: "Wields fire, frost and arcane power from afar.",
	ClassicData.CharClass.WARLOCK: "Bargains with dark powers for curses and flame.",
	ClassicData.CharClass.DRUID: "Changes shape and draws on nature to heal and fight.",
	ClassicData.CharClass.SPELLSWORD: "Writes spells into the blade: holds the line with wards, or cuts with fire, frost and storm.",
}
const NAME_STARTS := ["Al", "Bran", "Cor", "Dun", "El", "Fen", "Gar", "Hal", "Is", "Jor", "Kel", "Lor",
	"Mar", "Nor", "Os", "Per", "Quen", "Ros", "Sel", "Tor", "Ul", "Vor", "Wen", "Yr",
	"Ash", "Bel", "Cal", "Dar", "Ed", "Gil", "Har", "Ing", "Lyn", "Mer", "Od", "Rand", "Sten", "Tam", "Ward", "Ald"]
const NAME_ENDS := ["ric", "wyn", "dor", "mar", "eth", "ia", "on", "ald", "ra", "ith", "us", "en", "a", "os", "ell",
	"win", "ard", "da", "ford", "mund", "rid", "ana", "ley", "ton", "ise", "aric", "elm", "una"]

enum Screen { LOGIN, SELECT, CREATE }

## Set before changing to this scene to skip the login, as when logging out.
static var start_at_select := false

var _screen := Screen.LOGIN
var _ui_scale := 1.0

enum Anchor { TOP, BOTTOM, CENTER, STRETCH }
var _layer := Control.new()
var _modal: Control
var _settings := ConfigFile.new()
var _account := ""
var _remember := false
## Remembering the password keeps only its length: no server ever checks it,
## so the field is refilled with stand-in characters rather than saving what
## was typed.
var _remember_password := false
var _password_length := 0
var _characters: Array[Dictionary] = []
var _selected := 0
var _race := ClassicData.Race.HUMAN
var _class := ClassicData.CharClass.PALADIN
## The new character's look (HumanoidModel), for Humans.
var _look: Dictionary = {}
var _new_name := ""
## Set once Enter World starts loading, so it can't start twice.
var _entering := false
## The Options menu, over every screen.
var _options_menu := GameMenu.new()
## Looks for a newer release (released builds only), and installs it.
var _updater: Updater
## Shows the update's dialog again when the screen is rebuilt (resizing
## frees the old one); empty when there's none.
var _update_dialog := Callable()


func _ready() -> void:
	# Tests and `--save=` runs play one save file directly.
	if GameState.single_save:
		_enter_game.call_deferred()
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings.load(_settings_path())
	_remember = _settings.get_value("login", "remember", false)
	_account = _settings.get_value("login", "account", "") if _remember else ""
	_remember_password = _settings.get_value("login", "remember_password", false)
	_password_length = _settings.get_value("login", "password_length", 0) if _remember_password else 0
	_build_background()
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_layer)
	_options_menu.in_game = false
	add_child(_options_menu)
	get_viewport().size_changed.connect(_rebuild)
	Settings.changed.connect(func(key: String) -> void:
		if key == "ui_scale":
			_rebuild()
	)
	_screen = Screen.SELECT if start_at_select else Screen.LOGIN
	start_at_select = false
	if _screen == Screen.SELECT:
		_load_characters(_settings.get_value("characters", "last", ""))
	_rebuild()
	# Restarted by the reload command: straight back into the world.
	if not GameState.resume_name.is_empty():
		var resume := GameState.resume_name
		GameState.resume_name = ""
		_load_characters(resume)
		if _selected < _characters.size() and _characters[_selected].name == resume:
			_enter_world.call_deferred()
			return
	if Updater.should_check():
		_start_update_check()


func _build_background() -> void:
	var sky := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.05, 0.06, 0.14))
	gradient.set_color(1, Color(0.18, 0.1, 0.12))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	sky.texture = texture
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sky)
	# Embers drifting up from the bottom of the screen.
	var embers := CPUParticles2D.new()
	embers.amount = 60
	embers.lifetime = 9.0
	embers.preprocess = 9.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.direction = Vector2.UP
	embers.spread = 15.0
	embers.gravity = Vector2.ZERO
	embers.color = Color(1.0, 0.55, 0.2, 0.7)
	add_child(embers)
	var place_embers := func() -> void:
		var window := get_viewport_rect().size
		embers.position = Vector2(window.x / 2, window.y + 10)
		embers.emission_rect_extents = Vector2(window.x / 2, 4)
		embers.initial_velocity_min = window.y / 18.0
		embers.initial_velocity_max = window.y / 10.0
		embers.scale_amount_min = maxf(window.y / 400.0, 1.0)
		embers.scale_amount_max = maxf(window.y / 200.0, 2.0)
	get_viewport().size_changed.connect(place_embers)
	place_embers.call()


func _rebuild() -> void:
	_ui_scale = Settings.hud_scale(get_viewport_rect().size.y)
	theme = _make_theme()
	for child in _layer.get_children():
		# Renamed so the new screen's nodes get their names while these wait to be freed.
		child.name = "Old%d" % child.get_instance_id()
		child.queue_free()
	_modal = null
	match _screen:
		Screen.LOGIN:
			_build_login()
		Screen.SELECT:
			_build_select()
		Screen.CREATE:
			_build_create()
	if _update_dialog.is_valid():
		_update_dialog.call()


func _show_screen(screen: Screen) -> void:
	_screen = screen
	_rebuild()


# Login.

func _build_login() -> void:
	var title := _label(ProjectSettings.get_setting("application/config/name", ""), GOLD, TITLE_SIZE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(title, Vector2(0, 50), Vector2(_width(), 40), Anchor.CENTER)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", roundi(3 * _ui_scale))
	_place(form, Vector2(_width() / 2 - 60, 140), Vector2(120, 0), Anchor.CENTER)
	form.add_child(_label("Account Name", GOLD))
	var account := LineEdit.new()
	account.text = _account
	account.text_changed.connect(func(text: String) -> void: _account = text)
	form.add_child(account)
	form.add_child(_label("Account Password", GOLD))
	var password := LineEdit.new()
	password.secret = true
	password.text = "*".repeat(_password_length)
	form.add_child(password)
	var login := Button.new()
	login.text = "Login"
	form.add_child(login)
	var remember := CheckBox.new()
	OptionsWindow.style_check(remember, _ui_scale)
	remember.text = "Remember Account Name"
	remember.button_pressed = _remember
	remember.toggled.connect(func(on: bool) -> void: _remember = on)
	form.add_child(remember)
	var remember_password := CheckBox.new()
	OptionsWindow.style_check(remember_password, _ui_scale)
	remember_password.text = "Remember Password"
	remember_password.button_pressed = _remember_password
	remember_password.toggled.connect(func(on: bool) -> void: _remember_password = on)
	form.add_child(remember_password)
	var submit := func(_text := "") -> void: _login(password.text)
	login.pressed.connect(submit)
	account.text_submitted.connect(submit)
	password.text_submitted.connect(submit)
	# The game's version (x.y.z) is application/config/version in project.godot;
	# Windows exports take it too.
	var version := _label("Version %s" % ProjectSettings.get_setting("application/config/version", ""), Color(0.7, 0.7, 0.75))
	_place(version, Vector2(4, 258), Vector2(100, 10), Anchor.BOTTOM)
	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(get_tree().quit)
	_place(quit, Vector2(_width() - 54, 252), Vector2(50, 14), Anchor.BOTTOM)
	_add_options_button(Vector2(_width() - 54, 234))
	_add_patch_notes()
	var focus: Control = account if _account.is_empty() else login if not password.text.is_empty() else password
	focus.grab_focus.call_deferred()


## The latest patch's notes on the login screen's left: the first entry of
## data/patch_notes.json (newest first; every push adds one).
func _add_patch_notes() -> void:
	var entries: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATCH_NOTES_PATH))
	if not entries is Array or entries.is_empty():
		return
	var latest: Dictionary = entries[0]
	var panel := _panel()
	_place(panel, Vector2(8, 70), Vector2(PATCH_NOTES_WIDTH, 160), Anchor.STRETCH)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", roundi(3 * _ui_scale))
	panel.add_child(box)
	box.add_child(_label("Patch Notes", GOLD))
	box.add_child(_label("Version %s, %s" % [latest.get("version", ""), latest.get("date", "")], Color(0.7, 0.7, 0.75), FONT_SIZE - 2))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	# A scroll bar when the notes run past the panel: gold on dark, with room
	# between it and the text.
	var bar := scroll.get_v_scroll_bar()
	bar.custom_minimum_size.x = 5 * _ui_scale
	bar.add_theme_stylebox_override("scroll", _box(Color(0, 0, 0, 0.45), Color(0, 0, 0, 0), 0))
	for state: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var grab := _box(GOLD.darkened(0.45 if state == "grabber" else 0.2), Color(0, 0, 0, 0), 0)
		grab.set_corner_radius_all(roundi(2 * _ui_scale))
		bar.add_theme_stylebox_override(state, grab)
	var notes := VBoxContainer.new()
	notes.add_theme_constant_override("separation", roundi(3 * _ui_scale))
	notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gap := MarginContainer.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.add_theme_constant_override("margin_right", roundi(6 * _ui_scale))
	scroll.add_child(gap)
	gap.add_child(notes)
	for note: String in latest.get("notes", []):
		var line := _label("- " + note, Color(0.92, 0.9, 0.84), FONT_SIZE - 1)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size.x = (PATCH_NOTES_WIDTH - 22) * _ui_scale
		notes.add_child(line)


## There's no server: any account and password get in, after the usual steps.
func _login(password: String) -> void:
	if _account.strip_edges().is_empty():
		_show_modal("Please enter your account name.", ["OK"])
		return
	if password.is_empty():
		_show_modal("Please enter your password.", ["OK"])
		return
	_settings.set_value("login", "remember", _remember)
	_settings.set_value("login", "account", _account.strip_edges() if _remember else "")
	_settings.set_value("login", "remember_password", _remember_password)
	_settings.set_value("login", "password_length", password.length() if _remember_password else 0)
	_settings.save(_settings_path())
	for step: Array in LOGIN_STEPS:
		_show_modal(step[0], ["Cancel"])
		var cancelled := [false]
		_modal.get_meta("buttons")[0].pressed.connect(func() -> void: cancelled[0] = true)
		await get_tree().create_timer(step[1]).timeout
		if cancelled[0] or _screen != Screen.LOGIN:
			return
	_load_characters(_settings.get_value("characters", "last", ""))
	_show_screen(Screen.SELECT if not _characters.is_empty() else Screen.CREATE)


# Character select.

func _load_characters(select_name := "") -> void:
	_characters = GameState.list_characters()
	_selected = 0
	for i in _characters.size():
		if _characters[i].name == select_name:
			_selected = i


func _build_select() -> void:
	var realm := _label(REALM, GOLD, 12)
	realm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(realm, Vector2(0, 8), Vector2(_width(), 16))
	var list_panel := _panel()
	_place(list_panel, Vector2(_width() - 130, 30), Vector2(124, 200), Anchor.STRETCH)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", roundi(2 * _ui_scale))
	list_panel.add_child(list)
	var group := ButtonGroup.new()
	for i in _characters.size():
		var character := _characters[i]
		var entry := Button.new()
		entry.toggle_mode = true
		entry.button_group = group
		entry.button_pressed = i == _selected
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.text = "%s\nLevel %d %s %s" % [character.name, character.level,
			ClassicData.RACE_NAMES[character.race], ClassicData.CLASS_NAMES[character["class"]]]
		entry.pressed.connect(func() -> void:
			_selected = i
			_update_select_preview()
		)
		entry.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.double_click:
				_enter_world()
		)
		list.add_child(entry)
	var create := Button.new()
	create.text = "Create New Character"
	create.disabled = _characters.size() >= MAX_CHARACTERS
	create.pressed.connect(_start_create)
	_place(create, Vector2(_width() - 130, 234), Vector2(124, 14), Anchor.BOTTOM)
	# Down to just above Enter World.
	_add_preview(233)
	var name_label := _label("", GOLD, 12)
	name_label.name = "SelectedName"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(name_label, Vector2(_width() / 2 - 80, 30), Vector2(160, 16))
	var enter := Button.new()
	enter.text = "Enter World"
	enter.name = "EnterWorld"
	enter.add_theme_font_size_override("font_size", roundi(11 * _ui_scale))
	enter.pressed.connect(_enter_world)
	_place(enter, Vector2(_width() / 2 - 45, 236), Vector2(90, 20), Anchor.BOTTOM)
	var delete := Button.new()
	delete.text = "Delete Character"
	delete.name = "Delete"
	delete.pressed.connect(_confirm_delete)
	_place(delete, Vector2(_width() - 130, 252), Vector2(74, 14), Anchor.BOTTOM)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(func() -> void: _show_screen(Screen.LOGIN))
	_place(back, Vector2(_width() - 52, 252), Vector2(46, 14), Anchor.BOTTOM)
	_add_options_button(Vector2(6, 252))
	_update_select_preview()


func _update_select_preview() -> void:
	var has_character := _selected < _characters.size()
	var name_label: Label = _layer.get_node("SelectedName")
	name_label.text = _characters[_selected].name if has_character else ""
	_layer.get_node("EnterWorld").disabled = not has_character
	_layer.get_node("Delete").disabled = not has_character
	var preview: CharacterPreview = _layer.get_node("Preview")
	preview.visible = has_character
	if has_character:
		var character := _characters[_selected]
		preview.show_race(character.race, character.get("appearance", {}), character.get("equipment", {}))


func _enter_world() -> void:
	if _selected >= _characters.size() or _modal or _entering:
		return
	var character := _characters[_selected]
	if not GameState.select_character(character.path):
		_show_modal("Couldn't load %s." % character.name, ["OK"])
		return
	_settings.set_value("characters", "last", character.name)
	_settings.save(_settings_path())
	_entering = true
	LoadingScreen.enter(get_tree(), GAME_SCENE)


func _enter_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


## Classic makes you type DELETE to delete a character; here any case does.
func _confirm_delete() -> void:
	if _selected >= _characters.size():
		return
	var character := _characters[_selected]
	_show_modal("Do you want to permanently delete %s, level %d %s %s?\nType \"DELETE\" to confirm." % [
		character.name, character.level, ClassicData.RACE_NAMES[character.race],
		ClassicData.CLASS_NAMES[character["class"]]], ["Accept", "Cancel"])
	var confirm := LineEdit.new()
	confirm.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal.get_meta("box").add_child(confirm)
	_modal.get_meta("box").move_child(confirm, 1)
	confirm.grab_focus.call_deferred()
	var accept: Button = _modal.get_meta("buttons")[0]
	accept.disabled = true
	# Any case will do (classic wants capitals).
	confirm.text_changed.connect(func(text: String) -> void: accept.disabled = text.strip_edges().to_upper() != "DELETE")
	# Enter accepts, once the word is typed.
	confirm.text_submitted.connect(func(_text: String) -> void:
		if not accept.disabled:
			accept.pressed.emit()
	)
	accept.pressed.connect(func() -> void:
		GameState.delete_character(character.path)
		_load_characters()
		_rebuild()
	)


# Character creation.

func _start_create() -> void:
	_race = ClassicData.Race.HUMAN
	_class = ClassicData.CharClass.PALADIN
	_new_name = ""
	_look = HumanoidModel.random_appearance(randi())
	_show_screen(Screen.CREATE)


func _build_create() -> void:
	var races_panel := _panel()
	_place(races_panel, Vector2(6, 20), Vector2(110, 0))
	var races := VBoxContainer.new()
	races_panel.add_child(races)
	races.add_child(_label("Race", GOLD, 10))
	var race_group := ButtonGroup.new()
	for race: ClassicData.Race in ClassicData.RACE_NAMES:
		var button := Button.new()
		button.text = ClassicData.RACE_NAMES[race]
		button.toggle_mode = true
		button.button_group = race_group
		button.button_pressed = race == _race
		# Races without a model yet can't be made (ClassicData.PLAYABLE_RACES).
		button.disabled = not race in ClassicData.PLAYABLE_RACES
		button.tooltip_text = "Coming in a later update." if button.disabled else ""
		button.pressed.connect(func() -> void:
			_race = race
			if not ClassicData.is_playable(_race, _class):
				_class = _first_allowed_class()
			_rebuild()
		)
		races.add_child(button)
	var race_text := _label(RACE_TEXT[_race], Color.WHITE)
	race_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	races.add_child(race_text)
	var classes_panel := _panel()
	_place(classes_panel, Vector2(_width() - 116, 20), Vector2(110, 0))
	var classes := VBoxContainer.new()
	classes_panel.add_child(classes)
	classes.add_child(_label("Class", GOLD, 10))
	var class_group := ButtonGroup.new()
	for char_class: ClassicData.CharClass in ClassicData.CLASS_NAMES:
		var button := Button.new()
		button.text = ClassicData.CLASS_NAMES[char_class]
		button.toggle_mode = true
		button.button_group = class_group
		button.button_pressed = char_class == _class
		button.disabled = not ClassicData.is_playable(_race, char_class)
		if not char_class in SpellDB.classes_with_spells():
			button.tooltip_text = "Coming in a later update."
		elif button.disabled:
			button.tooltip_text = "Not available to %s characters." % ClassicData.RACE_NAMES[_race]
		button.pressed.connect(func() -> void:
			_class = char_class
			_rebuild()
		)
		classes.add_child(button)
	var class_text := CLASS_TEXT[_class] as String
	var class_label := _label(class_text, Color.WHITE)
	class_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	classes.add_child(class_label)
	# Down to just above the name box.
	_add_preview(211)
	_layer.get_node("Preview").show_race(_race, _look, CharacterPreview.kit_equipment(_race, _class))
	if _race == ClassicData.Race.HUMAN:
		_build_appearance()
	var title := _label("%s %s" % [ClassicData.RACE_NAMES[_race], ClassicData.CLASS_NAMES[_class]], GOLD, 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(title, Vector2(_width() / 2 - 80, 20), Vector2(160, 16))
	var name_row := HBoxContainer.new()
	_place(name_row, Vector2(_width() / 2 - 70, 214), Vector2(140, 14), Anchor.BOTTOM)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Name"
	name_edit.max_length = GameState.NAME_MAX
	name_edit.text = _new_name
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(text: String) -> void: _new_name = text)
	name_edit.text_submitted.connect(func(_text: String) -> void: _accept_create())
	name_row.add_child(name_edit)
	var random := Button.new()
	random.text = "Random"
	random.pressed.connect(func() -> void:
		_new_name = _random_name()
		name_edit.text = _new_name
	)
	name_row.add_child(random)
	var accept := Button.new()
	accept.text = "Accept"
	accept.add_theme_font_size_override("font_size", roundi(11 * _ui_scale))
	accept.pressed.connect(_accept_create)
	_place(accept, Vector2(_width() / 2 - 45, 236), Vector2(90, 20), Anchor.BOTTOM)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(func() -> void:
		_load_characters()
		_show_screen(Screen.SELECT if not _characters.is_empty() else Screen.LOGIN)
	)
	_place(back, Vector2(6, 252), Vector2(46, 14), Anchor.BOTTOM)
	name_edit.grab_focus.call_deferred()


## Body and look choices for the model, at the preview's lower left, as
## classic's arrows: Male and Female, then each choice with < and >.
func _build_appearance() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", roundi(2 * _ui_scale))
	var bodies := HBoxContainer.new()
	var body_group := ButtonGroup.new()
	for i in 2:
		var button := Button.new()
		button.text = ["Male", "Female"][i]
		button.toggle_mode = true
		button.button_group = body_group
		button.button_pressed = int(_look.body) == i
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			_look.body = i
			_look = HumanoidModel.clean_appearance(_look)
			_rebuild()
		)
		bodies.add_child(button)
	box.add_child(bodies)
	var choices := [["skin", "Skin", HumanoidModel.SKIN_COLORS.size()],
		["hair", "Hair", HumanoidModel.HAIR_STYLES[int(_look.body)].size()],
		["hair_color", "Hair Color", HumanoidModel.HAIR_COLORS.size()]]
	if HumanoidModel.FACES[int(_look.body)].size() > 1:
		choices.append(["face", "Beard", HumanoidModel.FACES[int(_look.body)].size()])
	for choice in choices:
		var row := HBoxContainer.new()
		for step in [-1, 1]:
			var arrow := Button.new()
			arrow.text = "<" if step < 0 else ">"
			arrow.pressed.connect(func() -> void:
				_look[choice[0]] = posmod(int(_look[choice[0]]) + step, int(choice[2]))
				_layer.get_node("Preview").show_race(_race, _look, CharacterPreview.kit_equipment(_race, _class))
			)
			row.add_child(arrow)
			if step < 0:
				var label := _label(choice[1], Color.WHITE)
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(label)
		box.add_child(row)
	var random := Button.new()
	random.text = "Randomize"
	random.pressed.connect(func() -> void:
		_look = HumanoidModel.random_appearance(randi())
		_rebuild()
	)
	box.add_child(random)
	_place(box, Vector2(_width() / 2 - 150, 128), Vector2(80, 80), Anchor.BOTTOM)


func _first_allowed_class() -> ClassicData.CharClass:
	for char_class: ClassicData.CharClass in ClassicData.CLASS_NAMES:
		if ClassicData.is_playable(_race, char_class):
			return char_class
	return ClassicData.CharClass.WARRIOR


func _random_name() -> String:
	for attempt in 20:
		var name: String = NAME_STARTS.pick_random() + NAME_ENDS.pick_random()
		if GameState.check_name(name).is_empty():
			return name
	return ""


func _accept_create() -> void:
	if _modal:
		return
	var look := _look if _race == ClassicData.Race.HUMAN else {}
	var error := GameState.create_character(_new_name, _race, _class, look)
	if not error.is_empty():
		_show_modal(error, ["OK"])
		return
	_load_characters(GameState.char_name)
	_show_screen(Screen.SELECT)


# Building blocks.

func _settings_path() -> String:
	return GameState.profile_dir.path_join("settings.cfg")


func _width() -> float:
	return get_viewport_rect().size.x / _ui_scale


## Screens are laid out 270 units tall. At a smaller UI Scale there's more
## height than that: this much more.
func _extra_height() -> float:
	return maxf(get_viewport_rect().size.y / _ui_scale - 270.0, 0.0)


## Places a control at a position and size in layout units. `anchor` says
## where it goes when the screen is taller than 270 units: TOP stays put,
## BOTTOM keeps its distance from the bottom, CENTER moves halfway, and
## STRETCH stays at the top and grows to take the extra height.
func _place(control: Control, at: Vector2, size_units: Vector2, anchor := Anchor.TOP) -> void:
	var extra := _extra_height()
	match anchor:
		Anchor.BOTTOM:
			at.y += extra
		Anchor.CENTER:
			at.y += extra / 2.0
		Anchor.STRETCH:
			size_units.y += extra
	control.position = at * _ui_scale
	control.size = size_units * _ui_scale
	_layer.add_child(control)


## The character model, from under the name at the top down to `bottom` (in
## layout units, kept at that distance from the bottom of the screen), so the
## feet stand just above the buttons there.
func _add_preview(bottom: float) -> void:
	var preview := CharacterPreview.new()
	preview.name = "Preview"
	preview.pixel_scale = maxi(roundi(_ui_scale), 1)
	var top := 48.0
	var height := bottom + _extra_height() - top
	_place(preview, Vector2(_width() / 2 - height * 0.45, top), Vector2(height * 0.9, height))


func _label(text: String, color: Color, font_size := FONT_SIZE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", roundi(font_size * _ui_scale))
	return label


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(PANEL_COLOR, BORDER_COLOR, 4))
	return panel


func _box(fill: Color, border: Color, margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(maxi(roundi(_ui_scale / 2), 1))
	style.set_content_margin_all(margin * _ui_scale)
	style.set_corner_radius_all(roundi(_ui_scale))
	return style


func _make_theme() -> Theme:
	var made := Theme.new()
	made.default_font_size = roundi(FONT_SIZE * _ui_scale)
	made.set_stylebox("normal", "Button", _box(UiStyle.BUTTON, UiStyle.GOLD, 2))
	made.set_stylebox("hover", "Button", _box(UiStyle.BUTTON_HOVER, UiStyle.GOLD_BRIGHT, 2))
	made.set_stylebox("pressed", "Button", _box(UiStyle.BUTTON_PRESSED, UiStyle.GOLD, 2))
	made.set_stylebox("disabled", "Button", _box(Color(0.15, 0.13, 0.13), Color(0.35, 0.35, 0.35), 2))
	made.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	made.set_color("font_color", "Button", GOLD)
	made.set_color("font_hover_color", "Button", Color.WHITE)
	made.set_color("font_pressed_color", "Button", Color.WHITE)
	made.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	made.set_color("font_disabled_color", "Button", Color(0.45, 0.45, 0.45))
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		made.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())
	made.set_stylebox("normal", "LineEdit", _box(Color(0, 0, 0, 0.75), BORDER_COLOR, 3))
	made.set_stylebox("focus", "LineEdit", _box(Color(0, 0, 0, 0.75), GOLD, 3))
	return made


## A centered message box with buttons; every button closes it.
## Its "box" meta is the VBox to add to, "buttons" the buttons in order.
func _show_modal(text: String, buttons: Array) -> void:
	_close_modal()
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(shade)
	var panel := _panel()
	panel.custom_minimum_size = Vector2(160, 0) * _ui_scale
	shade.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", roundi(4 * _ui_scale))
	panel.add_child(box)
	var message := _label(text, Color.WHITE)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size.x = 150 * _ui_scale
	box.add_child(message)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var made: Array[Button] = []
	for text_on_button: String in buttons:
		var button := Button.new()
		button.text = text_on_button
		button.custom_minimum_size.x = 50 * _ui_scale
		button.pressed.connect(_close_modal)
		row.add_child(button)
		made.append(button)
	if not made.is_empty():
		made[0].grab_focus.call_deferred()
	shade.set_meta("box", box)
	shade.set_meta("buttons", made)
	_modal = shade
	# Center once the panel knows its size.
	var center := func() -> void:
		panel.position = (get_viewport_rect().size - panel.size) / 2
	panel.resized.connect(center)
	center.call_deferred()


# Updates.

func _start_update_check() -> void:
	_updater = Updater.new()
	add_child(_updater)
	_updater.found.connect(_on_update_found)
	_updater.progress.connect(_on_update_progress)
	_updater.failed.connect(_on_update_failed)
	_updater.ready_to_restart.connect(_on_update_ready)
	_updater.check()


## A newer release: asks, once the screen is free of other dialogs (the
## login's steps), unless the player skipped this version.
func _on_update_found(version: String, size: int) -> void:
	if _settings.get_value("update", "skipped", "") == version:
		return
	while _modal != null or _entering:
		if _entering:
			return
		await get_tree().create_timer(0.5).timeout
	_update_dialog = _show_update_prompt.bind(version, size)
	_update_dialog.call()
	if Updater.auto_accept():
		_accept_update.call_deferred(version)


func _show_update_prompt(version: String, size: int) -> void:
	var installs := _updater.can_install()
	var text := "Version %s is available (you have %s)." % [version, Updater.current_version()]
	if installs:
		text += "
Download and install it now?" + (" (%d MB)" % roundi(size / 1048576.0) if size > 0 else "")
	else:
		text += "
Open the download page?"
	_show_modal(text, ["Update" if installs else "Download Page", "Later", "Skip This Version"])
	var buttons: Array = _modal.get_meta("buttons")
	buttons[0].pressed.connect(_accept_update.bind(version))
	buttons[1].pressed.connect(func() -> void: _update_dialog = Callable())
	buttons[2].pressed.connect(func() -> void:
		_update_dialog = Callable()
		_settings.set_value("update", "skipped", version)
		_settings.save(_settings_path())
	)
	buttons[2].custom_minimum_size.x = 70 * _ui_scale


func _accept_update(version: String) -> void:
	if not _updater.can_install():
		_update_dialog = Callable()
		_updater.open_page()
		return
	_update_dialog = _show_update_download.bind(version)
	_update_dialog.call()
	_updater.download()


func _show_update_download(version: String) -> void:
	_show_modal("Downloading version %s..." % version, ["Cancel"])
	_modal.set_meta("version", version)
	_modal.get_meta("buttons")[0].pressed.connect(func() -> void:
		_update_dialog = Callable()
		_updater.cancel()
	)


func _on_update_progress(fraction: float) -> void:
	if _modal and _modal.has_meta("version"):
		var message: Label = _modal.get_meta("box").get_child(0)
		message.text = "Downloading version %s... %d%%" % [_modal.get_meta("version"), roundi(fraction * 100.0)]


func _on_update_failed(message: String) -> void:
	_update_dialog = Callable()
	_show_modal(message + "
Open the download page instead?", ["Download Page", "Close"])
	_modal.get_meta("buttons")[0].pressed.connect(_updater.open_page)


## The new files wait for the game to close: the install script copies them
## in and starts the game again.
func _on_update_ready() -> void:
	_update_dialog = Callable()
	_show_modal("Installing the update. The game will start again in a moment.", [])
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()


func _close_modal() -> void:
	if _modal:
		_modal.queue_free()
		_modal = null


func _add_options_button(at: Vector2) -> void:
	var options := Button.new()
	options.text = "Options"
	options.pressed.connect(func() -> void:
		# Out of the login fields, so typing doesn't go into them behind the menu.
		get_viewport().gui_release_focus()
		_options_menu.toggle()
	)
	_place(options, at, Vector2(50, 14), Anchor.BOTTOM)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	if _options_menu.visible:
		# Esc backs out of the options; other keys wait until it's closed.
		if event.keycode == KEY_ESCAPE:
			_options_menu.toggle()
		get_viewport().set_input_as_handled()
		return
	if _modal:
		if event.keycode == KEY_ESCAPE:
			_close_modal()
		return
	match _screen:
		Screen.SELECT:
			if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
				_enter_world()
			elif event.keycode in [KEY_UP, KEY_DOWN] and not _characters.is_empty():
				_selected = wrapi(_selected + (1 if event.keycode == KEY_DOWN else -1), 0, _characters.size())
				_rebuild()
			elif event.keycode == KEY_ESCAPE:
				_show_screen(Screen.LOGIN)
		Screen.CREATE:
			if event.keycode == KEY_ESCAPE:
				_load_characters()
				_show_screen(Screen.SELECT if not _characters.is_empty() else Screen.LOGIN)
		Screen.LOGIN:
			if event.keycode == KEY_ESCAPE:
				get_tree().quit()
