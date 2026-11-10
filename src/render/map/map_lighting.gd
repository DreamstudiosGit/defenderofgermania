class_name MapLighting
extends Node3D
## Candlelight over the war table: a dark room, dim warm ambient light, a soft key light from
## above and table candles whose flames flicker gently. The costly parts follow the graphics
## quality ("quality" in data/map_art.json: ambient occlusion, indirect light, glow, the key
## light's shadow splits, how many candles cast shadows and into how large a shadow map), when
## the table is built and whenever the player changes the option.

var _environment := Environment.new()
var _key := DirectionalLight3D.new()
var _lights: Array[OmniLight3D] = []
var _energies: PackedFloat32Array = []
var _flames: Array[MeshInstance3D] = []
## Candle indices, those the data lets cast shadows first: quality takes them from the front.
var _casters: Array[int] = []
var _noise := FastNoiseLite.new()
var _time: float = 0.0
var _flicker_amount: float = 0.14
var _flicker_speed: float = 6.0
## The viewport's shadow map size before the table changed it.
var _atlas_before: int = -1


func build(table: Rect2) -> void:
	var light := MapArt.section("light")
	_flicker_amount = float(light.get("flicker_amount", 0.14))
	_flicker_speed = float(light.get("flicker_speed", 6.0))
	_set_up_environment(light)
	_key.name = "KeyLight"
	_key.rotation = Vector3(
		deg_to_rad(float(light.get("key_pitch_deg", -58.0))),
		deg_to_rad(float(light.get("key_yaw_deg", 24.0))), 0.0
	)
	_key.light_color = MapArt.color("light", "key_color", Color.WHITE)
	_key.light_energy = float(light.get("key_energy", 0.75))
	_key.shadow_enabled = true
	_key.shadow_bias = 0.04
	_key.directional_shadow_max_distance = maxf(table.size.x, table.size.y) * 2.5
	add_child(_key)
	_noise.frequency = 1.0
	var candle_color := MapArt.color("light", "candle_color", Color.ORANGE)
	var late: Array[int] = []
	for entry: Variant in MapArt.settings().get("candles", []):
		if entry is Dictionary:
			var casts := bool((entry as Dictionary).get("shadow", false))
			(_casters if casts else late).append(_lights.size())
			_add_candle(entry as Dictionary, candle_color)
	_casters.append_array(late)
	apply_quality(App.quality())
	App.settings.changed.connect(_on_setting_changed)


func _exit_tree() -> void:
	if _atlas_before >= 0:
		get_viewport().positional_shadow_atlas_size = _atlas_before
		_atlas_before = -1


func _process(delta: float) -> void:
	flicker(delta)


## Moves the candles' flicker on by `delta` seconds.
func flicker(delta: float) -> void:
	_time += delta
	for i: int in _lights.size():
		var wave := _noise.get_noise_2d(_time * _flicker_speed, i * 31.0) * _flicker_amount
		_lights[i].light_energy = _energies[i] * (1.0 + wave)
		_flames[i].scale = Vector3(1.0, 1.0 + wave * 1.5, 1.0)


## Switches the costly parts for a graphics quality level (UserSettings.Quality).
func apply_quality(level: int) -> void:
	_environment.ssao_enabled = bool(MapArt.by_quality("ssao", level, true))
	_environment.ssil_enabled = bool(MapArt.by_quality("ssil", level, false))
	_environment.glow_enabled = bool(MapArt.by_quality("glow", level, true))
	_key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	if int(MapArt.by_quality("key_shadow_splits", level, 4)) < 4:
		_key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	var shadows := int(MapArt.by_quality("candle_shadows", level, _casters.size()))
	for order: int in _casters.size():
		_lights[_casters[order]].shadow_enabled = order < shadows
	if is_inside_tree():
		var viewport := get_viewport()
		if _atlas_before < 0:
			_atlas_before = viewport.positional_shadow_atlas_size
		viewport.positional_shadow_atlas_size = int(
			MapArt.by_quality("candle_shadow_atlas", level, _atlas_before)
		)


func _on_setting_changed(key: String) -> void:
	if key == UserSettings.QUALITY:
		apply_quality(App.quality())


func _add_candle(entry: Dictionary, color: Color) -> void:
	var at: Array = entry.get("at", [0.0, 0.0])
	var height := float(entry.get("height", 4.0))
	var base := Vector3(float(at[0]), 0.0, float(at[1])) if at.size() == 2 else Vector3.ZERO
	var holder := MeshInstance3D.new()
	holder.mesh = MapMeshes.cylinder(1.3, 1.6, 0.4, 16)
	holder.position = base + Vector3(0.0, 0.2, 0.0)
	holder.material_override = MapArt.paint(MapArt.color("pieces", "gold", Color.GOLD))
	add_child(holder)
	var wax := MeshInstance3D.new()
	wax.mesh = MapMeshes.cylinder(0.6, 0.65, height, 12)
	wax.position = base + Vector3(0.0, 0.4 + height * 0.5, 0.0)
	wax.material_override = MapArt.paint(MapArt.color("light", "wax_color", Color.WHEAT))
	add_child(wax)
	var flame := MeshInstance3D.new()
	flame.mesh = MapMeshes.sphere(0.28, 0.9)
	flame.position = base + Vector3(0.0, 0.4 + height + 0.5, 0.0)
	var flame_material := StandardMaterial3D.new()
	flame_material.albedo_color = color.lightened(0.35)
	flame_material.emission_enabled = true
	flame_material.emission = color
	flame_material.emission_energy_multiplier = 4.0
	flame.material_override = flame_material
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flame)
	_flames.append(flame)
	var light := OmniLight3D.new()
	light.position = flame.position + Vector3(0.0, 0.8, 0.0)
	light.light_color = color
	light.light_energy = float(entry.get("energy", 5.0))
	light.omni_range = float(entry.get("range", 60.0))
	light.omni_attenuation = 1.2
	add_child(light)
	_lights.append(light)
	_energies.append(light.light_energy)


func _set_up_environment(light: Dictionary) -> void:
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color.from_string(str(light.get("background", "")), Color.BLACK)
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color.from_string(str(light.get("ambient", "")), Color.GRAY)
	_environment.ambient_light_energy = float(light.get("ambient_energy", 0.55))
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.ssao_radius = 1.2
	_environment.ssao_intensity = 1.6
	_environment.glow_intensity = float(light.get("glow", 0.45))
	_environment.glow_hdr_threshold = 1.2
	var world := WorldEnvironment.new()
	world.name = "Environment"
	world.environment = _environment
	add_child(world)
