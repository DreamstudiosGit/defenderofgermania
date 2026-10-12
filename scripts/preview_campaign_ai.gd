extends SceneTree
## Screenshots of the computer opponents in the campaign scene: the setup with a personality's
## tooltip, or the AI debug overlay once the computers played (one human, three computers)
## showing the house that weighed the most options, or --house.
## Usage: godot --resolution 1280x800 --script res://scripts/preview_campaign_ai.gd --
## --view=setup|overlay --shot=<png path> [--locale=de|en] [--house=<computer house>]

const SHOT_FRAMES := 30
const COMPUTERS := 3


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var args := _arguments()
	if args.has("locale"):
		TranslationServer.set_locale(args["locale"])
	var scene := (load("res://src/render/campaign/campaign_main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var setup: SetupScreen = scene.get("_setup")
	if args.get("view", "setup") == "overlay":
		(setup.find_child("start", true, false) as Button).pressed.emit()
		_play_until_computers_moved(scene)
		var overlay: AiDebugOverlay = scene.get("_ai_overlay")
		overlay.toggle()
		var wanted: String = args.get("house", _busiest(scene.get("ai")))
		if wanted in overlay.computer_houses():
			while overlay.house != wanted:
				overlay.cycle(1)
	else:
		(setup.find_child("personality_staufer", true, false) as Control).grab_focus()
	var tooltip: FocusTooltip = scene.get("_tooltip")
	for frame: int in SHOT_FRAMES:
		# The window's first mouse event would switch FocusTooltip off before the screenshot.
		tooltip.steer_by_focus()
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(args.get("shot", "user://campaign_ai.png"))
	print("campaign ai preview: %s (%s)" % [args.get("shot", ""), error_string(error)])
	quit(0 if error == OK else 1)


## Ends the human's phases (default event choices) until every computer house has played.
func _play_until_computers_moved(scene: Node) -> void:
	var session: CampaignSession = scene.get("session")
	var ai: AiPlayer = scene.get("ai")
	var guard := 0
	while ai.logs.size() < COMPUTERS and guard < 20:
		guard += 1
		_close_screens(scene)
		scene.call("execute", EndPhaseCommand.new(session.rules, session.active_house()))
	_close_screens(scene)


func _busiest(ai: AiPlayer) -> String:
	var best := ""
	for house: String in ai.logs:
		if best.is_empty() or ai.logs[house].entries.size() > ai.logs[best].entries.size():
			best = house
	return best


func _close_screens(scene: Node) -> void:
	for screen_name: String in ["_report", "_handover", "_events"]:
		var screen: Control = scene.get(screen_name)
		while screen.visible:
			screen.visible = false
			if screen is SettlementReport:
				(screen as SettlementReport).closed.emit()
			elif screen is HandoverScreen:
				(screen as HandoverScreen).confirmed.emit()


func _arguments() -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	for argument: String in OS.get_cmdline_user_args():
		var parts := argument.trim_prefix("--").split("=", true, 1)
		result[parts[0]] = parts[1] if parts.size() > 1 else ""
	return result
