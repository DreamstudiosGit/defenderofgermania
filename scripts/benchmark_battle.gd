extends SceneTree
## Frame-rate benchmark of the real-time battle: two computer armies of about 200 figures each
## fight in the rendered scene; prints figure count, average fps and the slowest second.
## Run with a window: godot --resolution 1280x800 --script res://scripts/benchmark_battle.gd

const ARMY: Array[String] = [
	"spearmen", "spearmen", "spearmen", "spearmen", "spearmen", "spearmen",
	"brabanters", "brabanters", "levy", "levy", "levy",
	"crossbowmen", "crossbowmen", "crossbowmen", "crossbowmen",
	"knights", "knights", "knights", "knights", "trebuchet",
]
## Past the 20 s deployment, so the measurement sees the armies fighting.
const WARM_UP_SECONDS := 30.0
const MEASURE_SECONDS := 20.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var battle := (load("res://src/render/battle/battle_main.tscn") as PackedScene).instantiate()
	root.add_child(battle)
	var cfg: CombatConfig = battle.get("_cfg")
	for army: BattleRules.ArmyPreset in cfg.battle.armies:
		army.units.assign(ARMY)
	battle.call("_on_start_requested", PackedInt32Array([-1, -1]))
	var sim: BattleSim = battle.get("_sim")
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < WARM_UP_SECONDS * 1e6:
		await process_frame
	var frames := 0
	var second_frames := 0
	var slowest := INF
	var second_start := Time.get_ticks_usec()
	start = second_start
	while Time.get_ticks_usec() - start < MEASURE_SECONDS * 1e6:
		await process_frame
		frames += 1
		second_frames += 1
		var now := Time.get_ticks_usec()
		if now - second_start >= 1e6:
			slowest = minf(slowest, second_frames * 1e6 / (now - second_start))
			second_frames = 0
			second_start = now
	var elapsed := (Time.get_ticks_usec() - start) / 1e6
	var size := root.get_visible_rect().size
	var report := "battle benchmark: %d figures at %dx%d, %.1f fps average, %.1f fps slowest second"
	print(report % [sim.state.fig_pos.size(), size.x, size.y, frames / elapsed, slowest])
	quit()
