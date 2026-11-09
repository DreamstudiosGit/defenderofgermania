class_name ConfirmDialog
extends Control
## Asks before something that cannot be undone (overwrite a save, leave a campaign, quit).
## Focus starts on "cancel", Esc / B cancels, and focus returns to where it was when the
## dialog closes. Add one to a screen and call ask(); it keeps working while the tree is
## paused.

signal confirmed
signal cancelled

const WIDTH := 420.0

var _question := CampaignStyle.paragraph("", CampaignStyle.FONT_SIZE)
var _confirm := Button.new()
var _cancel := Button.new()
var _focus_before: Control = null


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var column := CampaignStyle.modal(self, Color(UiPalette.SHADE, 0.7))
	_question.custom_minimum_size.x = WIDTH
	_question.add_theme_color_override("font_color", CampaignStyle.TEXT)
	_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_question)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	_cancel.name = "cancel"
	_cancel.custom_minimum_size.x = 160
	_cancel.set_meta(UiSounds.SOUND_META, &"ui_back")
	_cancel.pressed.connect(_close.bind(false))
	buttons.add_child(_cancel)
	_confirm.name = "confirm"
	_confirm.custom_minimum_size.x = 160
	_confirm.set_meta(UiSounds.SOUND_META, &"ui_confirm")
	_confirm.pressed.connect(_close.bind(true))
	buttons.add_child(_confirm)
	visible = false


## Shows the question (already translated) with the text of the confirming button; the other
## button says "cancel" unless cancel_text is given.
func ask(question: String, confirm_text: String, cancel_text: String = "") -> void:
	_question.text = question
	_confirm.text = confirm_text
	_cancel.text = cancel_text if not cancel_text.is_empty() else tr("UI_CANCEL")
	_focus_before = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	visible = true
	_cancel.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close(false)


func _close(accepted: bool) -> void:
	visible = false
	if _focus_before != null and is_instance_valid(_focus_before):
		if _focus_before.is_visible_in_tree():
			_focus_before.grab_focus()
	_focus_before = null
	if accepted:
		confirmed.emit()
	else:
		cancelled.emit()
