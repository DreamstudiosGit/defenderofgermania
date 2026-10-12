extends Node3D
## Trebuchet minigame scene. Opened directly it is the practice mode (default setup from
## data/combat_siege.json, a how-to, again and quit); configure_campaign plays the campaign's
## siege and reports `finished`. The rules (TrebuchetSim) decide every shot; this scene only
## shows them: aim, throw, flight, impact, settle, and the counterfire in between.

signal finished(result: TrebuchetResult)

enum Phase { AIM, THROW, FLIGHT, SETTLE, COUNTERFIRE, DONE }

const FIRST_SEED := 1198
## Longest frame the clock takes in one go (shader compiles must not eat the aiming time).
const MAX_FRAME_SECONDS := 0.1

var _cfg: SiegeConfig
var _map: MapData
var _setup: TrebuchetSetup
var _sim: TrebuchetSim
var _aimer: TrebuchetAimer
var _control: SiegeAimControl
var _devices := PackedInt32Array([BattleInputMap.Device.KEYBOARD, BattleInputMap.Device.PAD_1])
var _seed: int = FIRST_SEED
var _campaign: bool = false
var _headless: bool = false
var _phase: Phase = Phase.DONE
var _clock: float = 0.0
var _path: SiegeBallistics.Launch
var _impact: SiegeBallistics.Impact
var _reported: bool = false
var _looking: bool = false
## Frame in which a menu button was pressed; its key must not also throw.
var _menu_frame: int = -10

var _world := SiegeWorld.new()
var _castle_view := SiegeCastleView.new()
var _effects := SiegeEffects.new()
var _trebuchet := SiegeTrebuchetView.new()
var _shots := SiegeShotView.new()
var _camera := SiegeCamera.new()
var _hud := SiegeHud.new()
var _help := SiegeHelp.new()
var _result_panel := SiegeResultPanel.new()


## Plays a campaign siege instead of the practice; call before adding the scene to the tree.
## devices[0] is the attacker's BattleInputMap.Device, or -1 for the computer's crew.
func configure_campaign(setup: TrebuchetSetup, devices: PackedInt32Array, seed_value: int) -> void:
	_setup = setup.duplicate_setup()
	_devices = PackedInt32Array([devices[0] if devices.size() > 0 else -1])
	_seed = seed_value
	_campaign = true


func _ready() -> void:
	_cfg = SiegeConfig.load_file()
	_map = MapData.load_file()
	if _cfg == null or _map == null:
		push_error("siege: data/combat_siege.json or data/map.json could not be loaded")
		return
	SiegeInputMap.register()
	_headless = DisplayServer.get_name() == "headless"
	if _setup == null:
		_setup = _cfg.practice.duplicate_setup()
		if _headless:
			_devices = PackedInt32Array([-1])
	if not _headless:
		get_viewport().msaa_3d = Viewport.MSAA_4X
	for node: Node in [_world, _castle_view, _effects, _trebuchet, _shots, _camera]:
		add_child(node)
	_camera.current = true
	_camera.setup()
	_world.build(_camera, _headless)
	_trebuchet.build(_colors(_setup.attacker_house)[0])
	add_child(_hud)
	var overlay := CanvasLayer.new()
	overlay.layer = 2
	add_child(overlay)
	overlay.add_child(_help)
	overlay.add_child(_result_panel)
	_help.visible = false
	_connect_signals()
	_start()
	if not _campaign and not _headless:
		_help.open(true)


func _process(delta: float) -> void:
	var speed := SiegeArt.number("pacing", "headless_speed", 8.0) if _headless else 1.0
	advance(minf(delta, MAX_FRAME_SECONDS) * speed)


