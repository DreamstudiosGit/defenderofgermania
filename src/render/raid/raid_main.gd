extends Node3D
## Castle raid scene (M6 "Abenteuer"), a torch-lit side view. Opened directly it is the practice
## mode: setup screen with a short how-to, the raid, then again, back to the setup or quit. As a
## campaign raid (configure_campaign) it plays the given setup and reports through `finished`.

signal finished(result: RaidResult)

enum Phase { MENU, INTRO, RAID, OUTRO, RESULT }

const MAX_TICKS_PER_FRAME := 5
## Headless runs (tests) skip intro and outro, play fast and report at once.
const HEADLESS_TICKS_PER_FRAME := 30
const FIRST_SEED := 1198

var _cfg: RaidConfig
var _heraldry: Dictionary[String, PackedColorArray] = {}
var _sim: RaidSim
var _setup := RaidSetup.new()
var _campaign: RaidSetup = null
var _device: int = BattleInputMap.Device.KEYBOARD
var _seed: int = FIRST_SEED
var _reader: RaidInputReader
var _ai: RaidAI
var _phase := Phase.MENU
var _phase_left: float = 0.0
var _accumulator: float = 0.0
var _previous := PackedFloat64Array()
var _headless: bool = false
var _flee: bool = false
var _last_result: RaidResult = null

var _scenery: Node3D
var _world: RaidWorld
var _dressing: RaidDressing
var _room: RaidTargetRoom
var _figures: RaidFigures
var _effects := RaidEffects.new()
var _feedback := RaidFeedback.new()
var _camera := RaidCamera.new()
var _hud := RaidHud.new()
var _menu := RaidMenu.new()
var _pause := RaidPausePanel.new()
var _result_panel := RaidResultPanel.new()


func _ready() -> void:
	_cfg = RaidConfig.load_file()
	var map := MapData.load_file()
	if _cfg == null or map == null:
		push_error("raid: data/combat_raid.json or data/map.json could not be loaded")
		return
	_heraldry = map.heraldry()
	RaidInputMap.register()
	_headless = DisplayServer.get_name() == "headless"
	_build_environment()
	add_child(_effects)
	add_child(_camera)
	_camera.current = true
	if not _headless:
		get_viewport().msaa_3d = Viewport.MSAA_4X
		add_child(BattleInk.new())
	add_child(_hud)
	var overlay := CanvasLayer.new()
	overlay.layer = 2
	add_child(overlay)
	for panel: Control in [_menu, _pause, _result_panel]:
		overlay.add_child(panel)
	_result_panel.visible = false
	_hud.visible = false
	_menu.start_requested.connect(_on_start_requested)
	_menu.quit_requested.connect(_quit_practice)
	_pause.resume_requested.connect(func() -> void: _pause.visible = false)
	_pause.flee_requested.connect(_on_flee_requested)
	_pause.quit_requested.connect(_quit_practice)
	_result_panel.retry_requested.connect(func() -> void: _start(_setup, _device))
	_result_panel.setup_requested.connect(func() -> void: _menu.open(_setup, _device, _cfg))
	_result_panel.quit_requested.connect(_quit_practice)
	_result_panel.continue_requested.connect(func() -> void: finished.emit(_last_result))
	_result_panel.set_campaign(_campaign != null)
	_setup.practice = true
	if _campaign != null:
		_start(_campaign, _device)
	elif _headless:
		_start(_setup, -1)
	else:
		_menu.open(_setup, _device, _cfg)


## Plays a campaign raid instead of the practice; call before adding the scene to the tree.
## devices[0] is the leader's BattleInputMap.Device, or -1 for the computer.
func configure_campaign(setup: RaidSetup, devices: PackedInt32Array, seed_value: int) -> void:
	_campaign = setup.copy()
	_campaign.practice = false
	_device = devices[0] if devices.size() > 0 else -1
	_seed = seed_value


