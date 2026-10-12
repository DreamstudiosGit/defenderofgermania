class_name JoustHud
extends CanvasLayer
## Joust HUD: the helmet slit in the first-person phases, both riders' plates (stance, points),
## the pass, phase captions, the aim marks, the run-up gauge, the shield compass, control hints
## and big shouts for hits and falls.

const MARGIN := 20.0
const PLATE_WIDTH := 300.0
const HINT_SIZE := 15
const DARK_FIELD := 0.2
const SHOUT_HEIGHT := 0.55
const HELMET := preload("res://src/ui/joust/joust_helmet.gdshader")

var aim := JoustAimOverlay.new()
var tempo := JoustTempoGauge.new()
var shield := JoustShieldWidget.new()

var _helmet := ColorRect.new()
var _plates: Array[Plate] = []
var _pass := Label.new()
var _caption := Label.new()
var _hint := Label.new()
var _shout := BattleShout.new()
var _names: Array[String] = ["", ""]
var _colors: Array[PackedColorArray] = []


class Plate:
	extends VBoxContainer

	var title := Label.new()
	var points := Label.new()
	var bar := ProgressBar.new()

	func _init(right: bool) -> void:
		custom_minimum_size.x = PLATE_WIDTH
		var row := HBoxContainer.new()
		add_child(row)
		title.label_settings = JoustHud.settings(22)
		points.label_settings = JoustHud.settings(22)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(points if right else title)
		row.add_child(title if right else points)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
		bar.show_percentage = false
		bar.custom_minimum_size.y = 14.0
		bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN if right else ProgressBar.FILL_BEGIN_TO_END
		add_child(bar)

	func paint(color: Color) -> void:
		var fill := StyleBoxFlat.new()
		fill.bg_color = color
		fill.set_corner_radius_all(3)
		var back := StyleBoxFlat.new()
		back.bg_color = Color(0.1, 0.08, 0.06, 0.85)
		back.border_color = Color(1.0, 0.82, 0.3, 0.8)
		back.set_border_width_all(2)
		back.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", back)


func _ready() -> void:
	var material := ShaderMaterial.new()
	material.shader = HELMET
	_helmet.material = material
	_helmet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_helmet)
	_helmet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(aim)
	add_child(_shout)
	# Shouts sit in the upper part of the screen, above the riders.
	_shout.anchor_bottom = SHOUT_HEIGHT
	for r: int in JoustState.RIDERS:
		var plate := Plate.new(r == 1)
		add_child(plate)
		var preset := Control.PRESET_TOP_LEFT if r == 0 else Control.PRESET_TOP_RIGHT
		plate.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, MARGIN)
		plate.grow_horizontal = Control.GROW_DIRECTION_END if r == 0 else Control.GROW_DIRECTION_BEGIN
		_plates.append(plate)
	_pass.label_settings = settings(24)
	_pass.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_pass)
	_pass.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 18)
	_pass.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption.label_settings = settings(30)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_caption)
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_caption.offset_top = -190
	_caption.offset_bottom = -150
	add_child(tempo)
	tempo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	tempo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tempo.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tempo.offset_top = -120
	tempo.offset_bottom = -56
	add_child(shield)
	shield.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, MARGIN
	)
	shield.grow_vertical = Control.GROW_DIRECTION_BEGIN
	shield.offset_bottom = -42
	shield.offset_top = shield.offset_bottom - shield.custom_minimum_size.y
	_hint.label_settings = settings(HINT_SIZE)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 10)
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN


## Text key of a hit on a zone (data/combat_joust.json zone id).
static func hit_key(zone_id: String) -> String:
	return "JOUST_HIT_" + zone_id.to_upper()


## The field colour, or the charge when the field is too dark to read on the helmet.
static func readable(colors: PackedColorArray) -> Color:
	return colors[0].lightened(0.15) if colors[0].get_luminance() >= DARK_FIELD else colors[1]


static func settings(font_size: int) -> LabelSettings:
	var label := LabelSettings.new()
	label.font_size = font_size
	label.outline_size = maxi(4, font_size / 4)
	label.outline_color = Color(0.08, 0.06, 0.05)
	return label


