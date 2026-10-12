class_name RaidDressing
extends Node3D
## Torchlight and furnishing of the raid interior: flickering torches along the walls, moonlit
## windows and banners in the owner's colours in the halls, barrels and racks, the door frames
## and the far door the reinforcements come through.

const TORCH_HEIGHT := 2.3
const DOOR_HEIGHT := 2.9
## The reinforcements' door sits in the back wall this far before the end of the target room.
const FAR_DOOR_INSET := 1.0

var _lights: Array[OmniLight3D] = []
var _flames: Array[Node3D] = []
var _energy: float = 2.0
var _flicker: float = 0.2
var _noise := FastNoiseLite.new()
var _time: float = 0.0
var _far_door: Node3D
var _door_open: float = 0.0
var _door_target: float = 0.0


func build(world: RaidWorld, colors: PackedColorArray, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_noise.seed = seed_value
	_noise.frequency = 2.5
	_energy = RaidArt.number("light", "torch_energy", 2.4)
	_flicker = RaidArt.number("light", "flicker", 0.2)
	var layout := world.layout
	var spacing := RaidArt.number("light", "torch_spacing", 6.5)
	var x := 1.5
	while x < layout.end_x - FAR_DOOR_INSET - 1.2:
		if absf(x - layout.door_x) > 0.8:
			add_torch(Vector3(x, world.floor_y(x) + TORCH_HEIGHT, world.back_z + 0.2), true)
		x += spacing
	for path: RaidLayout.SneakPath in layout.sneak_paths:
		var middle := (path.from_x + path.to_x) * 0.5
		var level := world.floor_y(middle)
		if path.below:
			var bottom := level - RaidArt.number("rooms", "cellar_depth", 2.7)
			add_torch(Vector3(middle, bottom + 1.7, world.back_z + 0.2), false)
		else:
			var rise := RaidArt.number("rooms", "gallery_height", 2.9)
			add_torch(Vector3(middle, level + rise + 1.6, world.back_z + 0.2), false)
	for i: int in world.stretches.size():
		_dress_stretch(world, i, colors, rng)
	_lintel(world, layout.door_x)
	_wall_door(world, 0.4, true)
	_far_door = _wall_door(world, layout.end_x - FAR_DOOR_INSET, false)


func _process(delta: float) -> void:
	_time += delta
	for i: int in _lights.size():
		var wave := _noise.get_noise_2d(_time, i * 17.0)
		_lights[i].light_energy = _energy * (1.0 + _flicker * wave)
		_flames[i].scale = Vector3.ONE * (1.0 + 0.25 * wave)
	if _far_door != null and not is_equal_approx(_door_open, _door_target):
		_door_open = move_toward(_door_open, _door_target, delta * 2.5)
		_far_door.rotation.y = -_door_open * PI * 0.45


## A wall torch with its own flickering light; shadows only for the corridor torches.
func add_torch(at: Vector3, shadows: bool) -> void:
	var torch := Node3D.new()
	torch.position = at
	add_child(torch)
	torch.add_child(RaidArt.box(Vector3(0.12, 0.3, 0.12), Vector3(0, -0.3, -0.05), "iron"))
	var stick := RaidArt.cylinder(0.045, 0.5, Vector3(0, -0.12, 0.08), "wood_dark")
	stick.rotation.x = 0.35
	torch.add_child(stick)
	var flame := MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = 0.11
	shape.height = 0.36
	shape.radial_segments = 8
	shape.rings = 4
	flame.mesh = shape
	flame.material_override = RaidArt.glow(RaidArt.color("flame"), 3.0)
	flame.position = Vector3(0, 0.18, 0.16)
	torch.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = RaidArt.light_color("torch")
	light.omni_range = RaidArt.number("light", "torch_range", 7.0)
	light.omni_attenuation = 1.2
	light.light_energy = _energy
	light.shadow_enabled = shadows
	light.position = Vector3(0, 0.25, 0.6)
	torch.add_child(light)
	_lights.append(light)
	_flames.append(flame)


func open_far_door() -> void:
	_door_target = 1.0


func _dress_stretch(
	world: RaidWorld, i: int, colors: PackedColorArray, rng: RandomNumberGenerator
) -> void:
	var stretch := world.stretches[i]
	var x0 := maxf(stretch.x, 1.0)
	var x1 := minf(stretch.y, world.layout.door_x - 0.6)
	if x1 - x0 < 3.0:
		return
	var hall := world.ceilings[i] > RaidArt.number("rooms", "ceiling", 4.2) + 0.1
	var level := stretch.z
	if hall:
		_window(world, x0 + (x1 - x0) * 0.3, level)
		_window(world, x0 + (x1 - x0) * 0.7, level)
		_hanging(
			"castle_tapestry",
			Vector3((x0 + x1) * 0.5, level + 1.0, world.back_z + 0.12),
			0.75,
			colors
		)
	else:
		_hanging(
			"castle_banner",
			Vector3(x0 + (x1 - x0) * rng.randf_range(0.3, 0.7), level, world.back_z + 0.3),
			0.42,
			colors
		)
	var props := rng.randi_range(1, 3)
	for p: int in props:
		var px := rng.randf_range(x0 + 0.5, x1 - 0.5)
		var pz := world.back_z + rng.randf_range(0.45, 0.8)
		match rng.randi_range(0, 2):
			0:
				var barrel := MeshInstance3D.new()
				barrel.mesh = BattleModels.mesh("prop_barrel_wood")
				barrel.position = Vector3(px, world.floor_y(px), pz)
				add_child(barrel)
			1:
				add_child(RaidArt.box(
					Vector3(0.8, 0.6, 0.6), Vector3(px, world.floor_y(px) + 0.3, pz), "wood"
				))
			_:
				_rack(world, px, pz)


func _window(world: RaidWorld, x: float, level: float) -> void:
	add_child(RaidArt.box(
		Vector3(1.0, 2.2, 0.2), Vector3(x, level + 3.0, world.back_z + 0.05), "stone_dark"
	))
	var glass := RaidArt.box(
		Vector3(0.6, 1.8, 0.05), Vector3(x, level + 3.0, world.back_z + 0.16), "glass"
	)
	glass.material_override = RaidArt.glow(RaidArt.light_color("moon"), 0.9)
	add_child(glass)
	add_child(RaidArt.box(
		Vector3(0.06, 1.8, 0.08), Vector3(x, level + 3.0, world.back_z + 0.2), "iron"
	))
	add_child(RaidArt.box(
		Vector3(0.6, 0.06, 0.08), Vector3(x, level + 3.3, world.back_z + 0.2), "iron"
	))


## A castle kit piece hung on the wall in the owner's colours.
func _hanging(piece: String, at: Vector3, scale_factor: float, colors: PackedColorArray) -> void:
	var mesh := CastleArt.mesh(piece)
	if mesh == null:
		return
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.scale = Vector3.ONE * scale_factor
	instance.position = at
	if colors.size() >= 2:
		instance.set_instance_shader_parameter("house_primary", colors[0])
		instance.set_instance_shader_parameter("house_secondary", colors[1])
	add_child(instance)


func _rack(world: RaidWorld, x: float, z: float) -> void:
	var level := world.floor_y(x)
	add_child(RaidArt.box(Vector3(1.1, 0.08, 0.1), Vector3(x, level + 1.3, z - 0.1), "wood_dark"))
	add_child(RaidArt.box(Vector3(1.1, 0.08, 0.1), Vector3(x, level + 0.35, z - 0.1), "wood_dark"))
	for k: int in 3:
		var spear := RaidArt.cylinder(
			0.025, 2.0, Vector3(x - 0.35 + k * 0.35, level + 1.0, z), "wood"
		)
		spear.rotation.z = 0.08
		add_child(spear)
		add_child(RaidArt.box(
			Vector3(0.06, 0.2, 0.03), Vector3(x - 0.35 + k * 0.35 - 0.08, level + 2.05, z), "iron"
		))


## Lintel over the doorway into the target room.
func _lintel(world: RaidWorld, x: float) -> void:
	var level := world.floor_y(x)
	var top := world.ceiling_at(x) + 0.6
	var depth := world.front_z - world.back_z
	add_child(RaidArt.box(
		Vector3(0.7, top - level - DOOR_HEIGHT, depth),
		Vector3(x, (level + DOOR_HEIGHT + top) * 0.5, (world.front_z + world.back_z) * 0.5),
		"stone_dark"
	))


## A door in the back wall: dark opening, stone frame and a leaf hinged on its left edge.
func _wall_door(world: RaidWorld, x: float, open: bool) -> Node3D:
	var level := world.floor_y(x)
	var z := world.back_z
	add_child(RaidArt.box(Vector3(1.3, 2.5, 0.1), Vector3(x, level + 1.25, z + 0.03), "stone_cut"))
	add_child(RaidArt.box(
		Vector3(0.22, 2.7, 0.3), Vector3(x - 0.76, level + 1.35, z + 0.1), "stone_dark"
	))
	add_child(RaidArt.box(
		Vector3(0.22, 2.7, 0.3), Vector3(x + 0.76, level + 1.35, z + 0.1), "stone_dark"
	))
	add_child(RaidArt.box(Vector3(1.74, 0.3, 0.3), Vector3(x, level + 2.75, z + 0.1), "stone_dark"))
	var hinge := Node3D.new()
	hinge.position = Vector3(x - 0.62, level, z + 0.14)
	add_child(hinge)
	hinge.add_child(RaidArt.box(Vector3(1.24, 2.45, 0.1), Vector3(0.62, 1.23, 0), "wood"))
	for band: float in [0.5, 1.9]:
		hinge.add_child(RaidArt.box(Vector3(1.24, 0.1, 0.13), Vector3(0.62, band, 0), "iron"))
	if open:
		hinge.rotation.y = -PI * 0.45
	return hinge
