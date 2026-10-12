extends Node3D
## Joust scene. Opened directly it is the practice mode: setup menu with a short how-to, the
## joust, a result panel with retry and quit. As a campaign joust (configure_campaign) it rides
## the given setup and reports `finished` — at once when nobody human rides, else on "continue".
## The simulation runs on its fixed tick; the view interpolates between ticks.

signal finished(result: JoustResult)
## Practice mode's quit button; when nothing is connected the game quits.
signal quit_requested

const MAX_TICKS_PER_FRAME := 5
## Headless runs (tests, smoke runs) let the computer ride and step several ticks per frame.
const HEADLESS_TICKS_PER_FRAME := 8
const FIRST_SEED := 1198
## Skill the computer rides with when it takes the player's side (spectating, headless).
const STAND_IN_SKILL := 2

var _cfg: JoustConfig
var _heraldry: Dictionary[String, PackedColorArray] = {}
var _houses: Array[String] = []
var _sim: JoustSim
var _setup := JoustSetup.practice_default()
var _campaign: JoustSetup = null
var _devices := PackedInt32Array([BattleInputMap.Device.KEYBOARD, -1])
var _seed: int = FIRST_SEED
var _readers: Array[JoustInputReader] = [null, null]
var _ais: Array[JoustAI] = [null, null]
var _lists: JoustLists
var _riders := JoustRiders.new()
var _camera := JoustCamera.new()
var _hud := JoustHud.new()
var _menu := JoustMenu.new()
var _result_panel := JoustResultPanel.new()
var _accumulator: float = 0.0
var _previous_tips: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _headless: bool = false
var _names: Array[String] = ["", ""]
var _colors: Array[PackedColorArray] = []
var _owners: Array[String] = []
var _reported: bool = false


func _ready() -> void:
	_cfg = JoustConfig.load_file()
	var map := MapData.load_file()
	if _cfg == null or map == null:
		push_error("joust: data/combat_joust.json, combat.json or map.json could not be loaded")
		return
	_heraldry = map.heraldry()
	_houses = map.houses
	JoustInputMap.register()
	_headless = DisplayServer.get_name() == "headless"
	if not _headless:
		get_viewport().msaa_3d = Viewport.MSAA_4X
	add_child(_riders)
	add_child(_camera)
	_camera.current = true
	if not _headless:
		add_child(BattleInk.new())
	add_child(_hud)
	var overlay := CanvasLayer.new()
	overlay.layer = 2
	add_child(overlay)
	overlay.add_child(_menu)
	overlay.add_child(_result_panel)
	_result_panel.visible = false
	_menu.visible = false
	_menu.start_requested.connect(_on_start_requested)
	_menu.quit_requested.connect(_quit)
	_result_panel.retry_requested.connect(func() -> void: _start(_setup))
	_result_panel.setup_requested.connect(_open_menu)
	_result_panel.quit_requested.connect(_quit)
	_result_panel.continue_requested.connect(_report)
	if _campaign != null:
		_start(_campaign)
	elif _headless:
		_devices = PackedInt32Array([-1, -1])
		_start(_setup)
	else:
		_prepare(_setup)
		_open_menu()


## Rides a campaign joust instead of the practice menu; call before adding the scene to the
## tree. devices[0] is the player's BattleInputMap.Device or -1 for the computer; the opponent
## (rider 1) is always the computer with setup.opponent_skill.
func configure_campaign(setup: JoustSetup, devices: PackedInt32Array, seed_value: int) -> void:
	_campaign = setup
	_devices = PackedInt32Array([devices[0] if devices.size() > 0 else -1, -1])
	_seed = seed_value


func _process(delta: float) -> void:
	if _sim == null:
		return
	var dt := _sim.tick_seconds()
	var running := not _menu.visible and not _sim.is_over()
	if running:
		_accumulator += delta
	var now := _sim.state.tick * dt + _accumulator
	for reader: JoustInputReader in _readers:
		if reader == null:
			continue
		reader.poll(now)
		if reader.menu_pressed() and _campaign == null and not _menu.visible:
			_open_menu()
			return
	if running:
		var steps := 0
		var budget := HEADLESS_TICKS_PER_FRAME if _headless else MAX_TICKS_PER_FRAME
		while (_headless or _accumulator >= dt) and steps < budget and not _sim.is_over():
			_tick()
			_accumulator = maxf(_accumulator - dt, 0.0)
			steps += 1
		if steps == budget:
			_accumulator = 0.0
	_update_view(1.0 if _headless else clampf(_accumulator / dt, 0.0, 1.0), delta)
	_capture_mouse(_camera.first_person and running)


## Moves riders, camera and HUD to `alpha` of the way to the next tick.
func _update_view(alpha: float, delta: float) -> void:
	_riders.update_view(_sim, alpha, delta)
	_camera.frame(_sim, _riders, alpha, delta)
	_riders.hide_body(0 if _camera.first_person else -1)
	_hud.update_view(_sim, _camera.first_person)
	_show_aim(alpha)


func _input(event: InputEvent) -> void:
	for reader: JoustInputReader in _readers:
		if reader != null:
			reader.handle_event(event)


func _exit_tree() -> void:
	_capture_mouse(false)


