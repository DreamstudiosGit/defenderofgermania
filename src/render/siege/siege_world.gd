class_name SiegeWorld
extends Node3D
## The land of the siege: warm daylight with toon light and the battle's ink pass, a meadow
## with the road from the trebuchet to the gate (milestones every 25 m help to judge range),
## fields, a village behind the castle, woods and hills ("light" and "ground" in
## data/combat_siege_art.json). The environment sits on the camera like in the castle view.

var _ground_body := StaticBody3D.new()


func build(camera: Camera3D, headless: bool) -> void:
	camera.environment = _environment()
	add_child(_sun())
	var ground := SiegeArt.section("ground")
	var size := float(ground.get("size", 1200.0))
	_add_box("Meadow", Vector3(size, 1.0, size), Vector3(size * 0.15, -0.5, 0.0), 0.0,
		SiegeArt.color("ground", "grass", Color.OLIVE_DRAB))
	var road: Array = ground.get("road_span", [-30, 150])
	var width := float(ground.get("road_width", 5.0))
	var length := float(road[1]) - float(road[0])
	_add_box("Road", Vector3(length, 0.04, width), Vector3(float(road[0]) + length * 0.5, 0.01, 0.0),
		0.0, SiegeArt.color("ground", "road_color", Color.BURLYWOOD))
	_add_fields(ground)
	_add_markers(ground)
	_add_trees(ground)
	_add_props(ground)
	_add_collider(size)
	if not headless:
		add_child(BattleInk.new())


## Static ground the falling castle parts land on.
func _add_collider(size: float) -> void:
	_ground_body.name = "GroundBody"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, 2.0, size)
	shape.shape = box
	shape.position = Vector3(size * 0.15, -1.0, 0.0)
	_ground_body.add_child(shape)
	add_child(_ground_body)


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
		for furrow: int in 5:
			var offset := (furrow - 2) * size.z / 5.0
			var center := at + Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, offset)
			_add_box("Furrow", Vector3(size.x * 0.94, 0.1, 0.35), center, yaw, color.darkened(0.22))


func _add_markers(ground: Dictionary) -> void:
	var markers: Dictionary = ground.get("markers", {})
	var piece := str(markers.get("piece", ""))
	if piece.is_empty():
		return
	var every := float(markers.get("every", 25.0))
	var x := float(markers.get("from", 50.0))
	while x <= float(markers.get("to", 125.0)) + 0.01:
		var stone := SiegeArt.instance(piece, x * 7.0, SiegeArt.scale_of(markers.get("scale", 1.0)))
		stone.position = Vector3(x, 0.0, float(markers.get("side", -4.0)))
		add_child(stone)
		x += every


func _add_trees(ground: Dictionary) -> void:
	var kinds: Array = ground.get("tree_kinds", [])
	if kinds.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(ground.get("tree_seed", 1198))
	var scales: Array = ground.get("tree_scale", [2.0, 3.0])
	var batches: Dictionary[String, Array] = {}
	for zone: Variant in ground.get("tree_zones", []):
		var area: Array = zone
		for i: int in int(area[4]):
			var kind := str(kinds[rng.randi_range(0, kinds.size() - 1)])
			var at := Vector3(
				rng.randf_range(float(area[0]), float(area[2])), 0.0,
				rng.randf_range(float(area[1]), float(area[3]))
			)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(
				Vector3.ONE * rng.randf_range(float(scales[0]), float(scales[1]))
			)
			if not batches.has(kind):
				batches[kind] = []
			batches[kind].append(Transform3D(basis, at))
	for kind: String in batches:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = SiegeArt.mesh(kind)
		var transforms: Array = batches[kind]
		multimesh.instance_count = transforms.size()
		for i: int in transforms.size():
			multimesh.set_instance_transform(i, transforms[i] as Transform3D)
		var trees := MultiMeshInstance3D.new()
		trees.name = kind
		trees.multimesh = multimesh
		add_child(trees)


## Rocks [piece, x, z, scale], hills [piece, x, z, yaw, scale], village [piece, x, z, yaw].
func _add_props(ground: Dictionary) -> void:
	for entry: Variant in ground.get("rocks", []):
		var rock: Array = entry
		var node := SiegeArt.instance(str(rock[0]), float(rock[1]) * 13.0,
			Vector3.ONE * float(rock[3]))
		node.position = Vector3(float(rock[1]), 0.0, float(rock[2]))
		add_child(node)
	for entry: Variant in ground.get("hills", []):
		var hill: Array = entry
		var node := SiegeArt.instance(str(hill[0]), float(hill[3]), Vector3.ONE * float(hill[4]))
		node.position = Vector3(float(hill[1]), 0.0, float(hill[2]))
		add_child(node)
	for entry: Variant in ground.get("village", []):
		var house: Array = entry
		var node := SiegeArt.instance(str(house[0]), float(house[3]), Vector3.ONE)
		node.position = Vector3(float(house[1]), 0.0, float(house[2]))
		add_child(node)


func _add_box(node_name: String, size: Vector3, at: Vector3, yaw: float, color: Color) -> void:
	var box := BoxMesh.new()
	box.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = box
	instance.transform = Transform3D(Basis(Vector3.UP, yaw), at)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.roughness = 0.9
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


static func _sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation = Vector3(
		deg_to_rad(-SiegeArt.number("light", "sun_elevation_deg", 40.0)),
		deg_to_rad(SiegeArt.number("light", "sun_azimuth_deg", -150.0)), 0.0
	)
	sun.light_color = SiegeArt.color("light", "sun_color", Color.WHITE)
	sun.light_energy = SiegeArt.number("light", "sun_energy", 1.2)
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.directional_shadow_max_distance = SiegeArt.number("light", "shadow_distance", 360.0)
	return sun


static func _environment() -> Environment:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = SiegeArt.color("light", "sky_top", Color.SKY_BLUE)
	sky_material.sky_horizon_color = SiegeArt.color("light", "sky_horizon", Color.WHITE)
	sky_material.ground_horizon_color = SiegeArt.color("light", "ground_horizon", Color.GRAY)
	sky_material.ground_bottom_color = SiegeArt.color("ground", "grass", Color.OLIVE_DRAB)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = SiegeArt.color("light", "ambient", Color.GRAY)
	environment.ambient_light_energy = SiegeArt.number("light", "ambient_energy", 0.4)
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.ssao_enabled = true
	environment.fog_enabled = true
	environment.fog_light_color = SiegeArt.color("light", "fog_color", Color.LIGHT_GRAY)
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_density = SiegeArt.number("light", "fog_density", 0.7)
	environment.fog_depth_begin = SiegeArt.number("light", "fog_begin", 240.0)
	environment.fog_depth_end = SiegeArt.number("light", "fog_end", 620.0)
	environment.fog_sky_affect = 0.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.3
	return environment
