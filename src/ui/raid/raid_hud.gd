class_name RaidHud
extends CanvasLayer
## Castle raid HUD: time left and the alarm on top, health and stamina bottom left, guards top
## right, the fight cues (RaidMarkers), a button prompt at the leader, short pop-up words for
## blows and big shouts for the alarm and the outcome.

const MARGIN := 24.0
const POP_SECONDS := 0.9
const BAR_WIDTH := 240.0

var markers := RaidMarkers.new()

var _timer := Label.new()
var _target := Label.new()
var _alarm := Label.new()
var _guards := Label.new()
var _health := ProgressBar.new()
var _stamina := ProgressBar.new()
var _prompt := Label.new()
var _hint := Label.new()
var _shout := BattleShout.new()
var _pops: Array[Label] = []
var _device: int = BattleInputMap.Device.KEYBOARD


func _ready() -> void:
	add_child(markers)
	add_child(_shout)
	var top := VBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 12)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	for label: Label in [_timer, _target, _alarm]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		top.add_child(label)
	_timer.label_settings = settings(34)
	_target.label_settings = settings(18)
	_alarm.label_settings = settings(20)
	_alarm.modulate = Color(1.0, 0.45, 0.3)
	_guards.label_settings = settings(18)
	add_child(_guards)
	_guards.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, MARGIN
	)
	_guards.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var bars := VBoxContainer.new()
	add_child(bars)
	bars.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, MARGIN
	)
	bars.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bars.add_child(_bar_row("RAID_HUD_HEALTH", _health, Color(0.78, 0.2, 0.16)))
	bars.add_child(_bar_row("RAID_HUD_STAMINA", _stamina, GroupShield.GOLD))
	_prompt.label_settings = settings(20)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_prompt)
	_hint.label_settings = settings(14)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = 520.0
	add_child(_hint)
	_hint.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, MARGIN
	)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN


func setup(target: String, device: int) -> void:
	_device = device
	_target.text = tr("RAID_TARGET_" + target.to_upper())
	_hint.text = "" if device < 0 else tr(
		"RAID_HINT_KEYBOARD" if device == BattleInputMap.Device.KEYBOARD else "RAID_HINT_PAD"
	)
	_shout.clear()
	for pop: Label in _pops:
		pop.queue_free()
	_pops.clear()


func update_view(sim: RaidSim, figures: RaidFigures, camera: Camera3D, delta: float) -> void:
	var state := sim.state
	var seconds := ceili(sim.seconds_left())
	_timer.text = "%d:%02d" % [floori(seconds / 60.0), seconds % 60]
	if state.alarm:
		_alarm.text = tr("RAID_HUD_ALARM")
	else:
		var to_alarm := ceili(sim.cfg.alarm_seconds - sim.elapsed_seconds())
		_alarm.text = tr("RAID_HUD_ALARM_SOON") % to_alarm
	_alarm.modulate = Color(1.0, 0.4, 0.3) if state.alarm else Color(0.85, 0.8, 0.7)
	var left := 0
	for guard: RaidFighter in state.guards:
		if guard.is_active():
			left += 1
	_guards.text = tr("RAID_HUD_GUARDS") % [state.count_guards(true), state.count_guards(false), left]
	_health.value = state.leader.health / maxf(state.leader.max_health, 1.0) * 100.0
	_stamina.value = state.leader.stamina / maxf(sim.cfg.stamina, 1.0) * 100.0
	var rested := state.leader.stamina >= sim.cfg.strike_cost
	_stamina.modulate = Color.WHITE if rested else Color(0.6, 0.6, 0.6)
	_update_prompt(sim, figures, camera)
	for pop: Label in _pops.duplicate():
		pop.position.y -= 40.0 * delta
		pop.modulate.a -= delta / POP_SECONDS
		if pop.modulate.a <= 0.0:
			_pops.erase(pop)
			pop.queue_free()


## A short word that rises from a point on screen and fades.
func pop(text: String, at: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.label_settings = settings(24)
	label.modulate = color
	label.position = at - Vector2(60, 20)
	label.size = Vector2(120, 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	_pops.append(label)


func shout(text: String, subtitle: String, color: Color) -> void:
	_shout.shout(text, subtitle, color)


func _update_prompt(sim: RaidSim, figures: RaidFigures, camera: Camera3D) -> void:
	var state := sim.state
	var text := ""
	var keyboard := _device == BattleInputMap.Device.KEYBOARD
	var key := tr("RAID_KEY_ACT_KB" if keyboard else "RAID_KEY_ACT_PAD")
	if _device >= 0 and not state.over and not state.engaged and not state.is_sneaking():
		var path := sim.layout.entrance_at(state.leader.x)
		if path >= 0 and RaidMoves.path_open(state, sim.layout, path):
			text = tr("RAID_PROMPT_SNEAK") % key
		elif state.leader.x >= sim.layout.deed_x - RaidMoves.DEED_REACH:
			text = tr("RAID_PROMPT_HOLD") % [key, tr("RAID_DEED_" + sim.setup.target.to_upper())]
			if state.deed_progress > 0.0:
				text += "  %d %%" % roundi(state.deed_progress * 100.0)
	_prompt.text = text
	_prompt.visible = not text.is_empty()
	if _prompt.visible:
		var at := camera.unproject_position(figures.leader.global_position + Vector3.UP * 2.5)
		_prompt.size = Vector2(420, 30)
		_prompt.position = at - Vector2(210, 30)


func _bar_row(key: String, bar: ProgressBar, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = tr(key)
	label.label_settings = settings(16)
	label.custom_minimum_size.x = 90.0
	row.add_child(label)
	bar.custom_minimum_size = Vector2(BAR_WIDTH, 18)
	bar.show_percentage = false
	bar.max_value = 100.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.1, 0.07, 0.05, 0.85)
	back.border_color = Color(0.05, 0.03, 0.02)
	back.set_border_width_all(2)
	back.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	row.add_child(bar)
	return row


static func settings(font_size: int) -> LabelSettings:
	var result := LabelSettings.new()
	result.font_size = font_size
	result.outline_size = 5
	result.outline_color = Color(0.1, 0.07, 0.05)
	return result
