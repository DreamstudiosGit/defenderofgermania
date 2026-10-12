class_name MerchantStage
extends Node3D
## The river road of the raid in the battle's toon style: meadow with a worn track along x,
## the river and its banks behind, groves beyond, a strip of grass and flowers in front, bushes
## where the companies lie in ambush and the town gate with the town behind its wall. The
## seed of the scenery comes from the province, so a place always looks the same.

## Road strip, river and grove depths (z, towards the camera is +).
const RIVER_Z := -10.0
const RIVER_WIDTH := 7.0
const GROVE_NEAR := -17.0
const GROVE_FAR := -34.0
const FOREGROUND_NEAR := 4.5
const FOREGROUND_FAR := 9.0
## The gate turns its arch towards the camera by this much; the road bends in with it.
const GATE_TURN_DEG := 30.0
## The kit gate is built for the castle scale; the side view wants it smaller.
const GATE_SCALE := 0.7
const TOWN_HOUSES: Array[String] = [
	"settlement_townhouse", "settlement_house", "settlement_townhouse", "settlement_longhouse",
]
const TOWN_DIRECTORY := "res://assets/economy/"

var _placements: Dictionary[String, Array] = {}
var _rng := RandomNumberGenerator.new()


func build(cfg: MerchantConfig, setup: MerchantSetup, map: MapData) -> void:
	var art := BattleModels.settings()
	var landscapes: Dictionary = art.get("landscapes", {})
	var seasons: Array = art.get("season_landscapes", [])
	var key := str(seasons[setup.season]) if setup.season in range(seasons.size()) else ""
	var style: Dictionary = landscapes.get(key, landscapes.get("river_valley", {}))
	_rng.seed = hash(setup.province)
	var start := cfg.leader_start() - 40.0
	var end := cfg.gate_x() + 40.0
	_add_environment(style)
	_add_ground(style, start, end)
	var river := BattleRiver.new()
	add_child(river)
	river.build(
		Vector2(end - start, 0.0), {"river_offset": RIVER_Z, "river_width": RIVER_WIDTH}
	)
	river.position.x = start
	var forest := 1.6 if _terrain(setup, map) == "forest" else 1.0
	_add_banks(start, end)
	_add_groves(style, start, end, forest * float(style.get("tree_density", 1.0)))
	_add_foreground(start, end)
	for share: float in cfg.ambush_at:
		var ambush := cfg.leader_start() + (cfg.gate_x() - cfg.leader_start()) * share
		for i: int in 3:
			_place("foliage_bush", Vector3(ambush - 1.2 + i * 1.2, 0, 5.0 + i % 2 * 0.5), 1.1)
	_add_gate(cfg.gate_x())
	for filename: String in _placements:
		_add_batch(filename, _placements[filename])


## z of the road at x: straight along the river, bending into the turned gate at the end.
static func road_z(x: float, gate_x: float) -> float:
	var into_gate := x - (gate_x - 6.0)
	return -into_gate * tan(deg_to_rad(GATE_TURN_DEG)) if into_gate > 0.0 else 0.0


func _terrain(setup: MerchantSetup, map: MapData) -> String:
	if map == null or not map.provinces.has(setup.province):
		return ""
	return map.provinces[setup.province].terrain


func _add_environment(style: Dictionary) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.35, 0.55, 0.85)
	sky_material.sky_horizon_color = Color(0.78, 0.84, 0.9)
	sky_material.ground_horizon_color = Color(0.6, 0.62, 0.5)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.79, 0.84, 0.75)
	environment.ambient_light_energy = float(style.get("ambient_energy", 0.75))
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.ssao_enabled = true
	environment.ssao_radius = 0.6
	environment.ssao_intensity = 1.4
	environment.glow_enabled = true
	environment.glow_intensity = 0.25
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var light: Dictionary = BattleModels.settings().get("sun", {})
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(
		deg_to_rad(-float(style.get("sun_elevation_deg", light.get("elevation_deg", 34.0)))),
		deg_to_rad(float(light.get("azimuth_deg", -28.0))),
		0.0
	)
	var sun_color := str(style.get("sun_color", light.get("color", "#ffe2b0")))
	sun.light_color = Color.from_string(sun_color, Color.WHITE)
	sun.light_energy = float(style.get("sun_energy", 1.0))
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	sun.shadow_bias = 0.03
	add_child(sun)


