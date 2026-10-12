extends Node3D
## Merchant train raid (GDD "Kaufmannszug") in a side view along a river road. Opened directly
## it is the practice mode: how-to, a default raid, retry and quit. As a campaign adventure
## (configure_campaign) it plays the given setup — the raider's devices steer the leader, no
## device lets the computer raid — and reports finished(result) when the player continues.
## Quitting a practice run reports the last result too; with nobody listening it quits.

signal finished(result: MerchantResult)

const MAX_TICKS_PER_FRAME := 5
## Headless runs (tests) step several ticks per frame.
const HEADLESS_TICKS_PER_FRAME := 8
const FIRST_SEED := 1198
const PRACTICE_HOUSE := "welfen"
const PRACTICE_COMPANIES: Array[String] = ["spearmen", "levy"]

var _cfg: MerchantConfig
var _combat: CombatConfig
var _map: MapData
var _sim: MerchantSim
var _ai: MerchantAI
var _reader: MerchantInputReader
var _stage := MerchantStage.new()
var _view := MerchantView.new()
var _camera := MerchantCamera.new()
var _hud := MerchantHud.new()
var _practice_panel := MerchantPracticePanel.new()
var _result_panel := MerchantResultPanel.new()
var _setup: MerchantSetup = null
var _campaign: bool = false
var _devices := PackedInt32Array([BattleInputMap.Device.KEYBOARD, BattleInputMap.Device.PAD_1])
var _seed: int = FIRST_SEED
var _accumulator: float = 0.0
var _clock: float = 0.0
var _outro_left: float = 0.0
var _headless: bool = false
var _house_colors := PackedColorArray()
var _neutral := PackedColorArray()


## Plays a campaign raid instead of the practice; call before adding the scene to the tree.
## devices: BattleInputMap.Device values steering the leader; none (or only -1) lets the
## computer raid with setup.raider_skill.
func configure_campaign(setup: MerchantSetup, devices: PackedInt32Array, seed_value: int) -> void:
	_setup = setup
	_devices = devices
	_seed = seed_value
	_campaign = true


func _ready() -> void:
	_cfg = MerchantConfig.load_file()
	_combat = CombatConfig.load_file()
	_map = MapData.load_file()
	if _cfg == null or _combat == null or _map == null:
		push_error("merchant raid: data could not be loaded")
		return
	MerchantInputMap.register()
	_headless = DisplayServer.get_name() == "headless"
	if _setup == null:
		_setup = _practice_setup(1, 1)
	var heraldry := _map.heraldry()
	_house_colors = heraldry.get(_setup.house, PackedColorArray([Color.RED, Color.GOLD]))
	_neutral = heraldry.get("neutral", PackedColorArray([Color.TAN, Color.WHEAT]))
	_stage.build(_cfg, _setup, _map)
	add_child(_stage)
	add_child(_view)
	add_child(_camera)
	_camera.current = true
	if not _headless:
		get_viewport().msaa_3d = Viewport.MSAA_4X
		add_child(BattleInk.new())
	add_child(_hud)
	var overlay := CanvasLayer.new()
	overlay.layer = 2
	add_child(overlay)
	overlay.add_child(_practice_panel)
	overlay.add_child(_result_panel)
	_practice_panel.visible = false
	_result_panel.visible = false
	_practice_panel.start_requested.connect(_on_practice_start)
	_practice_panel.quit_requested.connect(_quit)
	_result_panel.retry_requested.connect(func() -> void: _start(_setup))
	_result_panel.quit_requested.connect(_quit)
	_result_panel.continue_requested.connect(func() -> void: finished.emit(_sim.result()))
	_start(_setup)
	if not _campaign and not _headless:
		_open_practice()


func _process(delta: float) -> void:
	if _sim == null:
		return
	var waiting := _practice_panel.visible or _result_panel.visible
	if _reader != null:
		_reader.poll()
		if _reader.menu_pressed() and not _campaign and not waiting:
			_open_practice()
			waiting = true
	if not _sim.is_over() and not waiting:
		if _headless:
			for i: int in HEADLESS_TICKS_PER_FRAME:
				_tick()
		else:
			_advance(delta)
	elif _sim.is_over() and not waiting:
		_outro_left -= delta
		if _outro_left <= 0.0:
			_show_result()
	_clock += delta
	var alpha := 1.0 if _headless else clampf(_accumulator * _sim.tick_rate, 0.0, 1.0)
	_view.update_view(alpha, _clock, delta)
	_frame_camera(delta)
	_hud.update_view()


func _advance(delta: float) -> void:
	_accumulator += delta
	var tick := _sim.tick_seconds()
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
	var input := _reader.take() if _reader != null else _ai.think(_sim)
	_view.snapshot()
	_sim.step(input)
	_view.play_events(_sim.state.events)
	_hud.handle_events(_sim.state.events)
	if _sim.is_over():
		_outro_left = _cfg.outro_seconds
		if _headless:
			var result := _sim.result()
			print("merchant raid over: %d of %d wagons, %d taler, captured %s after %.1f s" % [
				result.wagons_stopped, result.wagons_total, result.taler, result.leader_captured,
				result.seconds
			])


func _start(setup: MerchantSetup) -> void:
	_setup = setup
	_seed += 1
	_sim = MerchantSim.new(_cfg, _combat, setup, _seed)
	_reader = MerchantInputReader.new(_devices)
	_ai = null
	if _reader.is_empty() or _headless and not _campaign:
		_reader = null
		_ai = MerchantAI.new(_cfg, setup.raider_skill)
	_view.setup(_sim, _house_colors, _neutral)
	var town := tr("PROVINCE_" + setup.province)
	_hud.setup(_sim, _house_colors, town, _reader.main_device() if _reader != null else -1)
	_camera.setup(_cfg.leader_start(), _cfg.gate_x(), _cfg.gate_x())
	_accumulator = 0.0
	_clock = 0.0
	_outro_left = _cfg.outro_seconds
	_practice_panel.visible = false
	_result_panel.visible = false


func _frame_camera(delta: float) -> void:
	var s := _sim.state
	_hud.visible = not _practice_panel.visible
	if _practice_panel.visible:
		_camera.follow(_cfg.wagon_start(_cfg.wagons - 1), 1.0, delta)
	elif s.phase == MerchantState.Phase.INTRO:
		var share := float(s.tick) / maxf(1.0, _sim.intro_ticks())
		_camera.pan(s.gate_x, s.leader_x, share)
	else:
		_camera.follow(_view.people.leader_point().x, s.leader_facing, delta)


func _show_result() -> void:
	_hud.clear_shouts()
	_result_panel.show_result(_sim.result(), _setup.practice or not _campaign, _house_colors[0])


func _open_practice() -> void:
	_result_panel.visible = false
	_practice_panel.open(_setup.escort_skill, _setup.companies.size())


func _on_practice_start(escort_skill: int, companies: int) -> void:
	_start(_practice_setup(escort_skill, companies))


func _practice_setup(escort_skill: int, companies: int) -> MerchantSetup:
	var setup := MerchantSetup.new()
	setup.house = PRACTICE_HOUSE
	setup.escort_skill = escort_skill
	for c: int in mini(companies, PRACTICE_COMPANIES.size()):
		setup.companies.append(PRACTICE_COMPANIES[c])
	setup.practice = true
	return setup


func _quit() -> void:
	finished.emit(_sim.result() if _sim != null else MerchantResult.new())
	if finished.get_connections().is_empty():
		get_tree().quit()
