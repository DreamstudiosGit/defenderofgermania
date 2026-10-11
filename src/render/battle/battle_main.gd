extends Node3D
## Battle prototype P1 (main scene): start menu, real-time battle between human or computer
## sides on the simulation's fixed tick, interpolated presentation, result screen, restart.

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


func _ready() -> void:
	_cfg = CombatConfig.load_file()
	if _cfg == null:
		push_error("battle: data/combat.json could not be loaded")
		return
	BattleInputMap.register()
	_headless = DisplayServer.get_name() == "headless"
	_field.build(_cfg.battle, _cfg.battle.armies)
	add_child(_field)
	add_child(_figures)
	add_child(_volleys)
	add_child(_markers)
	add_child(_camera)
	_camera.current = true
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
	if _headless:
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
		if reader.menu_pressed() and not _menu.visible:
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
	_markers.update_view(_sim.state, _sim.rules, positions, _humans(), _marker_colors())
	_hud.update_view(_sim, positions, delta)
	_camera.follow(_focus(positions), delta)


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
			BattleEvent.Kind.IMPACT:
				if _slowmo_cooldown <= 0.0:
					_slowmo_left = SLOWMO_SECONDS
					_slowmo_cooldown = SLOWMO_GAP
	if _sim.is_over():
		_finish()


func _start() -> void:
	_seed += 1
	var setup := _cfg.battle.default_setup()
	setup.attacker.is_human = _devices[0] >= 0
	setup.defender.is_human = _devices[1] >= 0
	_sim = BattleSim.new(_cfg, setup, _seed)
	for s: int in BattleState.SIDES:
		var human := _devices[s] >= 0
		_readers[s] = BattleInputReader.new(_devices[s]) if human else null
		_ais[s] = null if human else BattleAI.new(s, _seed * 2 + s)
	_figures.setup(_sim.state, _cfg.battle.armies)
	_hud.setup(_sim.state, _cfg.battle.armies, _devices, _camera)
	_volleys.clear()
	_field.show_zones(true)
	_menu.visible = false
	_result_panel.visible = false
	_previous_figures = _sim.state.fig_pos.duplicate()
	_previous_positions = _sim.state.pos.duplicate()
	_accumulator = 0.0
	_slowmo_left = 0.0
	_camera.zoomed_out = not (_devices[0] >= 0 or _devices[1] >= 0)
	_camera.setup(_cfg.battle.field_size, _focus(_sim.state.pos))


func _finish() -> void:
	if _headless:
		var result := _sim.result()
		print("battle over: attacker won %s after %.1f s" % [result.attacker_won, result.duration])
	_result_panel.show_result(_sim, _cfg.battle.armies)


func _open_menu() -> void:
	_result_panel.visible = false
	_menu.open(_cfg.battle.armies, _devices)


func _on_start_requested(devices: PackedInt32Array) -> void:
	_devices = devices
	_start()


## Human players' active groups, or the whole battle when only the computer plays.
func _focus(positions: PackedVector2Array) -> Vector2:
	var state := _sim.state
	var sum := Vector2.ZERO
	var count := 0
	for c: int in state.company_count():
		if not state.is_present(c) or c >= positions.size():
			continue
		var s := state.side[c]
		var humans := _devices[0] >= 0 or _devices[1] >= 0
		if humans and (_devices[s] < 0 or state.group[c] != state.active_group[s]):
			continue
		sum += positions[c]
		count += 1
	return sum / count if count > 0 else _cfg.battle.field_size * 0.5


func _humans() -> Array[bool]:
	return [_devices[0] >= 0, _devices[1] >= 0]


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
