class_name SaveSlotRow
extends Control
## One line of the saved games (SaveSlotsScreen): a wide button that tells what the slot
## holds — its name, the round and date in the game, the human houses, when it was saved and,
## unless all is well, its status in words — and, on its right end, the button that deletes
## a used manual slot.

signal picked(slot: String)
signal delete_requested(slot: String)

const ROW_SIZE := Vector2(810.0, 70.0)
const DELETE_WIDTH := 104.0
## The delete button's distance from the row's right, upper and lower edge.
const DELETE_INSET := 13.0
const SIDE_MARGIN := 16.0
const NAME_SIZE := 19
const BADGE_SIZE := Vector2(17, 20)
## Hot-seat seats; a header that lists more houses is not the game's.
const MAX_HOUSES := 4
const DIMMED := 0.6

var slot := ""
var status := SaveGames.Status.EMPTY
var header: Dictionary = {}
var button := Button.new()
var delete := Button.new()

var _content := VBoxContainer.new()
var _name := CampaignStyle.heading("", NAME_SIZE)
var _status := CampaignStyle.label("", CampaignStyle.SMALL_SIZE, CampaignStyle.BAD)
var _saved := CampaignStyle.label("", CampaignStyle.SMALL_SIZE, CampaignStyle.MUTED)
var _date := CampaignStyle.label("", CampaignStyle.SMALL_SIZE + 1)
var _houses := HBoxContainer.new()


func _init(row_slot: String) -> void:
	slot = row_slot
	name = row_slot
	custom_minimum_size = ROW_SIZE
	button.name = "pick"
	button.pressed.connect(func() -> void: picked.emit(slot))
	add_child(button)
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 1)
	button.add_child(_content)
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.offset_left = SIDE_MARGIN
	# Every row keeps the delete button's place free, so the times of saving line up.
	_content.offset_right = -(DELETE_INSET + DELETE_WIDTH + SIDE_MARGIN)
	_status.name = "status"
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_saved.name = "saved"
	_saved.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_date.name = "date"
	_houses.name = "houses"
	_houses.add_theme_constant_override("separation", 5)
	_content.add_child(_line([_name, _status, _saved] as Array[Control], 14))
	_content.add_child(_line([_date, _houses] as Array[Control], 18))
	# The button takes every click and the hover; nothing inside may catch them.
	for inner: Control in _content.find_children("*", "Control", true, false):
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	delete.name = "delete"
	delete.pressed.connect(func() -> void: delete_requested.emit(slot))
	add_child(delete)
	delete.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	delete.offset_left = -(DELETE_INSET + DELETE_WIDTH)
	delete.offset_right = -DELETE_INSET
	delete.offset_top = DELETE_INSET
	delete.offset_bottom = -DELETE_INSET


## "Automatischer Spielstand", "Spielstand 2".
static func slot_name(slot_id: String) -> String:
	var number := SaveGames.SLOTS.find(slot_id) + 1
	if number > 0:
		return CampaignFormat.t("SAVES_SLOT") % number
	return CampaignFormat.t("SAVES_AUTOSAVE")


## "Runde 12 · Herbst 1200", from the round in a save's header.
static func game_date(save_header: Dictionary) -> String:
	var moment := GameState.new()
	moment.turn = save_header.get("turn", 0)
	var season := CampaignFormat.season_name(moment.season())
	return CampaignFormat.t("SAVES_DATE") % [moment.turn + 1, season, CampaignFormat.year(moment)]


## The status in words; nothing to say about a save that is simply there.
static func status_text(slot_status: SaveGames.Status, save_header: Dictionary) -> String:
	match slot_status:
		SaveGames.Status.EMPTY:
			return CampaignFormat.t("SAVES_EMPTY")
		SaveGames.Status.RECOVERED:
			return CampaignFormat.t("SAVES_RECOVERED")
		SaveGames.Status.BROKEN:
			return CampaignFormat.t("SAVES_BROKEN")
		SaveGames.Status.OTHER_VERSION:
			var version := str(save_header.get("game_version", ""))
			var current := str(ProjectSettings.get_setting("application/config/version", ""))
			if version.is_empty() or version == current:
				return CampaignFormat.t("SAVES_OTHER_VERSION")
			return CampaignFormat.t("SAVES_OTHER_GAME_VERSION") % version
	return ""


## Reads the slot anew. `map` gives the houses their colours; without it (null) the badges
## stay plain.
func show_slot(map: MapData) -> void:
	status = SaveGames.status(slot)
	header = SaveGames.header(slot)
	var words := status_text(status, header)
	var known := not header.is_empty()
	_name.text = slot_name(slot)
	_status.text = words if known else ""
	_saved.text = SaveCaption.date(str(header.get("saved_at", "")))
	_date.text = game_date(header) if known else words
	var date_color := CampaignStyle.TEXT
	if not known:
		date_color = CampaignStyle.MUTED if status == SaveGames.Status.EMPTY else CampaignStyle.BAD
	_date.add_theme_color_override("font_color", date_color)
	delete.text = CampaignFormat.t("SAVES_DELETE")
	delete.visible = slot != SaveGames.AUTOSAVE and status != SaveGames.Status.EMPTY
	_show_houses(map)


## A row that cannot be picked is dimmed and passed over by the focus.
func set_pickable(pickable: bool) -> void:
	button.disabled = not pickable
	button.focus_mode = Control.FOCUS_ALL if pickable else Control.FOCUS_NONE
	_content.modulate.a = 1.0 if pickable else DIMMED


func is_pickable() -> bool:
	return not button.disabled


## The names of the houses shown, in order.
func house_names() -> Array[String]:
	var names: Array[String] = []
	for label: Node in _houses.find_children("*", "Label", false, false):
		names.append((label as Label).text)
	return names


func _show_houses(map: MapData) -> void:
	for child: Node in _houses.get_children():
		child.free()
	var humans: Array = header.get("humans", [])
	for house: String in humans.slice(0, MAX_HOUSES):
		var badge := HouseBadge.new(BADGE_SIZE)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if map != null and map.house_colors.has(house):
			badge.colors = map.house_colors[house]
		_houses.add_child(badge)
		var label := CampaignStyle.label(
			CampaignFormat.house_name(house), CampaignStyle.SMALL_SIZE, CampaignStyle.MUTED
		)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_houses.add_child(label)
		var gap := Control.new()
		gap.custom_minimum_size.x = 6
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_houses.add_child(gap)


static func _line(parts: Array[Control], separation: int) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", separation)
	for part: Control in parts:
		line.add_child(part)
	return line
