class_name MainMenuScreen
extends Control
## The main menu over its backdrop: the title, the column of entries and the version in a
## corner. It only asks — every entry emits a signal and the scene decides where it leads.
## Practice, the saved games, the options and the credits open on top; while one is open the
## entries behind it are out of reach, and when it closes the focus returns to its entry.

signal continue_requested(slot: String)
signal new_campaign_requested
signal load_requested(slot: String)
signal quick_battle_requested
## mode: PracticeMenu.JOUST, SIEGE, RAID or MERCHANT.
signal practice_requested(mode: StringName)
## The options changed the language; every text must be built again.
signal language_changed
signal quit_requested

const SIDE_MARGIN := 72.0
const CORNER_MARGIN := 20.0
const TITLE_GAP := 26
const TITLE_SLIDE := Vector2(-40.0, 0.0)
const TITLE_SECONDS := 0.6
const ENTRIES_DELAY := 0.25
const VEIL_SECONDS := 0.9
## Frames before the entrance plays: a scene's first frames are slow and would swallow it,
## and slides start from where the layout has put things.
const ENTRANCE_FRAMES := 3
## Darkening behind the text: where it holds and where it ends, as shares of the width.
const SHADE_STOPS: Array[float] = [0.0, 0.4, 0.78]
const SHADE_ALPHAS: Array[float] = [0.97, 0.88, 0.0]

var entries := MenuEntries.new()
var practice := PracticeMenu.new()
var slots := SaveSlotsScreen.new()
var options := OptionsScreen.new()
var credits := CreditsScreen.new()

## Hides the backdrop until the entrance lifts it, so the menu opens out of the dark.
var _veil := ColorRect.new()
var _frames := 0
var _title := MenuTitle.new()
var _column := VBoxContainer.new()
## Holds the entries and, in their place, the practice submenu.
var _body := VBoxContainer.new()
var _continue: Button
var _continue_info := CampaignStyle.label("", CampaignStyle.SMALL_SIZE - 1, UiPalette.MUTED)
var _options_entry: Button
## The entry whose screen is on top right now.
var _opened_by: Button = null


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.color = UiPalette.SHADE
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.visible = false
	add_child(_veil)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shade())
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_theme_constant_override("separation", TITLE_GAP)
	add_child(_column)
	_column.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_column.offset_left = SIDE_MARGIN
	_column.offset_right = SIDE_MARGIN
	_column.add_child(_title)
	_column.add_child(_body)
	_body.add_child(entries)
	_body.add_child(practice)
	_add_entries()
	add_child(_version())
	for screen: Control in [slots, options, credits]:
		add_child(screen)
	practice.chosen.connect(func(mode: StringName) -> void: practice_requested.emit(mode))
	practice.closed.connect(_on_top_closed)
	slots.load_requested.connect(func(slot: String) -> void: load_requested.emit(slot))
	slots.closed.connect(_on_slots_closed)
	options.language_changed.connect(func() -> void: language_changed.emit())
	options.closed.connect(_on_top_closed)
	credits.closed.connect(_on_top_closed)


func _ready() -> void:
	# The practice submenu is shorter; without this the title would jump when it opens.
	_body.custom_minimum_size.y = entries.get_combined_minimum_size().y
	refresh_saves()
	entries.focus_first()
	var animated := DisplayServer.get_name() != "headless"
	set_process(animated)
	if animated:
		_veil.visible = true
		_title.modulate.a = 0.0
		entries.modulate.a = 0.0


func _process(_delta: float) -> void:
	_frames += 1
	if _frames >= ENTRANCE_FRAMES:
		set_process(false)
		_play_entrance()


## Continue leads to the newest save and tells its round and date; without a save it is out
## of reach.
func refresh_saves() -> void:
	var slot := SaveGames.latest()
	_continue.disabled = slot.is_empty()
	_continue_info.text = tr("MENU_CONTINUE_NONE")
	if not slot.is_empty():
		_continue_info.text = SaveCaption.of(SaveGames.header(slot))
	entries.set_reachable(_opened_by == null)


