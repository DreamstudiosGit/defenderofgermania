extends Node3D
## Real-time battle scene. As the prototype (main scene): start menu, battle between human or
## computer sides on the simulation's fixed tick, interpolated presentation, result screen,
## restart. As a campaign battle (configure_campaign): the given setup, then battle_finished.

signal battle_finished(result: BattleResult)

const MAX_TICKS_PER_FRAME := 5
const SLOWMO_SECONDS := 0.5
const SLOWMO_SCALE := 0.3
const SLOWMO_GAP := 3.0
## Headless runs (the smoke test) skip the menu, let the computer play both sides and step
## several ticks per frame, so `godot --headless --quit-after 600` reaches the melee.
const HEADLESS_TICKS_PER_FRAME := 4
const FIRST_SEED := 1198

var _cfg: CombatConfig
var _sim: BattleSim
var _field := BattleField.new()
var _figures := BattleFigures.new()
var _volleys := BattleVolleys.new()
var _dust := BattleDust.new()
var _tumblers := BattleTumblers.new()
var _markers := BattleMarkers.new()
var _camera := BattleCamera.new()
var _hud := BattleHud.new()
var _menu := BattleMenu.new()
var _result_panel := BattleResultPanel.new()
var _readers: Array[BattleInputReader] = [null, null]
var _ais: Array[BattleAI] = [null, null]
var _devices := PackedInt32Array([BattleInputMap.Device.KEYBOARD, -1])
var _seed: int = FIRST_SEED
var _accumulator: float = 0.0
var _slowmo_left: float = 0.0
var _slowmo_cooldown: float = 0.0
var _previous_figures := PackedVector2Array()
var _previous_positions := PackedVector2Array()
var _headless: bool = false
var _campaign: BattleSetup = null


func _ready() -> void:
	_cfg = CombatConfig.load_file()
	var map := MapData.load_file()
	if _cfg == null or map == null:
		push_error("battle: data/combat.json or data/map.json could not be loaded")
		return
	if _campaign != null:
		_cfg.battle.armies.assign([_preset(_campaign.attacker), _preset(_campaign.defender)])
	_cfg.battle.apply_house_colors(map.heraldry())
	BattleInputMap.register()
	_headless = DisplayServer.get_name() == "headless"
	if not _headless:
		get_viewport().msaa_3d = Viewport.MSAA_4X
	_field.build(_cfg.battle, _cfg.battle.armies)
	add_child(_field)
	add_child(_figures)
	add_child(_volleys)
	add_child(_dust)
	add_child(_tumblers)
	add_child(_markers)
	add_child(_camera)
	_camera.current = true
	if not _headless:
		add_child(BattleInk.new())
	_camera.setup(_cfg.battle.field_size, _cfg.battle.field_size * 0.5)
	add_child(_hud)
	var overlay := CanvasLayer.new()
	overlay.layer = 2
	add_child(overlay)
	overlay.add_child(_menu)
	overlay.add_child(_result_panel)
	_result_panel.visible = false
	_menu.start_requested.connect(_on_start_requested)
	_result_panel.play_again_requested.connect(_start)
	_result_panel.setup_requested.connect(_open_menu)
	_result_panel.continue_requested.connect(
		func() -> void: battle_finished.emit(_sim.result())
	)
	_result_panel.set_campaign(_campaign != null)
	if _campaign != null:
		_start()
	elif _headless:
		_devices = PackedInt32Array([-1, -1])
		_start()
	else:
		_open_menu()


func _process(delta: float) -> void:
	if _sim == null:
		return
	for reader: BattleInputReader in _readers:
		if reader == null:
			continue
		reader.poll()
		_camera.zoom(reader.take_zoom())
		if reader.menu_pressed() and not _menu.visible and _campaign == null:
			_open_menu()
	var tick := _sim.tick_seconds()
	if not _sim.is_over() and not _menu.visible:
		if _headless:
			for i: int in HEADLESS_TICKS_PER_FRAME:
				_tick()
		else:
			_advance(delta, tick)
	var alpha := 1.0 if _headless else clampf(_accumulator / tick, 0.0, 1.0)
	var positions := _interpolated(_previous_positions, _sim.state.pos, alpha)
	_figures.update_view(_sim.state, _previous_figures, alpha)
	_dust.update_view(_sim.state, positions, delta)
	_tumblers.update_view(_sim.state, delta)
	_markers.update_view(
		_sim.state, _sim.rules, positions, _selection_sides(), _marker_colors(), _humans()
	)
	var middle := _cfg.battle.field_size * 0.5
	var focus := BattleCamera.action_focus(_sim.state, positions, _selection_sides(), middle)
	_camera.frame(BattleCamera.company_points(_sim.state, positions), focus, delta)
	_hud.update_view(_sim, positions, delta)


func _unhandled_input(event: InputEvent) -> void:
	if _sim == null or _menu.visible or _sim.is_over():
		return
	for reader: BattleInputReader in _readers:
		if reader != null:
			reader.handle_event(event, _camera)