func _tick() -> void:
	if _sim.is_over():
		return
	var state := _sim.state
	var dt := _sim.tick_seconds()
	var inputs: Array[JoustInput] = []
	for r: int in JoustState.RIDERS:
		if _readers[r] != null:
			inputs.append(_readers[r].take(state.tick * dt, dt, _cfg.aim_range))
		else:
			inputs.append(_ais[r].think(_sim))
	for r: int in JoustState.RIDERS:
		_previous_tips[r] = state.riders[r].tip
	var before := state.phase
	_sim.step(inputs[0], inputs[1])
	if state.phase == JoustState.Phase.AIM and before != JoustState.Phase.AIM:
		for reader: JoustInputReader in _readers:
			if reader != null:
				reader.begin_aim(_cfg.aim_rest)
	_riders.handle_events(_sim)
	_hud.handle_events(_sim)
	for event: JoustEvent in state.events:
		if event.kind in [JoustEvent.Kind.HIT, JoustEvent.Kind.UNSEAT, JoustEvent.Kind.FINALE]:
			if event.kind != JoustEvent.Kind.HIT or state.riders[event.rider].last_zone >= 0:
				_lists.crowd.cheer()
	if _sim.is_over():
		_finish()


func _start(setup: JoustSetup) -> void:
	if _campaign == null:
		_seed += 1
	_prepare(setup)
	for r: int in JoustState.RIDERS:
		var human := _devices[r] >= 0 and not _headless
		_readers[r] = JoustInputReader.new(_devices[r]) if human else null
		var skill := setup.opponent_skill if r == 1 else STAND_IN_SKILL
		_ais[r] = null if human else JoustAI.for_skill(_cfg, r, skill, _seed)
	_hud.setup(_names, _colors, _cfg.zones, _devices[0] if _readers[0] != null else -1, setup.practice)
	_result_panel.set_practice(_campaign == null)
	_result_panel.visible = false
	_menu.visible = false
	_hud.visible = true
	_accumulator = 0.0
	_reported = false


## Builds the lists and riders for a setup and a fresh simulation (shown behind the menu).
func _prepare(setup: JoustSetup) -> void:
	_setup = setup
	_sim = JoustSim.new(_cfg, setup)
	var owners := setup.owners()
	_colors.clear()
	for r: int in JoustState.RIDERS:
		var colors: PackedColorArray = _heraldry.get(owners[r], PackedColorArray())
		if colors.size() < 2:
			colors = PackedColorArray([Color(0.6, 0.55, 0.45), Color(0.85, 0.8, 0.65)])
		_colors.append(colors)
		_names[r] = tr("BATTLE_HOUSE_" + owners[r].to_upper())
	if owners != _owners or _lists == null:
		if _lists != null:
			_lists.free()
		_lists = JoustLists.new()
		add_child(_lists)
		_lists.build(_colors)
		_riders.setup(owners, _colors)
		_owners = owners
	_riders.reset()
	for r: int in JoustState.RIDERS:
		_previous_tips[r] = _sim.state.riders[r].tip


func _show_aim(alpha: float) -> void:
	var state := _sim.state
	var dt := _sim.tick_seconds()
	var in_clash := state.phase == JoustState.Phase.CLASH
	var clash_time := (state.phase_tick + alpha) * dt
	_hud.aim.visible = _camera.first_person and (state.phase == JoustState.Phase.AIM or in_clash)
	var me := state.riders[0]
	var opponent := state.riders[1]
	var tip := me.impact_tip if in_clash else _previous_tips[0].lerp(me.tip, alpha)
	var incoming := opponent.impact_tip if in_clash else _previous_tips[1].lerp(opponent.tip, alpha)
	if _hud.aim.visible:
		var chest := _riders.chest(1)
		var axes := JoustTrack.target_axes(_riders.hand(0), chest)
		var until := _sim.impact_time() - (_sim.pass_tick() + alpha) * dt
		if in_clash:
			until = -clash_time
		var goal := _readers[0].goal() if _readers[0] != null else me.aim_target
		_hud.aim.show_aim(_camera, chest, axes, tip, goal, until, me.window, _readers[0] != null)
		if _readers[0] != null:
			var frame := _hud.aim.screen_frame()
			_readers[0].set_screen_frame(frame[0], frame[1])
	var aiming := state.phase == JoustState.Phase.AIM
	var aligned := aiming and JoustStrike.shield_aligned(_cfg, me.shield, incoming)
	_hud.shield.show_shield(Vector2(-incoming.x, incoming.y), me.shield, aligned, aiming)


func _finish() -> void:
	var result := _sim.result()
	if _headless:
		print("joust over: won %s, %d:%d after %d passes in %.1f s" % [
			result.won, result.player_points, result.opponent_points, result.passes,
			result.duration
		])
	if _campaign != null and _readers[0] == null:
		_report()
		return
	_result_panel.show_result(result, _names, _colors)


func _report() -> void:
	if _reported:
		return
	_reported = true
	finished.emit(_sim.result())


func _open_menu() -> void:
	_result_panel.visible = false
	_hud.visible = false
	_capture_mouse(false)
	_menu.open(_houses, _setup, _devices[0])


func _on_start_requested(setup: JoustSetup, device: int) -> void:
	_devices = PackedInt32Array([device, -1])
	_start(setup)


func _quit() -> void:
	quit_requested.emit()
	if quit_requested.get_connections().is_empty():
		get_tree().quit()


func _capture_mouse(captured: bool) -> void:
	if _headless or _readers[0] == null and captured:
		return
	var wanted := Input.MOUSE_MODE_CONFINED_HIDDEN if captured else Input.MOUSE_MODE_VISIBLE
	if _readers[0] != null and _readers[0].device != BattleInputMap.Device.KEYBOARD:
		wanted = Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != wanted:
		Input.mouse_mode = wanted
