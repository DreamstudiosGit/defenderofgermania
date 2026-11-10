class_name PracticeMenu
extends VBoxContainer
## The practice submenu of the main menu: the four adventures on their own, without a campaign
## around them, and the way back. Esc / B closes it.

signal chosen(mode: StringName)
signal closed

const JOUST := &"joust"
const SIEGE := &"siege"
const RAID := &"raid"
const MERCHANT := &"merchant"
## Mode and text key of each entry, in the order shown.
const MODES: Array[Array] = [
	[JOUST, "MENU_PRACTICE_JOUST"], [SIEGE, "MENU_PRACTICE_SIEGE"],
	[RAID, "MENU_PRACTICE_RAID"], [MERCHANT, "MENU_PRACTICE_MERCHANT"],
]
const HEADING_SIZE := 26

var entries := MenuEntries.new()


func _init() -> void:
	add_theme_constant_override("separation", 10)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var heading := CampaignStyle.heading(tr("MENU_PRACTICE"), HEADING_SIZE)
	heading.add_theme_constant_override("outline_size", 6)
	heading.add_theme_color_override("font_outline_color", UiPalette.INK)
	add_child(heading)
	add_child(entries)
	for mode: Array in MODES:
		var id: StringName = mode[0]
		var entry := entries.add_entry(id, tr(str(mode[1])))
		entry.pressed.connect(func() -> void: chosen.emit(id))
	var back := entries.add_entry("back", tr("UI_BACK"))
	back.set_meta(UiSounds.SOUND_META, &"ui_back")
	back.pressed.connect(close)
	entries.set_reachable(true)
	visible = false


func open() -> void:
	visible = true
	entries.focus_first()


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Audio.play(&"ui_back")
		close()
