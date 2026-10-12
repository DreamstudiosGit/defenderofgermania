class_name MapLighting
extends Node3D
## Candlelight over the war table: a dark room, dim warm ambient light, a soft key light from
## above and table candles whose flames flicker gently.

var _lights: Array[OmniLight3D] = []
var _energies: PackedFloat32Array = []
var _flames: Array[MeshInstance3D] = []
var _noise := FastNoiseLite.new()
var _time: float = 0.0


func build(table: Rect2) -> void:
	var light := MapArt.section("light")
	add_child(_environment(light))
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.rotation = Vector3(
		deg_to_rad(float(light.get("key_pitch_deg", -58.0))),
		deg_to_rad(float(light.get("key_yaw_deg", 24.0))), 0.0
	)
	key.light_color = MapArt.color("light", "key_color", Color.WHITE)
	key.light_energy = float(light.get("key_energy", 0.75))
	key.shadow_enabled = true
	key.shadow_bias = 0.04
	key.directional_shadow_max_distance = maxf(table.size.x, table.size.y) * 2.5
	add_child(key)
	_noise.frequency = 1.0
	var candle_color := MapArt.color("light", "candle_color", Color.ORANGE)
	for entry: Variant in MapArt.settings().get("candles", []):
		if entry is Dictionary:
			_add_candle(entry as Dictionary, candle_color)


func _process(delta: float) -> void:
	flicker(delta)


## Moves the candles' flicker on by `delta` seconds.
func flicker(delta: float) -> void:
	_time += delta
	var amount := MapArt.number("light", "flicker_amount", 0.14)
	var speed := MapArt.number("light", "flicker_speed", 6.0)
	for i: int in _lights.size():
		var wave := _noise.get_noise_2d(_time * speed, i * 31.0)
		_lights[i].light_energy = _energies[i] * (1.0 + wave * amount)
		_flames[i].scale = Vector3(1.0, 1.0 + wave * amount * 1.5, 1.0)


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
	light.shadow_enabled = bool(entry.get("shadow", false))
	add_child(light)
	_lights.append(light)
	_energies.append(light.light_energy)


static func _environment(light: Dictionary) -> WorldEnvironment:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.from_string(str(light.get("background", "")), Color.BLACK)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.from_string(str(light.get("ambient", "")), Color.GRAY)
	environment.ambient_light_energy = float(light.get("ambient_energy", 0.55))
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 1.6
	environment.glow_enabled = true
	environment.glow_intensity = float(light.get("glow", 0.45))
	environment.glow_hdr_threshold = 1.2
	var world := WorldEnvironment.new()
	world.name = "Environment"
	world.environment = environment
	return world