## The battle's meadow shader draws its worn lane at z = 0 when the field has no depth.
func _add_ground(style: Dictionary, start: float, end: float) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(end - start, 140.0)
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.position = Vector3((start + end) * 0.5, 0.0, -40.0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var surface := ShaderMaterial.new()
	surface.shader = preload("res://src/render/battle/meadow_surface.gdshader")
	surface.set_shader_parameter("field_size", Vector2(1000000.0, 0.0))
	var meadow := Color(0.36, 0.45, 0.2)
	var grass := Color.from_string(str(style.get("meadow_color", "")), meadow)
	surface.set_shader_parameter("meadow", grass)
	surface.set_shader_parameter("sand", Color.from_string(str(style.get("sand_color", "")), grass))
	ground.material_override = surface
	add_child(ground)


func _add_banks(start: float, end: float) -> void:
	var x := start
	while x < end:
		for side: float in [-1.0, 1.0]:
			var shore := RIVER_WIDTH * 0.5 + _rng.randf_range(0.1, 0.6)
			var bank := Vector3(x, 0, RIVER_Z + side * shore)
			_place("rock_small", bank, _rng.randf_range(0.35, 0.8), _rng.randf() * TAU)
			if _rng.randf() < 0.45:
				_place("foliage_reeds", bank + Vector3(0, 0, side * 0.5), 0.9)
		if _rng.randf() < 0.18:
			_place("foliage_water_lilies", Vector3(x, 0.04, RIVER_Z + 1.2), 0.8)
		if _rng.randf() < 0.3:
			_place("foliage_flowers", Vector3(x, 0, RIVER_Z + RIVER_WIDTH * 0.5 + 1.6), 1.1)
		x += 2.2


func _add_groves(style: Dictionary, start: float, end: float, density: float) -> void:
	var palettes: Dictionary = BattleModels.settings().get("tree_palettes", {})
	var trees: Array = palettes.get(str(style.get("tree_palette", "summer")), ["tree_oak"])
	var x := start
	while x < end:
		var z := _rng.randf_range(GROVE_FAR, GROVE_NEAR)
		var kind := str(trees[_rng.randi_range(0, trees.size() - 1)])
		_place(kind, Vector3(x, 0, z), _rng.randf_range(0.9, 1.5), _rng.randf() * TAU)
		if _rng.randf() < 0.5:
			_place("foliage_bush", Vector3(x + 1.0, 0, z + 2.0), _rng.randf_range(0.8, 1.3))
		x += _rng.randf_range(2.0, 4.5) / density
	x = start
	while x < end:
		var verge := Vector3(x, 0, _rng.randf_range(-6.5, -3.0))
		_place("foliage_grass", verge, _rng.randf_range(0.8, 1.2))
		x += _rng.randf_range(1.5, 3.5)


func _add_foreground(start: float, end: float) -> void:
	var x := start
	while x < end:
		var z := _rng.randf_range(FOREGROUND_NEAR, FOREGROUND_FAR)
		var kind := "foliage_flowers" if _rng.randf() < 0.3 else "foliage_grass"
		_place(kind, Vector3(x, 0, z), _rng.randf_range(0.8, 1.3), _rng.randf() * TAU)
		if _rng.randf() < 0.06:
			_place("rock_small", Vector3(x, 0, z + 1.0), _rng.randf_range(0.5, 0.9))
		x += _rng.randf_range(0.8, 2.0)
	x = start + 6.0
	while x < end - 50.0:
		_place("prop_fence_wood", Vector3(x, 0, FOREGROUND_FAR - 1.0), 1.0)
		x += 2.6 if _rng.randf() < 0.7 else 14.0


func _add_gate(gate_x: float) -> void:
	var turn := Basis(Vector3.UP, deg_to_rad(90.0 + GATE_TURN_DEG)).scaled(Vector3.ONE * GATE_SCALE)
	var gate := Vector3(gate_x + 1.0, 0, road_z(gate_x + 1.0, gate_x))
	var gates: Array = _placements.get_or_add("prop_town_gate", [])
	gates.append(Transform3D(turn, gate))
	_place("prop_barrel_wood", gate + Vector3(-5.0, 0, 3.2), 1.0)
	_place("prop_barrel_wood", gate + Vector3(-4.3, 0, 3.6), 0.9)
	for i: int in TOWN_HOUSES.size():
		var at := gate + Vector3(4.0 + i * 6.5, 0, -10.0 - (i % 2) * 5.0)
		_add_town_house(TOWN_HOUSES[i], Transform3D(Basis(Vector3.UP, i * 0.6), at))


func _add_town_house(filename: String, where: Transform3D) -> void:
	var scene := load(TOWN_DIRECTORY + filename + ".glb") as PackedScene
	if scene == null:
		push_error("merchant stage: cannot load %s" % filename)
		return
	var house := scene.instantiate() as Node3D
	house.transform = where
	add_child(house)


func _place(filename: String, at: Vector3, scale_factor: float, angle: float = 0.0) -> void:
	var placements: Array = _placements.get_or_add(filename, [])
	placements.append(Transform3D(Basis(Vector3.UP, angle).scaled(Vector3.ONE * scale_factor), at))


func _add_batch(filename: String, placements: Array) -> void:
	var model := BattleModels.mesh(filename)
	if model == null:
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = model
	multimesh.instance_count = placements.size()
	for i: int in placements.size():
		multimesh.set_instance_transform(i, placements[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = filename
	instance.multimesh = multimesh
	add_child(instance)
