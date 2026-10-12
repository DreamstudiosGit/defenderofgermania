class_name SettlementReport
extends Control
## What the last settlement did for each human house, from snapshots taken right before and
## after it: taler (income, upkeep), grain (harvest, eaten, spoiled), prestige, satisfaction
## and people per province, finished constructions, revolts and the autumn weather.

signal closed

var _title := CampaignStyle.heading("", 30)
var _weather := CampaignStyle.label("", CampaignStyle.SMALL_SIZE, CampaignStyle.MUTED)
var _columns := HBoxContainer.new()
var _close := CampaignStyle.modal_button("")


func _init() -> void:
	var column := CampaignStyle.modal(self, Color(0.0, 0.0, 0.0, 0.6))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_weather.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_weather)
	_columns.add_theme_constant_override("separation", 28)
	column.add_child(_columns)
	_close.text = tr("CAMPAIGN_CONTINUE")
	_close.pressed.connect(_on_close_pressed)
	column.add_child(_close)
	visible = false


## before: the state right before the settlement (end of the last campaign phase);
## after: right after it. Shows one column per human house still in the game.
func open(before: GameState, after: GameState, rules: GameRules, humans: Array[String]) -> void:
	_title.text = tr("CAMPAIGN_REPORT_TITLE") % CampaignFormat.season_name(before.season())
	_weather.visible = before.season() == GameState.Season.AUTUMN
	if _weather.visible:
		var parts := PackedStringArray()
		for region: String in rules.map.regions:
			parts.append("%s %s" % [
				tr("CAMPAIGN_REGION_" + region.to_upper()),
				CampaignFormat.number(after.weather.get(region, 1.0), 2),
			])
		_weather.text = tr("CAMPAIGN_REPORT_WEATHER") % ", ".join(parts)
	for child: Node in _columns.get_children():
		_columns.remove_child(child)
		child.queue_free()
	for house: String in humans:
		if after.houses.has(house) and not after.houses[house].is_eliminated:
			_columns.add_child(_house_column(before, after, rules, house))
	visible = true
	_close.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_close_pressed()


func _house_column(
	before: GameState, after: GameState, rules: GameRules, house: String
) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.custom_minimum_size.x = 250
	var name := CampaignStyle.heading(CampaignFormat.house_name(house), 22)
	name.add_theme_color_override("font_color", CampaignFormat.owner_color(rules.map, house))
	column.add_child(name)
	for line: ReportLines.Line in ReportLines.for_house(before, after, rules, house):
		var label := CampaignStyle.label(line.text, CampaignStyle.SMALL_SIZE + 1)
		match line.tone:
			ReportLines.Tone.WARNING:
				label.add_theme_color_override("font_color", CampaignStyle.BAD)
			ReportLines.Tone.HEADING:
				label.add_theme_color_override("font_color", CampaignStyle.GOLD)
				label.add_theme_font_size_override("font_size", CampaignStyle.FONT_SIZE)
		column.add_child(label)
	return column


func _on_close_pressed() -> void:
	visible = false
	closed.emit()
