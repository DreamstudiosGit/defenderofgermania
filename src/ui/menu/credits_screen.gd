class_name CreditsScreen
extends Control
## Credits and licences as a modal over the main menu: the game and who made it, the tools it
## is built with and — since they must ship with the game — the licence texts of the engine,
## its components and the typefaces (LicenceTexts). The text scrolls with the stick, the arrow
## keys, Page Up / Down and the wheel; Esc / B closes.

signal closed

const TEXT_SIZE := Vector2(780.0, 440.0)
## Pixels per second while the stick or an arrow key is held; the legal texts are long, so
## holding on speeds up to MAX_HASTE times that within HASTE_SECONDS.
const SCROLL_SPEED := 420.0
const MAX_HASTE := 6.0
const HASTE_SECONDS := 2.5
const NAME_SIZE := 34
const HEADING_SIZE := 22
const LEGAL_SIZE := 13
const TOOLS: Array[String] = [
	"MENU_CREDITS_ENGINE", "MENU_CREDITS_PHYSICS", "MENU_CREDITS_FONTS", "MENU_CREDITS_TESTS",
]

var _text := RichTextLabel.new()
var _back := CampaignStyle.modal_button(tr("UI_BACK"))
var _filled := false
## Seconds the stick or key has been held.
var _held := 0.0


func _init() -> void:
	var column := CampaignStyle.modal(self, Color(UiPalette.SHADE, 0.86))
	column.add_child(CampaignStyle.title(tr("MENU_CREDITS_TITLE"), 30))
	_text.name = "text"
	_text.custom_minimum_size = TEXT_SIZE
	_text.focus_mode = Control.FOCUS_NONE
	_text.add_theme_stylebox_override("normal", GameTheme.box(UiPalette.INSET, 1, 18, 12))
	_text.add_theme_constant_override("line_separation", 2)
	column.add_child(_text)
	_back.name = "back"
	_back.set_meta(UiSounds.SOUND_META, &"ui_back")
	_back.pressed.connect(close)
	column.add_child(_back)
	visible = false
	set_process(false)


func open() -> void:
	if not _filled:
		_filled = true
		_fill()
	_text.get_v_scroll_bar().value = 0.0
	visible = true
	set_process(true)
	_back.grab_focus()


func close() -> void:
	visible = false
	set_process(false)
	closed.emit()


## Moves the text by `pixels`, down for positive values.
func scroll_by(pixels: float) -> void:
	_text.get_v_scroll_bar().value += pixels


func _process(delta: float) -> void:
	var axis := Input.get_axis("ui_up", "ui_down")
	_held = _held + delta if axis != 0.0 else 0.0
	if axis != 0.0:
		var haste := 1.0 + (MAX_HASTE - 1.0) * minf(_held / HASTE_SECONDS, 1.0)
		scroll_by(axis * SCROLL_SPEED * haste * delta)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Audio.play(&"ui_back")
		close()
	elif event.is_action_pressed("ui_page_down", true):
		get_viewport().set_input_as_handled()
		scroll_by(_text.get_v_scroll_bar().page)
	elif event.is_action_pressed("ui_page_up", true):
		get_viewport().set_input_as_handled()
		scroll_by(-_text.get_v_scroll_bar().page)


func _fill() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	_text.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
	_heading("%s %s" % [tr("MENU_TITLE"), tr("MENU_TITLE_YEAR")], NAME_SIZE)
	_line(tr("MENU_VERSION") % version, UiPalette.MUTED)
	_text.newline()
	_line(tr("MENU_CREDITS_BY"), UiPalette.MUTED)
	_heading(tr("MENU_CREDITS_STUDIO"), HEADING_SIZE + 4)
	_text.newline()
	_heading(tr("MENU_CREDITS_TOOLS"), HEADING_SIZE)
	for key: String in TOOLS:
		_line(tr(key), UiPalette.TEXT)
	_text.pop()
	_text.newline()
	_heading(tr("MENU_CREDITS_LICENCES"), HEADING_SIZE)
	_legal("Godot Engine", LicenceTexts.engine())
	for font_name: String in LicenceTexts.FONTS:
		_legal(tr("MENU_CREDITS_FONT_LICENCE") % font_name, LicenceTexts.font(font_name))
	_text.newline()
	_heading(tr("MENU_CREDITS_COMPONENTS"), HEADING_SIZE)
	_legal("", LicenceTexts.components())
	var licences := LicenceTexts.licences()
	for licence: String in licences:
		_legal(licence, licences[licence])


func _heading(text: String, font_size: int) -> void:
	_text.push_context()
	_text.push_font(UiFonts.display())
	_text.push_font_size(font_size)
	_text.push_color(UiPalette.GOLD)
	_text.add_text(text)
	_text.pop_context()
	_text.newline()


func _line(text: String, color: Color) -> void:
	_text.push_color(color)
	_text.add_text(text)
	_text.pop()
	_text.newline()


## A legal text in small print under its name; the texts are plain, never BBCode.
func _legal(title: String, text: String) -> void:
	if not title.is_empty():
		_text.newline()
		_line(title, UiPalette.GOLD)
	_text.push_font_size(LEGAL_SIZE)
	_line(text, UiPalette.MUTED)
	_text.pop()
