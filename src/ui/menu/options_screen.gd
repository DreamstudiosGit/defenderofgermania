class_name OptionsScreen
extends Control
## The player's options (App.settings) as a modal over the main menu or the pause menu:
## video, audio, game and controls. Changes apply at once and are saved when it closes.
## LB / RB and PageUp / PageDown switch the tabs, Esc / B goes back, and the line under the
## tabs describes the row that has focus. It keeps working while the tree is paused.

signal closed
## The language changed; the caller rebuilds its screen (texts are set when a screen is built).
signal language_changed

const BACKDROP_ALPHA := 0.8
const PAGE_NAMES: Array[String] = ["video", "audio", "game", "controls"]
const TAB_TEXTS: Array[String] = [
	"OPTIONS_TAB_VIDEO", "OPTIONS_TAB_AUDIO", "OPTIONS_TAB_GAME", "OPTIONS_TAB_CONTROLS",
]
## Room for a description of two lines (21 px each, 3 px between), so the panel keeps its
## size and the longer German texts are not cut off.
const HINT_HEIGHT := 45.0
## Smaller than the other screens' titles: the panel has to fit 720 lines at the largest UI
## scale too.
const TITLE_SIZE := 30

## The language can only change where the caller can rebuild everything: in the main menu.
var allow_language := true
## The options to edit: App.settings unless a test hands in its own.
var settings: UserSettings = null

var _title := CampaignStyle.title("", TITLE_SIZE)
var _tabs := TabContainer.new()
var _hint := CampaignStyle.paragraph()
var _prompt := CampaignStyle.label("", CampaignStyle.SMALL_SIZE, CampaignStyle.MUTED)
var _reset := Button.new()
var _back := Button.new()
var _controls: ControlsSection = null
var _focus_before: Control = null
var _language_before := ""


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var column := CampaignStyle.modal(self, Color(UiPalette.SHADE, BACKDROP_ALPHA))
	column.add_theme_constant_override("separation", 8)
	column.add_child(_title)
	_tabs.name = "tabs"
	_tabs.use_hidden_tabs_for_min_size = true
	# No side margins: the rows line up with the tab bar and the description below.
	_tabs.add_theme_stylebox_override("panel", GameTheme.box(Color.TRANSPARENT, 0, 0, 6))
	_tabs.add_theme_constant_override("side_margin", 0)
	_tabs.tab_changed.connect(_on_tab_changed)
	column.add_child(_tabs)
	column.add_child(HSeparator.new())
	_hint.name = "hint"
	_hint.custom_minimum_size.y = HINT_HEIGHT
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# A wrapping label asks for the height of its text at the width it has, and before the
	# first layout that is no width at all; clipped, it never moves the panel.
	_hint.clip_text = true
	column.add_child(_hint)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	column.add_child(bottom)
	_prompt.name = "tab_prompt"
	_prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_prompt)
	_reset.name = "reset"
	_reset.pressed.connect(_on_reset_pressed)
	bottom.add_child(_reset)
	_back.name = "back"
	_back.set_meta(UiSounds.SOUND_META, &"ui_back")
	_back.pressed.connect(close)
	bottom.add_child(_back)
	_reset.focus_neighbor_right = _reset.get_path_to(_back)
	_back.focus_neighbor_left = _back.get_path_to(_reset)
	FocusTrap.pin(_reset, [SIDE_LEFT, SIDE_BOTTOM])
	FocusTrap.pin(_back, [SIDE_RIGHT, SIDE_BOTTOM])
	FocusTrap.pin(_tabs.get_tab_bar(), [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT])
	FocusTrap.ring(_tabs.get_tab_bar(), _back)
	visible = false


func _ready() -> void:
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	App.pad_in_use_changed.connect(_show_prompt)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var step := _tab_step(event)
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif step != 0:
		get_viewport().set_input_as_handled()
		_tabs.current_tab = wrapi(_tabs.current_tab + step, 0, _tabs.get_tab_count())
		_focus_page()


func open() -> void:
	if visible:
		return
	if settings == null:
		settings = App.settings
	_focus_before = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	_language_before = _language()
	if not settings.changed.is_connected(_on_setting_changed):
		settings.changed.connect(_on_setting_changed)
	_fill()
	_show_page(0)
	visible = true
	_focus_page()


