class_name AiDebugOverlay
extends PanelContainer
## Balancing tool (GDD "Ein Debug-Overlay zeigt alle Nutzenwerte"): a see-through side panel
## with every option the chosen computer house weighed in its last turn — phase, label, utility,
## taken (✓) or the key of the rules' refusal — newest first, under the house's personality,
## difficulty and pillars of the crown. F3 or Back+Y shows it; F4 (Shift+F4 back) or Back+RB/LB
## picks the house; the wheel or Back+d-pad scrolls. It never takes the focus; hidden, it takes
## no clicks and only its toggle.

const WIDTH := 400.0
const TOP := 80.0
const MARGIN := 8.0
const SCROLL_STEP := 160.0
## Regalia, a coronation site and the votes (AiStrength.pillars).
const PILLAR_KINDS := 3
const BACKGROUND := Color(0.10, 0.07, 0.05, 0.84)
const HEADINGS: Array[String] = [
	"CAMPAIGN_AI_DEBUG_PHASE", "CAMPAIGN_AI_DEBUG_OPTION", "CAMPAIGN_AI_DEBUG_UTILITY", ""
]

## The computer house shown.
var house := ""

var _badge := HouseBadge.new(Vector2(22, 26))
var _name := CampaignStyle.label("", CampaignStyle.FONT_SIZE + 2)
var _profile := CampaignStyle.label("", CampaignStyle.SMALL_SIZE, CampaignStyle.MUTED)
var _table := RichTextLabel.new()
var _state: GameState
var _rules: GameRules
var _ai: AiPlayer
var _rows := 0
## Controllers holding Back, by device.
var _back_held: Dictionary[int, bool] = {}


func _init() -> void:
	theme = CampaignStyle.theme()
	visible = false
	add_theme_stylebox_override("panel", CampaignStyle.panel_style(BACKGROUND, 1, 10))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	column.add_child(CampaignStyle.heading(tr("CAMPAIGN_AI_DEBUG_TITLE"), 18))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	row.add_child(_arrow("previous", "←", -1))
	_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_badge)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_name)
	row.add_child(_arrow("next", "→", 1))
	column.add_child(_profile)
	_table.name = "options"
	_table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_table.scroll_active = true
	_table.focus_mode = Control.FOCUS_NONE
	_table.add_theme_font_size_override("normal_font_size", CampaignStyle.SMALL_SIZE)
	_table.add_theme_color_override("default_color", CampaignStyle.TEXT)
	_table.add_theme_color_override("table_odd_row_bg", Color(CampaignStyle.GOLD, 0.06))
	_table.add_theme_color_override("table_even_row_bg", Color(0, 0, 0, 0))
	_table.add_theme_constant_override("table_h_separation", 8)
	column.add_child(_table)
	var keys := CampaignStyle.paragraph(tr("CAMPAIGN_AI_DEBUG_KEYS"), CampaignStyle.SMALL_SIZE - 2)
	column.add_child(keys)


## Stands `right` px in from the right edge (beside the side panels, not over them), from
## below the top bar to the bottom.
func place(right: float) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	offset_left = -right - WIDTH
	offset_top = TOP
	offset_right = -right
	offset_bottom = -MARGIN
	grow_horizontal = Control.GROW_DIRECTION_BEGIN


## Keeps the campaign's state and computer players; redraws while shown.
func refresh(state: GameState, rules: GameRules, ai: AiPlayer) -> void:
	_state = state
	_rules = rules
	_ai = ai
	var houses := computer_houses()
	if house not in houses:
		house = houses[0] if not houses.is_empty() else ""
	if visible:
		_redraw()


func toggle() -> void:
	visible = not visible
	if visible:
		_redraw()


## Shows the next (1) or previous (−1) computer house.
func cycle(step: int) -> void:
	var houses := computer_houses()
	if houses.is_empty():
		return
	house = houses[posmod(houses.find(house) + step, houses.size())]
	_redraw()


func scroll(step: int) -> void:
	_table.get_v_scroll_bar().value += step * SCROLL_STEP


