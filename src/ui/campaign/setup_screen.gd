class_name SetupScreen
extends Control
## New game (GDD "Partieaufbau"): who plays each house — a human, or a computer opponent with
## a personality (or one rolled from the seed) and a difficulty — and the seed. At least one
## house needs a human, since the session plays computer houses in one go until a human is to
## move. Emits start_requested.

signal start_requested(humans: Array[String], seed: int, computers: Dictionary)

const MIN_HUMANS := 1
## Items of the player choice.
const HUMAN := 0
const COMPUTER := 1
const COLUMNS := 5

var _hint := CampaignStyle.paragraph("", CampaignStyle.SMALL_SIZE + 1)
var _houses := GridContainer.new()
var _seed := LineEdit.new()
var _reroll := Button.new()
var _warning := CampaignStyle.paragraph("", CampaignStyle.SMALL_SIZE)
var _start := CampaignStyle.modal_button("")
var _players: Dictionary[String, OptionButton] = {}
var _personalities: Dictionary[String, OptionButton] = {}
var _difficulties: Dictionary[String, OptionButton] = {}
## Personality ids in the order of the choices, AiFormat.RANDOM last.
var _personality_ids: Array[String] = []
var _config: AiConfig
var _economy: EconomyConfig


func _init() -> void:
	var column := CampaignStyle.modal(self, Color(0.07, 0.05, 0.04))
	var title := CampaignStyle.heading(tr("CAMPAIGN_SETUP_TITLE"), 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_hint.text = tr("CAMPAIGN_SETUP_HINT")
	_hint.custom_minimum_size.x = 480
	column.add_child(_hint)
	_houses.columns = COLUMNS
	_houses.add_theme_constant_override("h_separation", 12)
	_houses.add_theme_constant_override("v_separation", 6)
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


## Shows the houses of the map — the first played by a human, the others by the data's
## computer opponents — and focuses the start button.
func open(rules: GameRules, config: AiConfig, seed_value: int) -> void:
	_config = config
	_economy = rules.economy
	for child: Node in _houses.get_children():
		_houses.remove_child(child)
		child.queue_free()
	_players.clear()
	_personalities.clear()
	_difficulties.clear()
	_personality_ids.assign(config.default_house.keys())
	_personality_ids.append(AiFormat.RANDOM)
	var headings: Array[String] = [
		"", "CAMPAIGN_SETUP_HOUSE", "CAMPAIGN_SETUP_PLAYER", "CAMPAIGN_AI_PERSONALITY",
		"CAMPAIGN_AI_DIFFICULTY",
	]
	for key: String in headings:
		var text := tr(key) if not key.is_empty() else ""
		_houses.add_child(CampaignStyle.label(text, CampaignStyle.SMALL_SIZE, CampaignStyle.MUTED))
	for house: String in rules.map.houses:
		_add_house(rules.map, house)
	_seed.text = str(seed_value)
	visible = true
	_check()
	_start.grab_focus()


func humans() -> Array[String]:
	var chosen: Array[String] = []
	for house: String in _players:
		if _players[house].selected == HUMAN:
			chosen.append(house)
	return chosen


## The computer houses with [personality, difficulty]; a random personality is rolled from the
## seed, so a seed always brings the same opponents.
func computers(seed_value: int) -> Dictionary[String, Array]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var result: Dictionary[String, Array] = {}
	for house: String in _players:
		if _players[house].selected != COMPUTER:
			continue
		var personality := _personality_ids[_personalities[house].selected]
		if personality == AiFormat.RANDOM:
			personality = _personality_ids[rng.randi_range(0, _personality_ids.size() - 2)]
		result[house] = [personality, _difficulties[house].selected]
	return result


func _add_house(map: MapData, house: String) -> void:
	var badge := HouseBadge.new()
	badge.colors = map.house_colors[house]
	_houses.add_child(badge)
	var title := CampaignStyle.label(CampaignFormat.house_name(house), CampaignStyle.FONT_SIZE + 2)
	title.add_theme_color_override("font_color", CampaignFormat.owner_color(map, house))
	_houses.add_child(title)
	var roles: Array[String] = [tr("CAMPAIGN_SETUP_HUMAN"), tr("CAMPAIGN_SETUP_COMPUTER")]
	var player := _choice("player_" + house, roles)
	player.select(HUMAN if _players.is_empty() else COMPUTER)
	player.tooltip_text = tr("CAMPAIGN_SETUP_PLAYER_HINT")
	_players[house] = player
	var names: Array[String] = []
	for id: String in _personality_ids:
		names.append(AiFormat.personality_name(id))
	var personality := _choice("personality_" + house, names)
	personality.select(_personality_ids.find(_config.personality_of(house)))
	_personalities[house] = personality
	var levels: Array[String] = []
	for level: int in _config.difficulties.size():
		levels.append(AiFormat.difficulty_name(level))
	var difficulty := _choice("difficulty_" + house, levels)
	difficulty.select(_config.default_difficulty)
	_difficulties[house] = difficulty


func _choice(node_name: String, items: Array[String]) -> OptionButton:
	var choice := OptionButton.new()
	choice.name = node_name
	for item: String in items:
		choice.add_item(item)
	choice.item_selected.connect(func(_index: int) -> void: _check())
	_houses.add_child(choice)
	return choice


## Personality and difficulty only count for computer houses; their tooltips explain the
## current choice.
func _check() -> void:
	for house: String in _players:
		var computer := _players[house].selected == COMPUTER
		var personality := _personalities[house]
		var difficulty := _difficulties[house]
		for choice: OptionButton in [personality, difficulty]:
			choice.disabled = not computer
			choice.focus_mode = Control.FOCUS_ALL if computer else Control.FOCUS_NONE
			choice.tooltip_text = tr("CAMPAIGN_AI_ONLY_COMPUTER")
		if computer:
			var id := _personality_ids[personality.selected]
			personality.tooltip_text = AiFormat.personality_hint(_config, id)
			difficulty.tooltip_text = AiFormat.difficulty_hint(
				_config, _economy, difficulty.selected
			)
	var problems := PackedStringArray()
	if humans().size() < MIN_HUMANS:
		problems.append(tr("CAMPAIGN_SETUP_TOO_FEW"))
	if not _seed.text.strip_edges().is_valid_int():
		problems.append(tr("CAMPAIGN_SETUP_BAD_SEED"))
	_warning.text = "\n".join(problems)
	_warning.visible = not problems.is_empty()
	_start.disabled = not problems.is_empty()


func _on_start_pressed() -> void:
	visible = false
	var seed_value := _seed.text.strip_edges().to_int()
	start_requested.emit(humans(), seed_value, computers(seed_value))
