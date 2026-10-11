class_name BattleHud
extends CanvasLayer
## Battle HUD: group shields bottom left (attacker) and bottom right (defender) with their
## switch hints, company bars, timer, control hints and the big shouts for battle events.

const MARGIN := 24.0
const HINT_SIZE := 14
const HINT_WIDTH := 460.0

var _shields: Array[Array] = [[], []]
var _rows: Array[HBoxContainer] = []
var _hints: Array[Label] = []
var _timer := Label.new()
var _bars := CompanyBars.new()
var _shout := BattleShout.new()
var _armies: Array[BattleRules.ArmyPreset] = []


func _ready() -> void:
	add_child(_bars)
	add_child(_shout)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer.label_settings = _settings(28)
	add_child(_timer)
	_timer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 12)
	_timer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	for s: int in BattleState.SIDES:
		var corner := VBoxContainer.new()
		add_child(corner)
		var preset := Control.PRESET_BOTTOM_LEFT if s == 0 else Control.PRESET_BOTTOM_RIGHT
		corner.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, MARGIN)
		corner.grow_horizontal = Control.GROW_DIRECTION_END if s == 0 else Control.GROW_DIRECTION_BEGIN
		corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.alignment = BoxContainer.ALIGNMENT_BEGIN if s == 0 else BoxContainer.ALIGNMENT_END
		corner.add_child(row)
		_rows.append(row)
		var hint := Label.new()
		hint.label_settings = _settings(HINT_SIZE)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size.x = HINT_WIDTH
		hint.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_LEFT if s == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		)
		corner.add_child(hint)
		_hints.append(hint)


## devices[s] is a BattleInputMap.Device, or -1 for an AI side.
func setup(
	state: BattleState,
	armies: Array[BattleRules.ArmyPreset],
	devices: PackedInt32Array,
	camera: Camera3D
) -> void:
	_armies = armies
	_bars.setup(camera, [armies[0].color.lightened(0.2), armies[1].color.lightened(0.2)])
	_shout.clear()
	for s: int in BattleState.SIDES:
		for child: Node in _rows[s].get_children():
			child.queue_free()
		_shields[s] = []
		var device := devices[s]
		_rows[s].add_child(_switch_label(device, true))
		for g: int in state.side_groups[s]:
			var shield := GroupShield.new()
			shield.group = g
			shield.house_color = armies[s].color
			shield.accent = armies[s].accent
			_rows[s].add_child(shield)
			_shields[s].append(shield)
		_rows[s].add_child(_switch_label(device, false))
		_hints[s].text = _hint_text(device)


func update_view(sim: BattleSim, positions: PackedVector2Array, delta: float) -> void:
	var state := sim.state
	_bars.update_view(state, positions, delta)
	var left := ceili(sim.seconds_left())
	var clock := "%d:%02d" % [floori(left / 60.0), left % 60]
	if state.phase == BattleState.Phase.DEPLOY:
		_timer.text = tr("BATTLE_PHASE_DEPLOY") % clock
	else:
		_timer.text = clock
	for s: int in BattleState.SIDES:
		var groups := state.side_groups[s]
		for i: int in groups.size():
			var shield: GroupShield = _shields[s][i]
			_fill_shield(state, sim.rules, shield, s, groups[i])


func handle_events(state: BattleState) -> void:
	for event: BattleEvent in state.events:
		var house := _house(event.side)
		match event.kind:
			BattleEvent.Kind.FIGHT_START:
				var cries := "%s   %s" % [tr(_key("BATTLE_CRY_", 0)), tr(_key("BATTLE_CRY_", 1))]
				_shout.shout(cries, "", Color.BLACK)
			BattleEvent.Kind.CHARGE:
				_shout.shout(tr("BATTLE_SHOUT_CHARGE"), tr(_key("BATTLE_CRY_", event.side)), house)
			BattleEvent.Kind.HEDGEHOG:
				_shout.shout(tr("BATTLE_SHOUT_HOLD"), "", house)
			BattleEvent.Kind.ROUT:
				var unit := tr("BATTLE_UNIT_" + state.unit_ids[event.company].to_upper())
				_shout.shout(tr("BATTLE_SHOUT_RETREAT"), unit, house)
			BattleEvent.Kind.RALLY:
				_shout.shout(tr("BATTLE_SHOUT_RALLY"), tr(_key("BATTLE_CRY_", event.side)), house)
			BattleEvent.Kind.LEADER_CAPTURED:
				_shout.shout(tr("BATTLE_SHOUT_LEADER_CAPTURED"), tr(_key("BATTLE_HOUSE_", event.side)), house)


func _fill_shield(
	state: BattleState, rules: BattleRules, shield: GroupShield, s: int, g: int
) -> void:
	var companies := 0
	var bolts := rules.volleys
	var leader := false
	for c: int in state.members(s, g):
		if state.status[c] != BattleState.Status.ACTIVE:
			continue
		if state.is_leader(c):
			leader = true
			continue
		companies += 1
		bolts = mini(bolts, state.bolts[c])
	var active := state.active_group[s] == g
	var archers := g == BattleState.Group.ARCHERS
	var changed := shield.companies != companies or shield.active != active
	changed = changed or shield.has_leader != leader or (archers and shield.bolts != bolts)
	shield.companies = companies
	shield.active = active
	shield.has_leader = leader
	shield.max_bolts = rules.volleys
	if not archers:
		shield.bolts = -1
	else:
		shield.bolts = bolts if companies > 0 else 0
	if changed:
		shield.queue_redraw()


func _switch_label(device: int, previous: bool) -> Label:
	var label := Label.new()
	label.label_settings = _settings(18)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if device == BattleInputMap.Device.KEYBOARD:
		label.text = "Q" if previous else "E"
	elif device >= 0:
		label.text = "LT" if previous else "RT"
	return label


func _hint_text(device: int) -> String:
	if device == BattleInputMap.Device.KEYBOARD:
		return tr("BATTLE_HINT_KEYBOARD")
	if device >= 0:
		return tr("BATTLE_HINT_PAD")
	return tr("BATTLE_CONTROL_AI")


func _house(s: int) -> Color:
	return _armies[s].color if s >= 0 and s < _armies.size() else Color.BLACK


func _key(prefix: String, s: int) -> String:
	return prefix + _armies[s].house.to_upper()


func _settings(font_size: int) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.outline_size = 5
	settings.outline_color = Color(0.1, 0.07, 0.05)
	return settings
