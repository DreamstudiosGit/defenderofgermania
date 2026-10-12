class_name CastleWorld
extends Node3D
## The land round the castle: warm daylight with toon light and the battle's ink and grain pass,
## a meadow with the road to the gate, a bare castle yard, fields and woods ("ground", "light"
## and "ink" in data/castle_art.json). The environment sits on the view's camera so it never
## competes with another scene's WorldEnvironment.

const INK := preload("res://src/render/battle/battle_ink.gdshader")

var _yard: MeshInstance3D


func build(camera: Camera3D) -> void:
	camera.environment = _environment()
	add_child(_sun())
	var ground := CastleArt.section("ground")
	var radius := float(ground.get("radius", 140.0))
	_add_disc("Meadow", radius, -0.5, 1.0, CastleArt.color("ground", "grass", Color.OLIVE_DRAB))
	_yard = _add_disc("Yard", 1.0, 0.0, 0.04, CastleArt.color("ground", "yard", Color.TAN))
	var length := float(ground.get("road_length", 120.0))
	_add_box(
		"Road", Vector3(float(ground.get("road_width", 5.0)), 0.04, length),
		Vector3(0.0, 0.01, length * 0.5), 0.0, CastleArt.color("ground", "road", Color.BURLYWOOD)
	)
	_add_fields(ground)
	_add_trees(ground)
	_add_ink()


## Bare earth inside the castle, sized for the castle type.
func show_yard(site_key: String) -> void:
	var radii: Dictionary = CastleArt.section("ground").get("yard_radius", {})
	var radius := float(radii.get(site_key, 0.0))
	_yard.visible = radius > 0.0
	_yard.scale = Vector3(maxf(radius, 0.01), 1.0, maxf(radius, 0.01))


func _add_fields(ground: Dictionary) -> void:
	var colors: Array = ground.get("field_colors", [])
	var fields: Array = ground.get("fields", [])
	for i: int in fields.size():
		var field: Array = fields[i]
		if field.size() != 5 or colors.is_empty():
			continue
		var color := Color.from_string(str(colors[i % colors.size()]), Color.KHAKI)
		var size := Vector3(float(field[2]), 0.08, float(field[3]))
		var at := Vector3(float(field[0]), 0.02, float(field[1]))
		var yaw := deg_to_rad(float(field[4]))
		_add_box("Field", size, at, yaw, color)
		var furrows := 5
		for furrow: int in furrows:
			var offset := (furrow - (furrows - 1) * 0.5) * size.z / furrows
			var line := Vector3(size.x * 0.94, 0.1, 0.35)
			var center := at + Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, offset)
			_add_box("Furrow", line, center, yaw, color.darkened(0.22))


func _add_trees(ground: Dictionary) -> void:
	var kinds: Array = ground.get("trees", [])
	if kinds.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(CastleArt.section("settlement").get("seed", 1198))
	var inner := float(ground.get("tree_inner_radius", 70.0))
	var outer := float(ground.get("tree_outer_radius", 110.0))
	var low := float(ground.get("tree_scale_min", 2.0))
	var high := float(ground.get("tree_scale_max", 3.0))
	var batches: Dictionary[String, Array] = {}
	for i: int in int(ground.get("tree_count", 60)):
		var angle := rng.randf() * TAU
		var at := Vector2(cos(angle), sin(angle)) * sqrt(lerpf(inner * inner, outer * outer, rng.randf()))
		var kind := str(kinds[rng.randi_range(0, kinds.size() - 1)])
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(low, high))
		if at.y > 0.0 and absf(at.x) < 8.0:
			continue
		if not batches.has(kind):
			batches[kind] = []
		batches[kind].append(Transform3D(basis, Vector3(at.x, 0.0, at.y)))
	for kind: String in batches:
		var mesh := BattleModels.mesh(kind)
		if mesh == null:
			continue
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = batches[kind].size()
		var transforms: Array = batches[kind]
		for i: int in transforms.size():
			multimesh.set_instance_transform(i, transforms[i] as Transform3D)
		var trees := MultiMeshInstance3D.new()
		trees.name = kind
		trees.multimesh = multimesh
		add_child(trees)


func _add_ink() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	var ink := MeshInstance3D.new()
	ink.name = "Ink"
	ink.mesh = quad
	# The vertex shader covers the screen wherever the node is, so it must never be culled.
	ink.extra_cull_margin = 16384.0
	ink.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = INK
	var settings := CastleArt.section("ink")
	for key: String in settings:
		if key == "color":
			material.set_shader_parameter("ink", CastleArt.color("ink", "color", Color.BLACK))
		else:
			material.set_shader_parameter(key, settings[key])
	ink.material_override = material
	add_child(ink)


func _add_disc(
	node_name: String, radius: float, y: float, height: float, color: Color
) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 64
	cylinder.rings = 1
	var disc := MeshInstance3D.new()
	disc.name = node_name
	disc.mesh = cylinder
	disc.position = Vector3(0.0, y, 0.0)
	disc.material_override = _toon(color)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	return disc


func _add_box(node_name: String, size: Vector3, at: Vector3, yaw: float, color: Color) -> void:
	var box := BoxMesh.new()
	box.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = box
	instance.transform = Transform3D(Basis(Vector3.UP, yaw), at)
	instance.material_override = _toon(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


static func _toon(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.roughness = 0.9
	return material


static func _sun() -> DirectionalLight3D:
	var light := CastleArt.section("light")
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation = Vector3(
		deg_to_rad(-float(light.get("sun_elevation_deg", 40.0))),
		deg_to_rad(float(light.get("sun_azimuth_deg", -38.0))), 0.0
	)
	sun.light_color = CastleArt.color("light", "sun_color", Color.WHITE)
	sun.light_energy = float(light.get("sun_energy", 1.2))
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.light_angular_distance = 0.6
	sun.directional_shadow_max_distance = float(light.get("shadow_distance", 320.0))
	return sun


static func _environment() -> Environment:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = CastleArt.color("light", "sky_top", Color.SKY_BLUE)
	sky_material.sky_horizon_color = CastleArt.color("light", "sky_horizon", Color.WHITE)
	sky_material.ground_horizon_color = CastleArt.color("light", "ground_horizon", Color.GRAY)
	sky_material.ground_bottom_color = CastleArt.color("ground", "grass", Color.OLIVE_DRAB)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = CastleArt.color("light", "ambient", Color.GRAY)
	environment.ambient_light_energy = CastleArt.number("light", "ambient_energy", 0.4)
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.ssao_enabled = true
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 1.6
	environment.fog_enabled = true
	environment.fog_light_color = CastleArt.color("light", "fog_color", Color.LIGHT_GRAY)
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_density = CastleArt.number("light", "fog_density", 0.7)
	environment.fog_depth_begin = CastleArt.number("light", "fog_begin", 200.0)
	environment.fog_depth_end = CastleArt.number("light", "fog_end", 500.0)
	environment.fog_sky_affect = 0.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.3
	return environment