func _advance(delta: float, tick: float) -> void:
	_slowmo_cooldown -= delta
	var time_scale := SLOWMO_SCALE if _slowmo_left > 0.0 else 1.0
	_slowmo_left -= delta
	_accumulator += delta * time_scale
	var steps := 0
	while _accumulator >= tick and steps < MAX_TICKS_PER_FRAME and not _sim.is_over():
		_tick()
		_accumulator -= tick
		steps += 1
	if steps == MAX_TICKS_PER_FRAME:
		_accumulator = 0.0


func _tick() -> void:
	if _sim.is_over():
		return
	var state := _sim.state
	var inputs: Array[BattleInput] = []
	for s: int in BattleState.SIDES:
		if _readers[s] != null:
			inputs.append(_readers[s].take())
		else:
			inputs.append(_ais[s].think(state, _sim.rules))
	_previous_figures = state.fig_pos.duplicate()
	_previous_positions = state.pos.duplicate()
	_sim.step(inputs[0], inputs[1])
	_hud.handle_events(state)
	for event: BattleEvent in state.events:
		match event.kind:
			BattleEvent.Kind.FIGHT_START:
				_field.show_zones(false)
			BattleEvent.Kind.VOLLEY:
				_volleys.launch(state.pos[event.company], state.pos[event.target])
			BattleEvent.Kind.SHOT:
				var engine := event.company
				var flight := _sim.rules.siege_flight_seconds
				_volleys.launch_stone(state.pos[engine], state.shot_point[engine], flight)
			BattleEvent.Kind.BLAST:
				_dust.burst(state.shot_point[event.company], 16, 6.0)
			BattleEvent.Kind.IMPACT:
				_dust.burst(state.pos[event.target], 10, state.radius[event.target])
				if _slowmo_cooldown <= 0.0:
					_slowmo_left = SLOWMO_SECONDS
					_slowmo_cooldown = SLOWMO_GAP
	if _sim.is_over():
		_finish()


func _start() -> void:
	var setup := _campaign
	if setup == null:
		_seed += 1
		setup = _cfg.battle.default_setup()
	setup.attacker.is_human = _devices[0] >= 0
	setup.defender.is_human = _devices[1] >= 0
	_sim = BattleSim.new(_cfg, setup, _seed)
	for s: int in BattleState.SIDES:
		var human := _devices[s] >= 0
		_readers[s] = BattleInputReader.new(_devices[s]) if human else null
		_ais[s] = null if human else BattleAI.new(s, _seed * 2 + s)
	_figures.setup(_sim.state, _cfg.battle.armies, _sim.tick_seconds())
	_figures.set_selection_sides(_selection_sides())
	_hud.setup(_sim.state, _cfg.battle.armies, _devices, _camera)
	_volleys.clear()
	_dust.clear()
	_tumblers.setup(_sim.state, _cfg.battle.armies)
	_field.show_zones(true)
	_menu.visible = false
	_result_panel.visible = false
	_previous_figures = _sim.state.fig_pos.duplicate()
	_previous_positions = _sim.state.pos.duplicate()
	_accumulator = 0.0
	_slowmo_left = 0.0
	_camera.setup(_cfg.battle.field_size, _cfg.battle.field_size * 0.5)


func _finish() -> void:
	if _headless:
		var result := _sim.result()
		print("battle over: attacker won %s after %.1f s" % [result.attacker_won, result.duration])
	_result_panel.show_result(_sim, _cfg.battle.armies)


## Plays a campaign battle instead of the prototype menu; call before adding the scene to the
## tree. devices[s] is a BattleInputMap.Device, or -1 for a computer side.
func configure_campaign(setup: BattleSetup, devices: PackedInt32Array, seed_value: int) -> void:
	_campaign = setup
	_devices = devices
	_seed = seed_value


func _open_menu() -> void:
	_result_panel.visible = false
	_menu.open(_cfg.battle.armies, _devices)


func _on_start_requested(devices: PackedInt32Array) -> void:
	_devices = devices
	_start()


static func _preset(side: BattleSide) -> BattleRules.ArmyPreset:
	var army := BattleRules.ArmyPreset.new()
	army.house = side.owner
	army.has_leader = side.has_leader
	army.leadership = side.leadership
	army.units = side.units.duplicate()
	return army


func _humans() -> Array[bool]:
	return [_devices[0] >= 0, _devices[1] >= 0]


func _selection_sides() -> Array[bool]:
	var humans := _humans()
	if humans[0] != humans[1]:
		return humans
	var hidden: Array[bool] = [false, false]
	return hidden


func _marker_colors() -> Array[Color]:
	return [_cfg.battle.armies[0].accent, _cfg.battle.armies[1].accent]


static func _interpolated(
	previous: PackedVector2Array, current: PackedVector2Array, alpha: float
) -> PackedVector2Array:
	if previous.size() != current.size():
		return current
	var result := PackedVector2Array()
	result.resize(current.size())
	for i: int in current.size():
		result[i] = previous[i].lerp(current[i], alpha)
	return result