## Computer houses in turn order.
func computer_houses() -> Array[String]:
	var result: Array[String] = []
	if _state == null:
		return result
	for id: String in _state.turn_order:
		if _state.houses[id].is_computer():
			result.append(id)
	return result


## Options listed for the house shown.
func row_count() -> int:
	return _rows


func _input(event: InputEvent) -> void:
	if not _campaign_shown():
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and _on_key(key):
		get_viewport().set_input_as_handled()
		return
	var button := event as InputEventJoypadButton
	if button == null:
		return
	if button.button_index == JOY_BUTTON_BACK:
		_back_held[button.device] = button.pressed
	elif button.pressed and _back_held.get(button.device, false) and _on_combo(button.button_index):
		get_viewport().set_input_as_handled()


func _on_key(key: InputEventKey) -> bool:
	if key.keycode == KEY_F3:
		toggle()
	elif key.keycode == KEY_F4 and visible:
		cycle(-1 if key.shift_pressed else 1)
	else:
		return false
	return true


func _on_combo(button: JoyButton) -> bool:
	if button == JOY_BUTTON_Y:
		toggle()
	elif not visible:
		return false
	elif button in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		cycle(1 if button == JOY_BUTTON_RIGHT_SHOULDER else -1)
	elif button in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
		scroll(1 if button == JOY_BUTTON_DPAD_DOWN else -1)
	else:
		return false
	return true


## False while a battle, a minigame or the castle covers the campaign's screens.
func _campaign_shown() -> bool:
	var parent := get_parent() as CanvasItem
	return parent == null or parent.is_visible_in_tree()


func _redraw() -> void:
	_table.clear()
	_rows = 0
	_badge.visible = not house.is_empty()
	if house.is_empty():
		_name.text = tr("CAMPAIGN_AI_DEBUG_NONE")
		_name.add_theme_color_override("font_color", CampaignStyle.TEXT)
		_profile.text = ""
		return
	var owner := _state.houses[house]
	_badge.colors = _rules.map.house_colors[house]
	_name.text = CampaignFormat.house_name(house)
	_name.add_theme_color_override("font_color", CampaignFormat.owner_color(_rules.map, house))
	_profile.text = tr("CAMPAIGN_AI_DEBUG_PROFILE") % [
		AiFormat.personality_name(owner.personality),
		AiFormat.difficulty_name(owner.difficulty),
		AiStrength.pillars(_state, _rules, house),
		PILLAR_KINDS,
	]
	var entries: Array[AiLog.Entry] = []
	if _ai != null and _ai.logs.has(house):
		entries = _ai.logs[house].entries
	if entries.is_empty():
		_table.add_text(tr("CAMPAIGN_AI_DEBUG_EMPTY"))
		return
	_profile.text += "\n" + tr("CAMPAIGN_AI_DEBUG_TURN") % [entries[0].turn + 1, entries.size()]
	_table.push_table(HEADINGS.size())
	_table.set_table_column_expand(1, true)
	for key: String in HEADINGS:
		_cell(tr(key) if not key.is_empty() else "", CampaignStyle.MUTED)
	for i: int in range(entries.size() - 1, -1, -1):
		_add_row(entries[i])
	_table.pop()


func _add_row(entry: AiLog.Entry) -> void:
	_cell(CampaignFormat.phase_name(entry.phase), CampaignStyle.MUTED)
	_table.push_cell()
	_table.add_text(entry.label)
	if not entry.error.is_empty():
		_table.push_color(CampaignStyle.BAD)
		_table.add_text("\n" + entry.error)
		_table.pop()
	_table.pop()
	_cell(AiFormat.utility(entry.utility), CampaignStyle.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	if entry.taken:
		_cell("✓", CampaignStyle.GOOD)
	else:
		_cell("✗" if not entry.error.is_empty() else "", CampaignStyle.BAD)
	_rows += 1


func _cell(
	text: String, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
) -> void:
	_table.push_cell()
	_table.push_paragraph(align)
	_table.push_color(color)
	_table.add_text(text)
	_table.pop()
	_table.pop()
	_table.pop()


func _arrow(node_name: String, text: String, step: int) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: cycle(step))
	return button