## Saves the options and gives focus back to where it was.
func close() -> void:
	if not visible:
		return
	visible = false
	settings.changed.disconnect(_on_setting_changed)
	if settings.save_file() != OK:
		push_warning("options: cannot write %s" % settings.path)
	if is_instance_valid(_focus_before) and _focus_before.is_visible_in_tree():
		_focus_before.grab_focus()
	_focus_before = null
	closed.emit()
	if _language() != _language_before:
		language_changed.emit()


## Builds the pages anew: with the current values and in the language in use.
func _fill() -> void:
	for page: Node in _tabs.get_children():
		_tabs.remove_child(page)
		page.queue_free()
	var game := OptionsGame.new(settings)
	if not allow_language:
		game.lock_language()
	_controls = ControlsSection.new()
	_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The bindings of every scene do not fit the panel; the page scrolls, the others never do.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.add_child(_controls)
	var pages: Array[Control] = [
		OptionsVideo.new(settings), OptionsAudio.new(settings), game, scroll,
	]
	for index: int in pages.size():
		pages[index].name = PAGE_NAMES[index]
		_tabs.add_child(pages[index])
		_tabs.set_tab_title(index, tr(TAB_TEXTS[index]))
	_title.text = tr("OPTIONS_TITLE")
	_reset.text = tr("OPTIONS_RESET")
	_back.text = tr("UI_BACK")
	_show_prompt(App.pad_in_use)


## Refilling the tabs does not reliably report a change of tab, so the page is set up here.
func _show_page(tab: int) -> void:
	_tabs.current_tab = tab
	_on_tab_changed(tab)


func _focus_page() -> void:
	var inner := FocusTrap.focusables(_tabs.get_current_tab_control())
	var target: Control = _tabs.get_tab_bar() if inner.is_empty() else inner[0]
	target.grab_focus()


## Tab bar, the page's rows and the buttons below form one column. The controls page lays
## out its own controls; only the ways into it are set.
func _link_focus(page: Control) -> void:
	var bar := _tabs.get_tab_bar()
	var first: Control = _back
	var last: Control = bar
	if page is OptionsTab:
		var rows := (page as OptionsTab).controls()
		FocusTrap.link_column(rows)
		first = rows[0]
		last = rows[rows.size() - 1]
		first.focus_neighbor_top = first.get_path_to(bar)
		last.focus_neighbor_bottom = last.get_path_to(_back)
	else:
		var inner := FocusTrap.focusables(page)
		if not inner.is_empty():
			first = inner[0]
			last = inner[inner.size() - 1]
	bar.focus_neighbor_bottom = bar.get_path_to(first)
	for button: Button in [_reset, _back]:
		button.focus_neighbor_top = button.get_path_to(last)


## The language in use with these options (a choice of "system" resolves to a language).
func _language() -> String:
	return SettingsApplier.new(settings, get_window()).locale()


func _tab_step(event: InputEvent) -> int:
	var button := event as InputEventJoypadButton
	if button != null and button.pressed:
		if button.button_index == JOY_BUTTON_LEFT_SHOULDER:
			return -1
		if button.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			return 1
	if event.is_action_pressed("ui_page_up"):
		return -1
	if event.is_action_pressed("ui_page_down"):
		return 1
	return 0


func _show_prompt(pad: bool) -> void:
	_prompt.text = tr("OPTIONS_TABS_PAD") if pad else tr("OPTIONS_TABS_KEYS")


func _on_tab_changed(_tab: int) -> void:
	var page := _tabs.get_current_tab_control()
	if page == null:
		return
	_reset.visible = page is OptionsTab
	_hint.text = ""
	if _controls != null and page.is_ancestor_of(_controls):
		_controls.refresh()
	_link_focus(page)


func _on_focus_changed(control: Control) -> void:
	if not visible:
		return
	var node: Node = control
	while node != null and node != self and not node is OptionRow:
		node = node.get_parent()
	_hint.text = (node as OptionRow).hint if node is OptionRow else ""


func _on_reset_pressed() -> void:
	var page := _tabs.get_current_tab_control() as OptionsTab
	if page != null:
		page.reset()


func _on_setting_changed(key: String) -> void:
	if key == UserSettings.LOCALE:
		_retranslate.call_deferred()


## The texts were set when the pages were built, so a new language needs new pages.
func _retranslate() -> void:
	if not visible:
		return
	var tab := _tabs.current_tab
	_fill()
	_show_page(tab)
	_focus_page()
