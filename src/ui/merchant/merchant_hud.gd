class_name MerchantHud
extends CanvasLayer
## Raid HUD: the road strip and the gate countdown on top, loot and wagons top left, the
## leader's gauges bottom left and centre, the controls bottom right and big shouts for the
## turns of the raid.

const MARGIN := 24.0
const STRIP_SIDE := 0.16
const HINT_WIDTH := 430.0

var _strip := MerchantRoadStrip.new()
var _gauges := MerchantGauges.new()
var _shout := BattleShout.new()
var _timer := Label.new()
var _loot := Label.new()
var _prompt := Label.new()
var _hints := Label.new()
var _sim: MerchantSim
var _house := PackedColorArray()


func _ready() -> void:
	_gauges.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_gauges)
	add_child(_shout)
	add_child(_strip)
	_strip.anchor_left = STRIP_SIDE
	_strip.anchor_right = 1.0 - STRIP_SIDE
	_strip.offset_top = 8.0
	_strip.offset_bottom = 64.0
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for label: Label in [_timer, _loot, _prompt, _hints]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
	_timer.label_settings = _settings(28, Color(1.0, 0.97, 0.9))
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 68
	)
	_timer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_loot.label_settings = _settings(22, Color(1.0, 0.84, 0.35))
	_loot.position = Vector2(MARGIN, 10.0)
	_prompt.label_settings = _settings(18, Color(1.0, 0.97, 0.9))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 110
	)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hints.label_settings = _settings(14, Color(1.0, 0.97, 0.9))
	_hints.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hints.custom_minimum_size.x = HINT_WIDTH
	_hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hints.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, MARGIN
	)
	_hints.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hints.grow_vertical = Control.GROW_DIRECTION_BEGIN


## device: the raider's main device for the control hints, -1 for the computer.
func setup(sim: MerchantSim, house_colors: PackedColorArray, town: String, device: int) -> void:
	_sim = sim
	_house = house_colors
	_strip.setup(sim, house_colors, tr("MERCHANT_GATE_OF") % town)
	_gauges.setup(sim)
	_shout.clear()
	_hints.visible = device >= 0
	_hints.text = tr(
		"MERCHANT_KEYS_KEYBOARD" if device == BattleInputMap.Device.KEYBOARD else "MERCHANT_KEYS_PAD"
	)
	update_view()


func update_view() -> void:
	if _sim == null:
		return
	var s := _sim.state
	var seconds := ceili(_sim.seconds_left())
	var clock := "%d:%02d" % [floori(seconds / 60.0), seconds % 60]
	if s.phase == MerchantState.Phase.INTRO:
		_timer.text = tr("MERCHANT_INTRO_TIMER")
	else:
		_timer.text = tr("MERCHANT_GATE_TIMER") % clock
	var stopped := s.count_wagons(MerchantState.Wagon.STOPPED)
	_loot.text = "%s\n%s" % [
		tr("MERCHANT_LOOT") % s.loot(), tr("MERCHANT_WAGONS") % [stopped, s.wagon_count()]
	]
	var reachable := s.phase == MerchantState.Phase.RAID and _sim.pull_target() >= 0
	_prompt.visible = reachable and s.pull_wagon < 0 and _hints.visible
	_prompt.text = tr("MERCHANT_PROMPT_PULL")


func handle_events(events: Array[MerchantEvent]) -> void:
	var house := _house[0] if _house.size() > 0 else Color.RED
	var escort := Color(0.55, 0.5, 0.4)
	for event: MerchantEvent in events:
		match event.kind:
			MerchantEvent.Kind.RAID_START:
				_shout.shout(tr("MERCHANT_SHOUT_RAID"), "", house)
			MerchantEvent.Kind.ALARM:
				_shout.shout(tr("MERCHANT_SHOUT_ALARM"), tr("MERCHANT_SHOUT_ALARM_SUB"), escort)
			MerchantEvent.Kind.AMBUSH:
				_shout.shout(tr("MERCHANT_SHOUT_AMBUSH"), "", house)
			MerchantEvent.Kind.CAPTURED:
				_shout.shout(tr("MERCHANT_SHOUT_CAPTURED"), "", escort)
			MerchantEvent.Kind.OVER:
				if not _sim.state.captured:
					var clean := _sim.state.count_wagons(MerchantState.Wagon.ARRIVED) == 0
					var key := "MERCHANT_SHOUT_CLEAN" if clean else "MERCHANT_SHOUT_GATE"
					_shout.shout(tr(key), "", house)


func clear_shouts() -> void:
	_shout.clear()


static func _settings(font_size: int, color: Color) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = color
	settings.outline_size = 6
	settings.outline_color = Color(0.1, 0.07, 0.05)
	settings.shadow_size = 3
	settings.shadow_color = Color(0, 0, 0, 0.4)
	return settings
