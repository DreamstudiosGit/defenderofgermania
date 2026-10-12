extends Node
## Preview of the castle view on a fresh game. Run
## `godot res://src/render/castle/castle_preview.tscn -- [options]`:
## --level=<1..5> home castle level (default 1) or --province=<0..3> a province castle of the
## same house; --decorations=all; --buildings=all; --progress=<0..1> the next castle level under
## construction; --population=<n>; --house=<id> (default welfen); --camera=<yaw,pitch,distance>;
## --shot=<png> saves one frame after the time-lapse (or after --wait=<seconds>) and quits. The
## fake state is changed for the preview only.

const SEED := 1
const SETTLE_SECONDS := 1.0


func _ready() -> void:
	var rules := GameRules.load_files()
	if rules == null:
		push_error("castle preview: the game data could not be loaded")
		return
	var state := GameSetup.create(rules.map, rules.economy, SEED)
	var options := _options()
	var house_id: String = options.get("house", "welfen")
	if not state.houses.has(house_id):
		push_error("castle preview: unknown house %s" % house_id)
		return
	var province_id := _prepare(state, rules.economy, house_id, options)
	if DisplayServer.get_name() != "headless":
		get_viewport().msaa_3d = Viewport.MSAA_4X
	var view := CastleView.new()
	add_child(view)
	view.closed.connect(get_tree().quit)
	view.show_province(state, rules, province_id)
	if options.has("camera"):
		var parts := options["camera"].split(",")
		var camera := view.find_child("Camera", true, false) as CastleCamera
		if parts.size() == 3 and camera != null:
			camera.frame(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
	if options.has("shot"):
		var duration := CastleArt.number("timelapse", "duration", 3.0) + SETTLE_SECONDS
		_capture(options["shot"], float(options.get("wait", str(duration))))


static func _prepare(
	state: GameState, economy: EconomyConfig, house_id: String, options: Dictionary[String, String]
) -> String:
	var house := state.houses[house_id]
	var province_id := house.home_province
	var level := int(options.get("level", "1"))
	var table := economy.home_castle
	if options.has("province"):
		province_id = _province_castle(state, house_id)
		level = int(options["province"])
		table = economy.province_castle
	var province := state.provinces[province_id]
	province.castle_level = level
	if options.has("population"):
		province.population = float(options["population"])
	if options.get("decorations", "") == "all":
		house.decorations.assign(economy.decorations.keys())
	if options.get("buildings", "") == "all":
		province.buildings.clear()
		for id: String in economy.buildings:
			var def := economy.buildings[id]
			var upgraded := economy.buildings.values().any(
				func(other: BuildingDef) -> bool: return other.upgrade_of == id
			)
			if not upgraded and (province_id == house.home_province or not def.is_home_only):
				province.buildings.append(id)
	if options.has("progress") and table.has(level + 1):
		var rounds := table[level + 1].build_rounds
		var left := clampi(roundi((1.0 - float(options["progress"])) * rounds), 1, rounds)
		province.constructions.append(ConstructionState.create(ConstructionState.CASTLE, left))
	return province_id


## A province of the house other than its home; takes one over when it holds none.
static func _province_castle(state: GameState, house_id: String) -> String:
	var home := state.houses[house_id].home_province
	for province: ProvinceState in state.provinces_of(house_id):
		if province.id != home:
			return province.id
	for id: String in state.provinces:
		if id != home:
			state.provinces[id].owner = house_id
			return id
	return home


func _capture(path: String, seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(path))
	print("castle preview: saved %s (error %d)" % [path, error])
	get_tree().quit(0 if error == OK else 1)


static func _options() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for argument: String in OS.get_cmdline_user_args():
		var parts := argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else ""
	return options
