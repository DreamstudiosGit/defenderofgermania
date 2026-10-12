class_name BattleField
extends Node3D
## Daylight battlefield with Blender scenery and the simulation's deployment zones.

const MEADOW := Color(0.56, 0.62, 0.30)
const SURROUNDINGS := Color(0.38, 0.47, 0.22)
const ZONE_ALPHA := 0.055

var _zones: Array[MeshInstance3D] = []


func build(
	rules: BattleRules, armies: Array[BattleRules.ArmyPreset], landscape: String = ""
) -> void:
	var art := BattleModels.settings()
	var variants: Dictionary = art.get("landscapes", {})
	var selected := landscape if not landscape.is_empty() else str(art.get("default_landscape", ""))
	var style: Dictionary = variants.get(selected, {})
	if style.is_empty():
		push_error("combat art: unknown landscape %s" % selected)
		return
	_add_environment(style)
	var size := rules.field_size
	var outside := _add_plane(
		size * 3.0, Vector3(size.x / 2, -0.05, size.y / 2), _material(SURROUNDINGS)
	)
	var ground := _add_plane(size, Vector3(size.x / 2, 0.0, size.y / 2), _material(MEADOW))
	var surface := ShaderMaterial.new()
	surface.shader = preload("res://src/render/battle/meadow_surface.gdshader")
	surface.set_shader_parameter("field_size", size)
	surface.set_shader_parameter("meadow", Color.from_string(str(style["meadow_color"]), MEADOW))
	surface.set_shader_parameter("sand", Color.from_string(str(style["sand_color"]), MEADOW))
	ground.material_override = surface
	outside.material_override = surface
	for s: int in BattleState.SIDES:
		var color := armies[s].color if s < armies.size() else Color.WHITE
		color.a = ZONE_ALPHA
		var zone_x := rules.deploy_depth / 2 if s == 0 else size.x - rules.deploy_depth / 2
		var zone := _add_plane(
			Vector2(rules.deploy_depth, size.y), Vector3(zone_x, 0.03, size.y / 2), _material(color)
		)
		_zones.append(zone)
	var scenery := BattleScenery.new()
	add_child(scenery)
	scenery.build(rules, style)


func show_zones(visible_now: bool) -> void:
	for zone: MeshInstance3D in _zones:
		zone.visible = visible_now


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
	environment.ambient_light_energy = float(style.get("ambient_energy", 0.35))
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.ssao_enabled = true
	environment.ssao_radius = 0.75
	environment.ssao_intensity = 1.8
	environment.ssil_enabled = true
	environment.ssil_intensity = 0.4
	environment.glow_enabled = true
	environment.glow_intensity = 0.25
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	# A low, warm sun for long shadows; the camera stands far back, so shadows reach far.
	var light: Dictionary = BattleModels.settings().get("sun", {})
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(
		deg_to_rad(-float(style.get("sun_elevation_deg", light.get("elevation_deg", 30.0)))),
		deg_to_rad(float(light.get("azimuth_deg", -28.0))),
		0.0
	)
	var sun_color := str(style.get("sun_color", light.get("color", "#ffe2b0")))
	sun.light_color = Color.from_string(sun_color, Color.WHITE)
	sun.light_energy = float(style.get("sun_energy", 1.0))
	sun.shadow_enabled = true
	sun.light_angular_distance = 0.9
	sun.directional_shadow_max_distance = float(light.get("shadow_distance", 600.0))
	sun.shadow_bias = 0.03
	add_child(sun)


func _add_plane(size: Vector2, at: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
