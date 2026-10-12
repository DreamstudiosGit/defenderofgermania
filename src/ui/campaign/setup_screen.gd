class_name SetupScreen
extends Control
## New game: choose which houses humans play (2 to 4; the others stay passive until the
## computer opponents arrive) and the seed. Emits start_requested.

signal start_requested(humans: Array[String], seed: int)

const MIN_HUMANS := 2

var _hint := CampaignStyle.paragraph("", CampaignStyle.SMALL_SIZE + 1)
var _houses := VBoxContainer.new()
var _seed := LineEdit.new()
var _reroll := Button.new()
var _warning := CampaignStyle.paragraph("", CampaignStyle.SMALL_SIZE)
var _start := CampaignStyle.modal_button("")
var _toggles: Dictionary[String, CheckButton] = {}


func _init() -> void:
	var column := CampaignStyle.modal(self, Color(0.07, 0.05, 0.04))
	var title := CampaignStyle.heading(tr("CAMPAIGN_SETUP_TITLE"), 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_hint.custom_minimum_size.x = 480
	column.add_child(_hint)
	_houses.add_theme_constant_override("separation", 6)
	column.add_child(_houses)
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 10)
	column.add_child(seed_row)
	seed_row.add_child(CampaignStyle.label(tr("CAMPAIGN_SEED")))
	_seed.custom_minimum_size = Vector2(160, 44)
	_seed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed.text_changed.connect(func(_text: String) -> void: _check())
	seed_row.add_child(_seed)
	_reroll.text = tr("CAMPAIGN_SEED_REROLL")
	_reroll.pressed.connect(func() -> void: _seed.text = str(randi()))
	seed_row.add_child(_reroll)
	_warning.add_theme_color_override("font_color", CampaignStyle.BAD)
	column.add_child(_warning)
	_start.name = "start"
	_start.text = tr("CAMPAIGN_SETUP_START")
	_start.pressed.connect(_on_start_pressed)
	column.add_child(_start)
	visible = false


## Shows the houses of the map with the first two chosen and focuses the start button.
func open(map: MapData, seed_value: int) -> void:
	for child: Node in _houses.get_children():
		_houses.remove_child(child)
		child.queue_free()
	_toggles.clear()
	for house: String in map.houses:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var badge := HouseBadge.new()
		badge.colors = map.house_colors[house]
		row.add_child(badge)
		var toggle := CheckButton.new()
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggle.button_pressed = _toggles.size() < MIN_HUMANS
		toggle.toggled.connect(func(_on: bool) -> void: _check())
		row.add_child(toggle)
		_houses.add_child(row)
		_toggles[house] = toggle
	_hint.text = tr("CAMPAIGN_SETUP_HINT") % [MIN_HUMANS, map.houses.size()]
	_seed.text = str(seed_value)
	visible = true
	_check()
	_start.grab_focus()


func humans() -> Array[String]:
	var chosen: Array[String] = []
	for house: String in _toggles:
		if _toggles[house].button_pressed:
			chosen.append(house)
	return chosen


func _check() -> void:
	for house: String in _toggles:
		var role := "CAMPAIGN_SETUP_HUMAN" if _toggles[house].button_pressed else "CAMPAIGN_SETUP_PASSIVE"
		_toggles[house].text = "%s · %s" % [CampaignFormat.house_name(house), tr(role)]
	var count := humans().size()
	var problems := PackedStringArray()
	if count < MIN_HUMANS:
		problems.append(tr("CAMPAIGN_SETUP_TOO_FEW") % MIN_HUMANS)
	if not _seed.text.strip_edges().is_valid_int():
		problems.append(tr("CAMPAIGN_SETUP_BAD_SEED"))
	_warning.text = "\n".join(problems)
	_warning.visible = not problems.is_empty()
	_start.disabled = not problems.is_empty()


func _on_start_pressed() -> void:
	visible = false
	start_requested.emit(humans(), _seed.text.strip_edges().to_int())