func _process(delta: float) -> void:
	if _sim == null:
		return
	if _reader != null and (_phase == Phase.INTRO or _phase == Phase.RAID) and not _pause.visible:
		_reader.poll()
		if _reader.menu_pressed():
			_pause.open(_campaign == null)
	_feedback.update(delta)
	_hud.visible = _phase != Phase.RESULT and not _menu.visible
	if not _pause.visible:
		match _phase:
			Phase.INTRO:
				_phase_left -= delta
				if _phase_left <= 0.0:
					_phase = Phase.RAID
			Phase.RAID:
				_advance(delta)
			Phase.OUTRO:
				_phase_left -= delta
				if _phase_left <= 0.0:
					_show_result()
	_update_view(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _reader == null or _phase != Phase.RAID or _pause.visible:
		return
	var span := _figures.leader_span(_camera)
	_reader.handle_event(event, span.x, span.y)


func _advance(delta: float) -> void:
	if _headless:
		for i: int in HEADLESS_TICKS_PER_FRAME:
			_tick()
		return
	var tick := _sim.tick_seconds()
	_accumulator += delta
	var steps := 0
	while _accumulator >= tick and steps < MAX_TICKS_PER_FRAME and _phase == Phase.RAID:
		_tick()
		_accumulator -= tick
		steps += 1
	if steps == MAX_TICKS_PER_FRAME:
		_accumulator = 0.0


func _tick() -> void:
	if _sim.is_over():
		return
	var input := _reader.take() if _reader != null else _ai.think(_sim)
	input.flee = input.flee or _flee
	_flee = false
	_previous = _positions()
	_sim.step(input)
	_show_events()
	if _sim.is_over():
		_end_raid()


func _start(setup: RaidSetup, device: int) -> void:
	_setup = setup.copy()
	_device = device
	_sim = RaidSim.new(_cfg, _setup, _seed)
	_reader = RaidInputReader.new(device) if device >= 0 else null
	# The computer leader fences as well as his blade: blade 1–2 clumsy … 4–5 masterly.
	_ai = null if device >= 0 else RaidAI.new(_cfg, clampi(_setup.blade - 1, 0, 3), _seed)
	_build_scenery()
	_previous = _positions()
	_accumulator = 0.0
	_flee = false
	_menu.visible = false
	_pause.visible = false
	_result_panel.visible = false
	_hud.setup(_setup.target, device)
	_camera.snap(_figures.leader.position, _world.floor_y(_figures.leader.position.x))
	_phase = Phase.INTRO
	_phase_left = 0.0 if _headless else _cfg.intro_seconds
	var owner_name := tr("RAID_OWNER_" + _setup.defender_owner.to_upper())
	_hud.shout(
		tr("RAID_TARGET_" + _setup.target.to_upper()),
		tr("RAID_INTRO") % owner_name, GroupShield.GOLD
	)
	if _sim.is_over():
		_end_raid()


func _build_scenery() -> void:
	if _scenery != null:
		_scenery.queue_free()
	_scenery = Node3D.new()
	add_child(_scenery)
	var raider_colors := _colors(_setup.raider_house)
	var defender_colors := _colors(_setup.defender_owner)
	_world = RaidWorld.new()
	_scenery.add_child(_world)
	_world.build(_sim.layout, _seed)
	_dressing = RaidDressing.new()
	_scenery.add_child(_dressing)
	_dressing.build(_world, defender_colors, _seed)
	_room = RaidTargetRoom.new()
	_scenery.add_child(_room)
	_room.build(_world, _setup.target, raider_colors, _seed)
	_figures = RaidFigures.new()
	_scenery.add_child(_figures)
	_figures.setup(
		_cfg, _world, _sim.state, _setup.raider_house, raider_colors, _setup.defender_owner,
		defender_colors
	)
	_figures.update_view(_sim, _positions(), 1.0, 0.0)


func _end_raid() -> void:
	_last_result = _sim.result()
	_phase = Phase.OUTRO
	_phase_left = 0.0 if _headless else _cfg.outro_seconds
	var keys := {
		RaidResult.Outcome.SUCCESS: "RAID_RESULT_SUCCESS",
		RaidResult.Outcome.CAPTURED: "RAID_RESULT_CAPTURED",
		RaidResult.Outcome.ESCAPED_WOUNDED: "RAID_RESULT_ESCAPED",
	}
	var color := GroupShield.GOLD if _last_result.success else Color(0.9, 0.4, 0.3)
	_hud.shout(tr(str(keys[_last_result.outcome])), "", color)


func _show_result() -> void:
	_phase = Phase.RESULT
	if _headless:
		finished.emit(_last_result)
		return
	_result_panel.set_campaign(_campaign != null)
	_result_panel.show_result(_last_result, _cfg)


func _update_view(delta: float) -> void:
	var alpha := clampf(_accumulator / _sim.tick_seconds(), 0.0, 1.0)
	if _headless or _phase != Phase.RAID:
		alpha = 1.0
	_figures.update_view(_sim, _previous, alpha, delta)
	var leader := _figures.leader.position
	_camera.follow(leader, _world.floor_y(leader.x), delta)
	_hud.update_view(_sim, _figures, _camera, delta)
	var selected := _reader.held_height() if _reader != null else -1
	var guard_color := _colors(_setup.defender_owner)[0].lightened(0.25)
	_hud.markers.update_view(_sim, _figures, _camera, selected, guard_color)


func _show_events() -> void:
	_feedback.show(_sim.state, _world, _effects, _hud, _camera)
	for event: RaidEvent in _sim.state.events:
		if event.kind == RaidEvent.Kind.REINFORCEMENT:
			_dressing.open_far_door()
		elif event.kind == RaidEvent.Kind.DEED_DONE:
			_room.complete()


## Corridor positions (leader, guards) and last the sneak progress (-1 off a sneak path).
func _positions() -> PackedFloat64Array:
	var state := _sim.state
	var positions := PackedFloat64Array([state.leader.x])
	for guard: RaidFighter in state.guards:
		positions.append(guard.x)
	positions.append(state.sneak_progress if state.is_sneaking() else -1.0)
	return positions


func _colors(owner_id: String) -> PackedColorArray:
	var colors: PackedColorArray = _heraldry.get(owner_id, PackedColorArray())
	if colors.size() >= 2:
		return colors
	return PackedColorArray([Color(0.55, 0.5, 0.4), Color(0.8, 0.75, 0.6)])


func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = RaidArt.light_color("background", Color.BLACK)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = RaidArt.light_color("ambient", Color(0.15, 0.17, 0.27))
	environment.ambient_light_energy = RaidArt.number("light", "ambient_energy", 1.0)
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = RaidArt.number("light", "glow_intensity", 0.7)
	environment.glow_bloom = 0.05
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.light_color = RaidArt.light_color("moon")
	moon.light_energy = RaidArt.number("light", "moon_energy", 0.3)
	moon.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	add_child(moon)


func _on_start_requested(setup: RaidSetup, device: int) -> void:
	_seed += 1
	_start(setup, device)


func _on_flee_requested() -> void:
	_pause.visible = false
	_flee = true


## Leaving the practice: back to whoever opened it, or out of the game when it runs alone.
func _quit_practice() -> void:
	if not finished.get_connections().is_empty():
		finished.emit(_last_result)
	else:
		get_tree().quit()