## device: the player's BattleInputMap.Device, -1 for the computer (no hints).
func setup(
	names: Array[String], colors: Array[PackedColorArray], zones: Array[JoustConfig.Zone],
	device: int, practice: bool
) -> void:
	_names = names
	_colors = colors
	aim.set_zones(zones)
	aim.zone_labels = practice
	shield.set_colors(colors[0])
	for r: int in JoustState.RIDERS:
		var bright := readable(colors[r])
		_plates[r].title.text = names[r]
		_plates[r].title.label_settings.font_color = bright.lightened(0.25)
		_plates[r].paint(bright)
	if device < 0:
		_hint.text = ""
	else:
		var keyboard := device == BattleInputMap.Device.KEYBOARD
		_hint.text = tr("JOUST_HINT_KEYBOARD" if keyboard else "JOUST_HINT_PAD")
	_shout.clear()


func handle_events(sim: JoustSim) -> void:
	var state := sim.state
	for event: JoustEvent in state.events:
		match event.kind:
			JoustEvent.Kind.SPUR:
				if event.rider == 0 and not state.riders[0].last_spur_on_beat:
					tempo.off_beat()
			JoustEvent.Kind.HIT:
				if event.rider == 0:
					_shout_hit(sim)
				elif state.riders[0].last_shielded:
					_shout.shout(tr("JOUST_YOUR_SHIELD_HELD"), "", _colors[0][0])
			JoustEvent.Kind.UNSEAT:
				_shout.shout(tr("JOUST_UNSEATED") % _names[event.rider], "", _colors[event.rider][0])
			JoustEvent.Kind.DECIDING_PASS:
				_shout.shout(tr("JOUST_DRAW_DECIDING"), "", Color(1.0, 0.82, 0.3))


func update_view(sim: JoustSim, first_person: bool) -> void:
	var state := sim.state
	for r: int in JoustState.RIDERS:
		var rider := state.riders[r]
		_plates[r].points.text = "%d" % rider.points
		_plates[r].bar.max_value = sim.cfg.stance
		_plates[r].bar.value = maxf(rider.stance, 0.0)
	_helmet.visible = first_person
	_hint.visible = first_person
	_pass.text = _pass_text(sim)
	tempo.visible = first_person and state.phase in [JoustState.Phase.READY, JoustState.Phase.RUNUP]
	if tempo.visible:
		var running := state.phase == JoustState.Phase.RUNUP
		tempo.show_tempo(state.riders[0], sim, sim.pass_time() if running else -1.0)
	shield.visible = first_person
	_caption.text = _caption_text(sim)
	_caption.visible = not _caption.text.is_empty()


func _pass_text(sim: JoustSim) -> String:
	var state := sim.state
	var number := state.pass_count
	match state.phase:
		JoustState.Phase.INTRO, JoustState.Phase.FINALE, JoustState.Phase.OVER:
			return ""
		JoustState.Phase.READY, JoustState.Phase.RETURN:
			number += 1
	if number > sim.cfg.passes:
		return tr("JOUST_DECIDING")
	return tr("JOUST_PASS") % [number, sim.cfg.passes]


func _caption_text(sim: JoustSim) -> String:
	match sim.state.phase:
		JoustState.Phase.INTRO:
			return tr("JOUST_INTRO") % [_names[0], _names[1]]
		JoustState.Phase.READY:
			return tr("JOUST_READY")
		JoustState.Phase.RUNUP:
			return tr("JOUST_RUNUP")
		JoustState.Phase.AIM:
			return tr("JOUST_AIM")
	return ""


func _shout_hit(sim: JoustSim) -> void:
	var rider := sim.state.riders[0]
	var title := tr("JOUST_HIT_MISS")
	var subtitle := ""
	if not rider.last_couched:
		if is_nan(rider.strike_offset):
			subtitle = tr("JOUST_NOT_COUCHED")
		else:
			subtitle = tr("JOUST_TOO_EARLY" if rider.strike_offset < 0.0 else "JOUST_TOO_LATE")
	elif rider.last_zone >= 0:
		title = tr(hit_key(sim.cfg.zones[rider.last_zone].id))
		if rider.last_perfect:
			subtitle = tr("JOUST_LANCE_BREAKS")
		if sim.state.riders[1].last_shielded:
			subtitle = (subtitle + " · " if not subtitle.is_empty() else "") + tr("JOUST_SHIELD_HELD")
	if rider.last_couched and not is_nan(rider.strike_offset):
		subtitle += ("  (%+d ms)" % roundi(rider.strike_offset * 1000.0))
	_shout.shout(title, subtitle, _colors[0][0])
