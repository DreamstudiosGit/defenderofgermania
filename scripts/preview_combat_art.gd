extends SceneTree

const OUTPUT := "res://art-src/combat/combat_battle_preview.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var packed := load("res://src/render/battle/battle_main.tscn") as PackedScene
	var battle := packed.instantiate()
	root.add_child(battle)
	battle.call("_on_start_requested", PackedInt32Array([-1, -1]))
	var sim: BattleSim = battle.get("_sim")
	for i: int in 480:
		battle.call("_tick")
	battle.set_process(false)
	var hud: BattleHud = battle.get("_hud")
	hud.update_view(sim, sim.state.pos, 0.0)
	var shout: BattleShout = hud.get("_shout")
	shout.clear()
	var volleys: BattleVolleys = battle.get("_volleys")
	volleys.clear()
	var figures: BattleFigures = battle.get("_figures")
	figures.update_view(sim.state, sim.state.fig_pos, 1.0)
	var camera: BattleCamera = battle.get("_camera")
	camera.setup(sim.rules.field_size, sim.rules.field_size * 0.5)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT))
	print("combat art preview: %s, error %d" % [OUTPUT, error])
	var before := sim.state.tick
	battle.set_process(true)
	await create_timer(1.0).timeout
	battle.set_process(false)
	print("rendered combat: %d simulation ticks in live Forward+ play" % (sim.state.tick - before))
	shout.clear()
	volleys.clear()
	var focus := Vector3(sim.state.pos[0].x, 0, sim.state.pos[0].y)
	camera.position = focus + Vector3(0, sin(camera.pitch), cos(camera.pitch)) * 32
	hud.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	image = root.get_texture().get_image()
	var detail := "res://art-src/combat/combat_unit_preview.png"
	var detail_error := image.save_png(ProjectSettings.globalize_path(detail))
	print("combat art detail: %s, error %d" % [detail, detail_error])
	error = error if error != OK else detail_error
	quit(0 if error == OK else 1)