func open_options() -> void:
	_open_on_top(_options_entry, options.open)


## The screens on top close themselves on Esc / B; this is the net below them, so that none
## of them can become a dead end.
func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event.is_action_pressed("ui_cancel"):
		return
	if slots.visible:
		get_viewport().set_input_as_handled()
		slots.close()
	elif options.visible:
		get_viewport().set_input_as_handled()
		options.close()


func _add_entries() -> void:
	_continue = entries.add_entry("continue", tr("MENU_CONTINUE"))
	_continue.pressed.connect(func() -> void: continue_requested.emit(SaveGames.latest()))
	_continue_info.name = "save_info"
	_continue_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_continue_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_continue_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_continue.add_child(_continue_info)
	_continue_info.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_continue_info.offset_right = -14.0
	var new_campaign := entries.add_entry("new_campaign", tr("MENU_NEW_CAMPAIGN"))
	new_campaign.pressed.connect(func() -> void: new_campaign_requested.emit())
	var load_game := entries.add_entry("load", tr("MENU_LOAD"))
	load_game.pressed.connect(
		_open_on_top.bind(load_game, func() -> void: slots.open(SaveSlotsScreen.Mode.LOAD))
	)
	var quick_battle := entries.add_entry("quick_battle", tr("MENU_QUICK_BATTLE"))
	quick_battle.pressed.connect(func() -> void: quick_battle_requested.emit())
	var practice_entry := entries.add_entry("practice", tr("MENU_PRACTICE"))
	practice_entry.pressed.connect(_open_on_top.bind(practice_entry, _open_practice))
	_options_entry = entries.add_entry("options", tr("MENU_OPTIONS"))
	_options_entry.pressed.connect(open_options)
	var credits_entry := entries.add_entry("credits", tr("MENU_CREDITS"))
	credits_entry.pressed.connect(_open_on_top.bind(credits_entry, credits.open))
	var quit := entries.add_entry("quit", tr("MENU_QUIT"))
	quit.pressed.connect(func() -> void: quit_requested.emit())


func _open_practice() -> void:
	entries.visible = false
	practice.open()


## Opens a screen on top of the entries. They go out of reach first, so the screen finds no
## focus to remember and the focus cannot wander behind it.
func _open_on_top(entry: Button, open: Callable) -> void:
	_opened_by = entry
	entries.set_reachable(false)
	open.call()


func _on_top_closed() -> void:
	entries.visible = true
	entries.set_reachable(true)
	if _opened_by != null and _opened_by.is_inside_tree():
		_opened_by.grab_focus()
	_opened_by = null


## Saves may have been deleted in the list.
func _on_slots_closed() -> void:
	_on_top_closed()
	refresh_saves()


func _play_entrance() -> void:
	var lift := create_tween()
	lift.tween_property(_veil, "modulate:a", 0.0, VEIL_SECONDS)
	lift.tween_callback(_veil.hide)
	UiMotion.slide_in(_title, TITLE_SLIDE, TITLE_SECONDS)
	entries.modulate.a = 1.0
	entries.play_entrance(ENTRIES_DELAY)


func _version() -> Label:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var label := CampaignStyle.label(
		tr("MENU_VERSION") % version, CampaignStyle.SMALL_SIZE, UiPalette.MUTED
	)
	label.name = "version"
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", UiPalette.INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		label.set_offset(side, -CORNER_MARGIN)
	return label


## Dark towards the left, where the text stands, and clear over the realm on the right.
static func _shade() -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(SHADE_STOPS)
	var colors := PackedColorArray()
	for alpha: float in SHADE_ALPHAS:
		colors.append(Color(UiPalette.SHADE, alpha))
	gradient.colors = colors
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 4
	var shade := TextureRect.new()
	shade.name = "shade"
	shade.texture = texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return shade