## One step of the minigame's clock (seconds of play); the whole presentation follows it.
func advance(delta: float) -> void:
	if _sim == null:
		return
	if _control.menu_pressed() and _phase != Phase.DONE:
		if _help.visible:
			_help.visible = false
		else:
			_help.open(not _campaign)
	if not _help.visible:
		_step(delta)
	_camera.update(delta)
	_trebuchet.update(delta)
	_castle_view.update(delta)
	_effects.update(delta)
	var human_aims := _phase == Phase.AIM and _control.is_human()
	_hud.update_status(_sim, _cfg.aim_limit_seconds - _clock if human_aims else -1.0)
	_hud.bars.update_view(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _control != null:
		_control.handle_event(event)


func _start() -> void:
	_sim = TrebuchetSim.new(_cfg, _setup, _seed)
	_control = SiegeAimControl.new(_cfg, _devices)
	_aimer = null if _control.is_human() else TrebuchetAimer.new(_cfg, _cfg.campaign_skill)
	_reported = false
	_effects.clear()
	_shots.clear()
	_result_panel.visible = false
	if _sim.castle == null:
		_finish()
		return
	_castle_view.build(_sim.castle, _setup.layout_key(), _colors(_setup.defender_owner), _effects)
	var tops := PackedVector3Array()
	for i: int in _sim.castle.part_count():
		tops.append(_castle_view.part_top(i))
	_hud.bars.setup(_sim.castle, _camera, tops)
	var owner := tr("BATTLE_HOUSE_" + _setup.defender_owner.to_upper())
	_hud.setup(_sim, tr("SIEGE_TITLE" if _campaign else "SIEGE_PRACTICE"),
		tr("SIEGE_CASTLE") % [owner, _setup.wall_level], _control.hints())
	_hud.show_aim(_control.aim)
	_camera.frame_aim()
	_enter(Phase.AIM)


func _step(delta: float) -> void:
	_clock += delta
	match _phase:
		Phase.AIM:
			_aim_step(delta)
		Phase.THROW:
			if _clock >= SiegeArt.number("trebuchet", "release_seconds", 0.75):
				var pot := _control.aim.projectile == TrebuchetShot.Projectile.FIRE_POT
				_shots.launch(_path, pot)
				_enter(Phase.FLIGHT)
		Phase.FLIGHT:
			_flight_step()
		Phase.SETTLE:
			if _clock >= _cfg.settle_seconds:
				_after_shot()
		Phase.COUNTERFIRE:
			if _clock >= _cfg.counterfire_seconds:
				_castle_view.apply(_sim.endure_counterfire(), Vector3.ZERO)
				_after_shot()
		Phase.DONE:
			var hold := SiegeArt.number("pacing", "ai_hold_seconds", 2.5)
			if _campaign and _aimer != null and not _reported and _clock >= hold:
				_report_result()


func _aim_step(delta: float) -> void:
	if _sim.is_over():
		_finish()
		return
	if _sim.is_counterfire_slot():
		_enter(Phase.COUNTERFIRE)
		_counterfire_show()
		return
	if _aimer != null:
		if _clock >= SiegeArt.number("pacing", "ai_aim_seconds", 2.0):
			_control.aim = _aimer.aim(_sim)
			_hud.show_aim(_control.aim)
			_throw()
		return
	var fire := _control.poll(delta) and Engine.get_process_frames() > _menu_frame + 1
	_look(_control.looking)
	_hud.show_aim(_control.aim)
	_shots.show_preview(_sim.preview(_control.aim))
	if fire or _clock >= _cfg.aim_limit_seconds:
		_throw()


func _throw() -> void:
	_control.aim.aim_seconds = _clock
	_look(false)
	_path = _sim.path_for(_control.aim)
	_impact = SiegeBallistics.trace(_cfg, _path, _sim.castle)
	_shots.show_preview(PackedVector2Array())
	_trebuchet.throw()
	_hud.message("")
	_enter(Phase.THROW)


func _flight_step() -> void:
	var t := _clock
	if t < _impact.time:
		_shots.fly(t)
		_camera.follow(t / maxf(_impact.time, 0.01), Vector3(_path.x_at(t), _path.y_at(t), 0.0))
		return
	var report := _sim.fire(_control.aim)
	var point := Vector3(report.impact.x, report.impact.y, 0.0)
	_shots.fly(report.impact.time)
	_shots.land(point, report.impact.part < 0)
	if report.impact.part < 0:
		_effects.burst(point, SiegeArt.color("dust", "wood", Color.TAN), 2.0, 0.6)
	_castle_view.apply(report.events, point)
	_camera.frame_castle()
	_camera.shake(1.0 if report.hit else 0.4)
	_hud.message(SiegeNews.shot_line(report, _sim.castle))
	_shout(report.events)
	_enter(Phase.SETTLE)


func _after_shot() -> void:
	if _sim.is_over():
		_finish()
		return
	_camera.frame_aim()
	_enter(Phase.AIM)


func _counterfire_show() -> void:
	var events: Array[SiegeEvent] = [SiegeEvent.make(SiegeEvent.Kind.COUNTERFIRE)]
	_shout(events)
	for i: int in 3:
		var at := Vector3(14.0 + 9.0 * i, 0.0, -6.0 + 7.0 * i)
		_effects.burst(at, SiegeArt.color("dust", "stone", Color.TAN), 2.0, 0.5)
	_camera.shake(0.6)


func _finish() -> void:
	_enter(Phase.DONE)
	_shots.show_preview(PackedVector2Array())
	var result := _sim.result()
	var name := ""
	if _sim.castle != null:
		name = SiegeNews.part_name(_sim.castle, _sim.castle.breach)
	_result_panel.show_result(result, name, not _campaign)
	if _headless:
		print("siege over: breach %s, wall %.2f, garrison %.2f, %d shots" % [
			result.breach, result.wall_damage, result.garrison_damage, result.shots_fired])


func _report_result() -> void:
	if _reported:
		return
	_reported = true
	finished.emit(_sim.result())


func _enter(phase: Phase) -> void:
	_phase = phase
	_clock = 0.0
	_hud.set_aiming(phase == Phase.AIM and _control.is_human())
	if phase == Phase.AIM and _aimer != null:
		_hud.message(tr("SIEGE_AI_AIMING"))


func _look(castle: bool) -> void:
	if castle == _looking:
		return
	_looking = castle
	if castle:
		_camera.frame_castle()
	else:
		_camera.frame_aim()


func _shout(events: Array[SiegeEvent]) -> void:
	var lines := SiegeNews.shout(events, _sim.castle)
	if lines.is_empty():
		return
	if _sim.castle.breach >= 0:
		_hud.shout.clear()
	_hud.shout.shout(lines[0], lines[1], _colors(_setup.attacker_house)[0])


func _colors(owner: String) -> PackedColorArray:
	return SiegeArt.house_colors(_map, owner)


func _connect_signals() -> void:
	_hud.aim_changed.connect(
		func(weight: int, angle: int) -> void: _control.set_aim(weight, angle)
	)
	_hud.projectile_changed.connect(
		func(kind: TrebuchetShot.Projectile) -> void: _control.set_projectile(kind)
	)
	_hud.fire_requested.connect(
		func() -> void:
			if _phase == Phase.AIM and _control.is_human() and not _help.visible:
				_throw()
	)
	_help.closed.connect(
		func() -> void:
			_help.visible = false
			_menu_frame = Engine.get_process_frames()
	)
	_help.retry_requested.connect(_retry)
	_help.quit_requested.connect(_quit)
	_result_panel.retry_requested.connect(_retry)
	_result_panel.quit_requested.connect(_quit)
	_result_panel.continue_requested.connect(_report_result)


func _retry() -> void:
	_help.visible = false
	_menu_frame = Engine.get_process_frames()
	_seed += 1
	_start()


## Practice opened directly closes the game; opened by a menu it hands the result back.
func _quit() -> void:
	if get_tree().current_scene == self:
		get_tree().quit()
	else:
		_report_result()
