class_name JoustLists
extends Node3D
## The tournament ground: daylight, meadow with a sand band, the tilt barrier draped in both
## riders' colours, fences, a roofed stand and standing crowd that cheer, pavilions at the ends
## and trees around (crowd in JoustCrowd). Built from primitives and the combat assets.

const HALF_LENGTH := 36.0
const HALF_WIDTH := 7.0
const BARRIER_HALF := 30.0
const POST_STEP := 3.0
const STAND_FRONT := -10.5
const STAND_HALF := 15.0
const TIER_DEPTH := 1.2
const TIERS := 3
const WOOD := Color(0.47, 0.32, 0.19)
const WOOD_LIGHT := Color(0.66, 0.5, 0.32)
const TREES: Array[String] = ["tree_oak", "tree_pine", "tree_birch", "tree_oak", "tree_pine"]

var crowd := JoustCrowd.new()

var _placements: Dictionary[String, Array] = {}


## colors[r] holds the field and charge colour of rider r's owner.
func build(colors: Array[PackedColorArray]) -> void:
	var art := BattleModels.settings()
	var styles: Dictionary = art.get("landscapes", {})
	var style: Dictionary = styles.get(str(art.get("default_landscape", "")), {})
	_add_environment(style)
	_add_ground(style)
	_add_barrier(colors)
	_add_fences()
	_add_stand(colors)
	add_child(crowd)
	crowd.build(colors)
	_add_pavilions(colors)
	_add_surroundings()
	for filename: String in _placements:
		_add_batch(filename, _placements[filename])


func _add_environment(style: Dictionary) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.35, 0.55, 0.85)
	sky_material.sky_horizon_color = Color(0.75, 0.82, 0.9)
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
	environment.glow_enabled = true
	environment.glow_intensity = 0.25
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var light: Dictionary = BattleModels.settings().get("sun", {})
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(
		deg_to_rad(-float(light.get("elevation_deg", 30.0))),
		deg_to_rad(float(light.get("azimuth_deg", -28.0))),
		0.0
	)
	sun.light_color = Color.from_string(str(light.get("color", "#ffe2b0")), Color.WHITE)
	sun.light_energy = float(style.get("sun_energy", 1.0))
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	sun.shadow_bias = 0.03
	add_child(sun)


func _add_ground(style: Dictionary) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(320, 320)
	plane.subdivide_width = 4
	plane.subdivide_depth = 4
	var material := ShaderMaterial.new()
	material.shader = preload("res://src/render/joust/joust_ground.gdshader")
	var meadow := Color.from_string(str(style.get("meadow_color", "")), Color(0.33, 0.42, 0.16))
	var sand := Color.from_string(str(style.get("sand_color", "")), Color(0.69, 0.54, 0.3))
	material.set_shader_parameter("meadow", meadow)
	material.set_shader_parameter("sand", sand)
	material.set_shader_parameter("lists_half_width", HALF_WIDTH)
	material.set_shader_parameter("lists_half_length", HALF_LENGTH)
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


## The tilt: posts, a top rail and cloth panels alternating the two riders' colours.
func _add_barrier(colors: Array[PackedColorArray]) -> void:
	var posts: Array[Transform3D] = []
	var panels: Array[Transform3D] = []
	var panel_colors := PackedColorArray()
	var x := -BARRIER_HALF
	var index := 0
	while x <= BARRIER_HALF + 0.01:
		posts.append(Transform3D(Basis(), Vector3(x, 0.75, 0)))
		if x + POST_STEP <= BARRIER_HALF + 0.01:
			var center := Vector3(x + POST_STEP * 0.5, 0.0, 0.0)
			var owner := colors[index % 2]
			panels.append(Transform3D(Basis.from_scale(Vector3(1, 1, 1)), center + Vector3(0, 0.82, 0)))
			panel_colors.append(owner[0])
			panels.append(Transform3D(Basis.from_scale(Vector3(1, 0.22, 1.2)), center + Vector3(0, 0.36, 0)))
			panel_colors.append(owner[1])
			index += 1
		x += POST_STEP
	_add_boxes(Vector3(0.16, 1.5, 0.16), posts, PackedColorArray(), WOOD)
	_add_boxes(Vector3(POST_STEP - 0.18, 1.0, 0.06), panels, panel_colors, Color.WHITE)
	var rail: Array[Transform3D] = [Transform3D(Basis(), Vector3(0, 1.48, 0))]
	_add_boxes(Vector3(BARRIER_HALF * 2.0 + 0.2, 0.1, 0.14), rail, PackedColorArray(), WOOD_LIGHT)


func _add_fences() -> void:
	var x := -HALF_LENGTH + 1.3
	while x < HALF_LENGTH:
		for z: float in [HALF_WIDTH + 0.6, -HALF_WIDTH - 0.6]:
			_place("prop_fence_wood", Vector3(x, 0, z), 1.0)
		x += 2.6
	for z: float in [-5.2, -2.6, 2.6, 5.2]:
		for end: float in [-HALF_LENGTH - 1.5, HALF_LENGTH + 1.5]:
			_place("prop_fence_wood", Vector3(end, 0, z), 1.0, PI / 2)


