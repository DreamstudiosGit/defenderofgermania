class_name SiegeHud
extends CanvasLayer
## HUD of the trebuchet minigame: castle and shot count top left, the wind top right, the aim
## panel bottom left (counterweight and angle sliders for the mouse, projectile choice, the
## throw button, the captain's patience), wall and garrison bottom right, HP bars over the
## castle parts, control hints and the big shouts. Mouse edits come back as signals; keys and
## sticks go through the minigame scene, which owns the aim.

signal aim_changed(counterweight: int, angle: int)
signal projectile_changed(projectile: TrebuchetShot.Projectile)
signal fire_requested

const MARGIN := 20.0
const PANEL_WIDTH := 400.0
const HINT_WIDTH := 600.0
const IMPATIENT_SECONDS := 10.0

var bars := SiegePartBars.new()
var shout := BattleShout.new()

var _title := Label.new()
var _castle_line := Label.new()
var _shots := Label.new()
var _message := Label.new()
var _wind := SiegeWindVane.new()
var _aim_panel := PanelContainer.new()
var _weight := HSlider.new()
var _weight_value := Label.new()
var _angle := HSlider.new()
var _angle_value := Label.new()
var _stone := Button.new()
var _pot := Button.new()
var _fire := Button.new()
var _patience := Label.new()
var _wall := ProgressBar.new()
var _garrison := ProgressBar.new()
var _hints := Label.new()
var _quiet: bool = false


func _ready() -> void:
	layer = 1
	add_child(bars)
	add_child(shout)
	_build_top_left()
	var wind_box := _panel(Control.PRESET_TOP_RIGHT)
	wind_box.add_child(_wind)
	_build_aim_panel()
	_build_status()
	_hints.label_settings = _settings(13)
	_hints.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hints.custom_minimum_size.x = HINT_WIDTH
	add_child(_hints)
	_hints.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE,
		MARGIN)
	_hints.grow_horizontal = Control.GROW_DIRECTION_BOTH


func setup(sim: TrebuchetSim, title: String, castle_line: String, hints: String) -> void:
	var cfg := sim.config
	_title.text = title
	_castle_line.text = castle_line
	_hints.text = hints
	_quiet = true
	_weight.min_value = cfg.counterweight_min
	_weight.max_value = cfg.counterweight_max
	_angle.min_value = cfg.angle_min
	_angle.max_value = cfg.angle_max
	_quiet = false
	_message.text = ""
	shout.clear()


## Shows the aim without echoing it back as a signal.
func show_aim(shot: TrebuchetShot) -> void:
	_quiet = true
	_weight.value = shot.counterweight
	_angle.value = shot.angle
	_quiet = false
	_weight_value.text = "%d %%" % shot.counterweight
	_angle_value.text = "%d°" % shot.angle
	_stone.button_pressed = shot.projectile == TrebuchetShot.Projectile.STONE
	_pot.button_pressed = shot.projectile == TrebuchetShot.Projectile.FIRE_POT


## Whether the player may aim now (their turn, a human crew).
func set_aiming(aiming: bool) -> void:
	_aim_panel.modulate.a = 1.0 if aiming else 0.55
	for control: Control in [_weight, _angle, _stone, _pot, _fire]:
		control.mouse_filter = Control.MOUSE_FILTER_STOP if aiming else Control.MOUSE_FILTER_IGNORE
	_fire.disabled = not aiming


func update_status(sim: TrebuchetSim, aim_left: float) -> void:
	var used := sim.shots_fired + sim.shots_lost
	var current := used if sim.is_over() else used + 1
	_shots.text = tr("SIEGE_SHOT") % [clampi(current, 1, maxi(sim.slots, 1)), sim.slots]
	if sim.shots_lost > 0:
		_shots.text += " · " + tr("SIEGE_SHOTS_LOST") % sim.shots_lost
	_wind.wind = sim.wind()
	_wind.limit = maxf(absf(sim.config.wind_min), absf(sim.config.wind_max))
	if sim.castle != null:
		var dealt := float(sim.castle.damage_dealt()) / sim.castle.wall_hp
		_wall.value = 100.0 * (1.0 - minf(1.0, sim.setup.wall_damage + dealt))
	_garrison.value = 100.0 * sim.garrison_health
	_patience.visible = aim_left >= 0.0 and aim_left <= IMPATIENT_SECONDS
	_patience.text = tr("SIEGE_AIM_TIME") % ceili(aim_left)


