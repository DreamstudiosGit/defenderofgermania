extends SceneTree
## Renders the joust screenshots in docs/screenshots: the run-up and the aim through the helmet
## slit, and a fall seen from the stand. Run windowed:
## godot --path . --resolution 1280x800 --script res://scripts/preview_joust.gd

const SHOTS := "res://docs/screenshots/"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var setup := JoustSetup.new()
	setup.house = "staufer"
	setup.opponent = "welfen"
	setup.lance = 3
	setup.opponent_skill = 0
	setup.practice = true
	var joust := (load("res://src/render/joust/joust_main.tscn") as PackedScene).instantiate()
	joust.call("configure_campaign", setup, PackedInt32Array([-1, -1]), 1198)
	root.add_child(joust)
	joust.set_process(false)
	var sim: JoustSim = joust.get("_sim")
	var hud: JoustHud = joust.get("_hud")
	var names: Array[String] = joust.get("_names")
	var colors: Array[PackedColorArray] = joust.get("_colors")
	hud.setup(names, colors, sim.cfg.zones, BattleInputMap.Device.KEYBOARD, true)
	var errors := 0
	errors += await _shot(joust, sim, 1, JoustState.Phase.RUNUP, 1.85, "m6_joust_runup.png")
	errors += await _shot(joust, sim, 1, JoustState.Phase.AIM, 1.2, "m6_joust_aim.png")
	errors += await _shot(joust, sim, 3, JoustState.Phase.CLASH, 1.0, "m6_joust_fall.png")
	quit(0 if errors == 0 else 1)


## Rides to `seconds` into the phase of pass `pass_number`, lets the view settle, saves.
func _shot(
	joust: Node, sim: JoustSim, pass_number: int, phase: JoustState.Phase, seconds: float,
	file: String
) -> int:
	var ticks := roundi(seconds * sim.cfg.tick_rate)
	while not (sim.state.pass_count == pass_number and sim.state.phase == phase):
		joust.call("_tick")
	while sim.state.phase_tick < ticks:
		joust.call("_tick")
		joust.call("_update_view", 1.0, sim.tick_seconds())
		await process_frame
	for i: int in 3:
		joust.call("_update_view", 1.0, 0.0)
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(SHOTS + file))
	print("joust preview: %s, error %d" % [file, error])
	return 0 if error == OK else 1