## A roofed wooden stand on the far side with a striped canopy in the riders' colours.
func _add_stand(colors: Array[PackedColorArray]) -> void:
	var wood: Array[Transform3D] = []
	for tier: int in TIERS:
		var height := 0.55 * (tier + 1)
		var z := STAND_FRONT - TIER_DEPTH * (tier + 0.5)
		wood.append(Transform3D(Basis.from_scale(Vector3(1, height, 1)), Vector3(0, height * 0.5, z)))
	_add_boxes(Vector3(STAND_HALF * 2.0, 1.0, TIER_DEPTH), wood, PackedColorArray(), WOOD_LIGHT)
	var posts: Array[Transform3D] = []
	var x := -STAND_HALF
	while x <= STAND_HALF + 0.01:
		for z: float in [STAND_FRONT + 0.2, STAND_FRONT - TIER_DEPTH * TIERS - 0.2]:
			posts.append(Transform3D(Basis(), Vector3(x, 2.6, z)))
		x += 5.0
	_add_boxes(Vector3(0.22, 5.2, 0.22), posts, PackedColorArray(), WOOD)
	var depth := TIER_DEPTH * TIERS + 0.8
	var roof: Array[Transform3D] = [
		Transform3D(Basis(), Vector3(0, 5.25, STAND_FRONT - depth * 0.5 + 0.2))
	]
	_add_boxes(Vector3(STAND_HALF * 2.0 + 1.0, 0.12, depth), roof, PackedColorArray(), colors[1][0])
	var valance: Array[Transform3D] = []
	var stripes := PackedColorArray()
	var count := 16
	for i: int in count:
		var stripe_x := -STAND_HALF - 0.5 + (i + 0.5) * (STAND_HALF * 2.0 + 1.0) / count
		var at := Vector3(stripe_x, 4.85, STAND_FRONT + 0.6)
		valance.append(Transform3D(Basis(), at))
		stripes.append(colors[i % 2][0] if i % 4 < 2 else colors[i % 2][1])
	_add_boxes(Vector3((STAND_HALF * 2.0 + 1.0) / count, 0.75, 0.06), valance, stripes, Color.WHITE)


## Pavilions and banners at both ends; banner poles in the riders' colours along the stand.
func _add_pavilions(colors: Array[PackedColorArray]) -> void:
	var teams: Array = BattleModels.settings().get("teams", ["blue", "red"])
	for r: int in JoustState.RIDERS:
		var side := -1.0 if r == 0 else 1.0
		var team := str(teams[r % teams.size()])
		var lane := JoustTrack.LANE * (1.0 if r == 0 else -1.0)
		var facing := -side * PI / 2
		_place("prop_tent_" + team, Vector3(side * (HALF_LENGTH + 6.0), 0, lane * 4.0), 1.6, facing)
		_place("prop_banner_" + team, Vector3(side * (HALF_LENGTH + 2.5), 0, lane * 6.5), 1.2, facing)
		_place("prop_barrel_wood", Vector3(side * (HALF_LENGTH + 3.5), 0, lane * 7.5), 1.0)
	var poles: Array[Transform3D] = []
	var cloths: Array[Transform3D] = []
	var cloth_colors := PackedColorArray()
	for i: int in 6:
		var x := -STAND_HALF + 3.0 + i * (STAND_HALF * 2.0 - 6.0) / 5.0
		var at := Vector3(x, 0, STAND_FRONT + 1.2)
		poles.append(Transform3D(Basis(), at + Vector3(0, 3.3, 0)))
		var owner := colors[i % 2]
		cloths.append(Transform3D(Basis(), at + Vector3(0.45, 5.6, 0)))
		cloth_colors.append(owner[0])
		cloths.append(Transform3D(Basis.from_scale(Vector3(1, 0.25, 1.1)), at + Vector3(0.45, 4.85, 0)))
		cloth_colors.append(owner[1])
	_add_boxes(Vector3(0.1, 6.6, 0.1), poles, PackedColorArray(), WOOD)
	_add_boxes(Vector3(0.85, 1.3, 0.04), cloths, cloth_colors, Color.WHITE)


func _add_surroundings() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1198
	for i: int in 70:
		var angle := rng.randf() * TAU
		var radius := rng.randf_range(48.0, 85.0)
		var at := Vector3(cos(angle) * radius * 1.2, 0, sin(angle) * radius)
		_place(TREES[i % TREES.size()], at, rng.randf_range(0.9, 1.5), rng.randf() * TAU)
	for i: int in 900:
		var at := Vector3(rng.randf_range(-70, 70), 0, rng.randf_range(-45, 45))
		if absf(at.z) < HALF_WIDTH + 0.5 and absf(at.x) < HALF_LENGTH + 2.0:
			continue
		if at.z < STAND_FRONT + 0.5 and at.z > STAND_FRONT - 5.5 and absf(at.x) < STAND_HALF + 1.0:
			continue
		var kind := "foliage_grass" if i % 4 != 0 else "foliage_flowers"
		if i % 23 == 0:
			kind = "foliage_bush"
		_place(kind, at, rng.randf_range(0.75, 1.2), rng.randf() * TAU)


func _place(filename: String, at: Vector3, scale_factor: float, angle: float = 0.0) -> void:
	if not _placements.has(filename):
		_placements[filename] = []
	_placements[filename].append(
		Transform3D(Basis(Vector3.UP, angle).scaled(Vector3.ONE * scale_factor), at)
	)


func _add_batch(filename: String, placements: Array) -> void:
	var mesh := BattleModels.mesh(filename)
	if mesh == null:
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = placements.size()
	for i: int in placements.size():
		multimesh.set_instance_transform(i, placements[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = filename
	instance.multimesh = multimesh
	add_child(instance)


func _add_boxes(
	size: Vector3, placements: Array[Transform3D], tint: PackedColorArray, color: Color
) -> void:
	var box := BoxMesh.new()
	box.size = size
	box.material = material(color, not tint.is_empty())
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = not tint.is_empty()
	multimesh.mesh = box
	multimesh.instance_count = placements.size()
	for i: int in placements.size():
		multimesh.set_instance_transform(i, placements[i])
		if not tint.is_empty():
			multimesh.set_instance_color(i, tint[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	add_child(instance)


static func material(color: Color, tinted: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.vertex_color_use_as_albedo = tinted
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material