func message(text: String) -> void:
	_message.text = text


func _build_top_left() -> void:
	var box := _panel(Control.PRESET_TOP_LEFT)
	var column := VBoxContainer.new()
	box.add_child(column)
	_title.label_settings = _settings(26)
	column.add_child(_title)
	_castle_line.label_settings = _settings(16)
	column.add_child(_castle_line)
	_shots.label_settings = _settings(18)
	column.add_child(_shots)
	_message.label_settings = _settings(16)
	_message.modulate = Color(1.0, 0.9, 0.6)
	column.add_child(_message)


func _build_aim_panel() -> void:
	_aim_panel.add_theme_stylebox_override("panel", BattleResultPanel.panel_style())
	add_child(_aim_panel)
	_aim_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE,
		MARGIN)
	_aim_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = PANEL_WIDTH
	column.add_theme_constant_override("separation", 8)
	_aim_panel.add_child(column)
	column.add_child(_slider_row("SIEGE_COUNTERWEIGHT", _weight, _weight_value))
	column.add_child(_slider_row("SIEGE_ANGLE", _angle, _angle_value))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	var group := ButtonGroup.new()
	for entry: Array in [[_stone, "SIEGE_STONE", TrebuchetShot.Projectile.STONE],
			[_pot, "SIEGE_FIRE_POT", TrebuchetShot.Projectile.FIRE_POT]]:
		var button: Button = entry[0]
		button.text = tr(str(entry[1]))
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var kind: TrebuchetShot.Projectile = entry[2]
		button.pressed.connect(func() -> void: projectile_changed.emit(kind))
		row.add_child(button)
	_fire.text = tr("SIEGE_FIRE")
	_fire.focus_mode = Control.FOCUS_NONE
	_fire.add_theme_font_size_override("font_size", 22)
	_fire.pressed.connect(func() -> void: fire_requested.emit())
	column.add_child(_fire)
	_patience.label_settings = _settings(15)
	_patience.modulate = Color(1.0, 0.6, 0.45)
	column.add_child(_patience)


func _slider_row(key: String, slider: HSlider, value: Label) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = tr(key)
	label.custom_minimum_size.x = 130.0
	label.label_settings = _settings(16)
	row.add_child(label)
	slider.step = 1.0
	slider.focus_mode = Control.FOCUS_NONE
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(_on_slider_changed)
	row.add_child(slider)
	value.custom_minimum_size.x = 56.0
	value.label_settings = _settings(18)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return row


func _build_status() -> void:
	var box := _panel(Control.PRESET_BOTTOM_RIGHT)
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 260.0
	box.add_child(column)
	for entry: Array in [[_wall, "SIEGE_WALL", Color(0.75, 0.70, 0.60)],
			[_garrison, "SIEGE_GARRISON", Color(0.85, 0.35, 0.25)]]:
		var label := Label.new()
		label.text = tr(str(entry[1]))
		label.label_settings = _settings(16)
		column.add_child(label)
		var bar: ProgressBar = entry[0]
		bar.custom_minimum_size.y = 18.0
		bar.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = entry[2]
		bar.add_theme_stylebox_override("fill", fill)
		column.add_child(bar)


func _panel(preset: Control.LayoutPreset) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := BattleResultPanel.panel_style()
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, MARGIN)
	if preset == Control.PRESET_TOP_RIGHT or preset == Control.PRESET_BOTTOM_RIGHT:
		panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	return panel


func _on_slider_changed(_value: float) -> void:
	if not _quiet:
		aim_changed.emit(roundi(_weight.value), roundi(_angle.value))


static func _settings(font_size: int) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.outline_size = 4
	settings.outline_color = Color(0.1, 0.07, 0.05)
	return settings
