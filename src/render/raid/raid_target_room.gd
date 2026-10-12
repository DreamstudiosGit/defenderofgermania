class_name RaidTargetRoom
extends Node3D
## The room at the end of the raid, furnished for its target: the treasury's strongbox and coin
## heaps, the dungeon cell with a prisoner of the raider's house, the granary's sacks and hay, or
## the chapel altar with the imperial regalia. The deed changes it: the strongbox opens, the cell
## door swings, the hay burns, the regalia are gone.

const BACK_INSET := 0.6

var _target: String = ""
var _hinge: Node3D
var _taken: Array[Node3D] = []
var _fires: Array[CPUParticles3D] = []
var _light: OmniLight3D
var _done: float = -1.0


func build(
	world: RaidWorld, target: String, raider_colors: PackedColorArray, seed_value: int
) -> void:
	_target = target
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var deed := world.layout.deed_x
	var level := world.floor_y(deed)
	var back := world.back_z + BACK_INSET
	_light = OmniLight3D.new()
	_light.light_color = RaidArt.light_color("torch")
	_light.light_energy = 1.6
	_light.omni_range = 6.0
	_light.position = Vector3(deed + 0.8, level + 2.2, 0.8)
	add_child(_light)
	match target:
		"treasury":
			_treasury(deed, level, back, rng)
		"dungeon":
			_dungeon(world, deed, level, raider_colors)
		"granary":
			_granary(deed, level, back, rng)
		_:
			_regalia(world, deed, level)


## The deed is done.
func complete() -> void:
	_done = 0.0
	for node: Node3D in _taken:
		node.visible = false
	for fire: CPUParticles3D in _fires:
		fire.emitting = true


func _process(delta: float) -> void:
	if _done < 0.0:
		return
	_done = minf(_done + delta, 1.0)
	if _hinge != null:
		_hinge.rotation.y = -_done * PI * 0.5 if _target == "dungeon" else 0.0
		_hinge.rotation.z = _done * 1.4 if _target == "treasury" else _hinge.rotation.z
	if not _fires.is_empty():
		_light.light_color = Color(1.0, 0.45, 0.15)
		_light.light_energy = 1.6 + 4.0 * _done


func _treasury(deed: float, level: float, back: float, rng: RandomNumberGenerator) -> void:
	var box := Vector3(deed + 0.95, level, -0.45)
	add_child(RaidArt.box(Vector3(0.9, 0.55, 0.65), box + Vector3(0, 0.275, 0), "wood"))
	for band: float in [-0.3, 0.3]:
		add_child(RaidArt.box(Vector3(0.08, 0.57, 0.67), box + Vector3(band, 0.285, 0), "iron"))
	_hinge = Node3D.new()
	_hinge.position = box + Vector3(-0.45, 0.55, 0)
	add_child(_hinge)
	_hinge.add_child(RaidArt.box(Vector3(0.9, 0.16, 0.65), Vector3(0.45, 0.08, 0), "wood_dark"))
	var gold := RaidArt.glow(RaidArt.color("gold"), 0.6)
	var glint := RaidArt.box(Vector3(0.75, 0.08, 0.5), box + Vector3(0, 0.54, 0), "gold")
	glint.material_override = gold
	add_child(glint)
	for i: int in 3:
		var x := deed - 1.6 + i * 1.7
		add_child(RaidArt.box(Vector3(1.0, 0.6, 0.6), Vector3(x, level + 0.3, back), "wood_dark"))
		add_child(RaidArt.box(Vector3(1.02, 0.08, 0.62), Vector3(x, level + 0.45, back), "iron"))
	for i: int in 40:
		var coin := RaidArt.cylinder(0.06, 0.025, Vector3(
			deed + rng.randf_range(-1.8, 2.6), level + 0.62 + rng.randf_range(0.0, 0.08),
			back + rng.randf_range(-0.2, 0.2)
		), "gold")
		coin.rotation = Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
		add_child(coin)
		if i < 12:
			_taken.append(coin)


func _dungeon(world: RaidWorld, deed: float, level: float, raider_colors: PackedColorArray) -> void:
	var grille_z := world.back_z + 1.3
	add_child(RaidArt.box(
		Vector3(4.0, 0.12, 0.12), Vector3(deed + 0.4, level + 2.4, grille_z), "iron"
	))
	var x := deed - 1.6
	while x <= deed + 2.4:
		if x < deed - 0.45 or x > deed + 0.65:
			add_child(RaidArt.cylinder(0.035, 2.4, Vector3(x, level + 1.2, grille_z), "iron"))
		x += 0.22
	_hinge = Node3D.new()
	_hinge.position = Vector3(deed - 0.45, level, grille_z)
	add_child(_hinge)
	var bar := 0.0
	while bar <= 1.1:
		_hinge.add_child(RaidArt.cylinder(0.035, 2.3, Vector3(bar, 1.15, 0), "iron"))
		bar += 0.22
	_hinge.add_child(RaidArt.box(Vector3(1.1, 0.08, 0.08), Vector3(0.55, 1.2, 0), "iron"))
	var prisoner := MeshInstance3D.new()
	prisoner.mesh = BattleModels.unit_mesh("levy", "")
	prisoner.position = Vector3(deed + 0.2, level, world.back_z + 0.6)
	if raider_colors.size() >= 2:
		prisoner.set_instance_shader_parameter("house_primary", raider_colors[0])
		prisoner.set_instance_shader_parameter("house_secondary", raider_colors[1])
	add_child(prisoner)
	for k: int in 2:
		add_child(RaidArt.box(
			Vector3(0.05, 0.6, 0.05),
			Vector3(deed - 1.0 + k * 2.6, level + 1.6, world.back_z + 0.15),
			"iron"
		))


func _granary(deed: float, level: float, back: float, rng: RandomNumberGenerator) -> void:
	for i: int in 9:
		var sack := MeshInstance3D.new()
		var shape := SphereMesh.new()
		shape.radius = 0.32
		shape.height = 0.5
		shape.radial_segments = 8
		shape.rings = 4
		sack.mesh = shape
		sack.material_override = RaidArt.material("linen")
		sack.position = Vector3(
			deed - 1.4 + (i % 5) * 0.62,
			level + 0.25 + (i / 5) * 0.42,
			back + rng.randf_range(-0.15, 0.15)
		)
		add_child(sack)
	for k: int in 2:
		var heap := MeshInstance3D.new()
		var shape := SphereMesh.new()
		shape.radius = 0.9
		shape.height = 1.1
		shape.radial_segments = 10
		shape.rings = 5
		heap.mesh = shape
		heap.material_override = RaidArt.material("hay")
		var at := Vector3(deed + 1.1 + k * 1.6, level + 0.2, -0.5 - k * 0.6)
		heap.position = at
		add_child(heap)
		_fires.append(_fire(at + Vector3(0, 0.6, 0.3)))
	var barrel := MeshInstance3D.new()
	barrel.mesh = BattleModels.mesh("prop_barrel_wood")
	barrel.position = Vector3(deed - 2.4, level, back)
	add_child(barrel)


func _regalia(world: RaidWorld, deed: float, level: float) -> void:
	var altar := Vector3(deed + 1.1, level, -0.8)
	add_child(RaidArt.box(Vector3(1.3, 1.0, 0.9), altar + Vector3(0, 0.5, 0), "stone"))
	add_child(RaidArt.box(Vector3(1.36, 0.06, 0.96), altar + Vector3(0, 1.02, 0), "linen"))
	var crown := Node3D.new()
	crown.position = altar + Vector3(0, 1.12, 0)
	add_child(crown)
	var cushion := RaidArt.box(Vector3(0.5, 0.12, 0.4), Vector3.ZERO, "wood")
	cushion.material_override = RaidArt.material("linen", Color(0.75, 0.2, 0.2))
	crown.add_child(cushion)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.13
	torus.outer_radius = 0.18
	ring.mesh = torus
	ring.material_override = RaidArt.glow(RaidArt.color("gold"), 0.5)
	ring.position = Vector3(0, 0.12, 0)
	crown.add_child(ring)
	for i: int in 8:
		var angle := TAU * i / 8.0
		var spike := RaidArt.box(
			Vector3(0.05, 0.12, 0.05), Vector3(cos(angle) * 0.155, 0.2, sin(angle) * 0.155), "gold"
		)
		crown.add_child(spike)
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.18
	orb.mesh = sphere
	orb.material_override = ring.material_override
	orb.position = Vector3(0.36, 0.14, 0.05)
	crown.add_child(orb)
	_taken.append(crown)
	var window := Vector3(altar.x, level + 2.75, world.back_z + 0.12)
	var panes: Array[Color] = [Color("#b8333a"), Color("#3a5fbf"), Color("#e0b040"), Color("#3f8f5a")]
	for i: int in 4:
		var pane := RaidArt.box(
			Vector3(0.34, 0.9, 0.05), window + Vector3(-0.54 + i * 0.36, 0, 0), "glass"
		)
		pane.material_override = RaidArt.glow(panes[i].darkened(0.25), 0.5)
		add_child(pane)
		add_child(RaidArt.box(
			Vector3(0.05, 0.95, 0.08), window + Vector3(-0.72 + i * 0.36, 0, 0.02), "iron"
		))
	add_child(RaidArt.box(Vector3(1.5, 0.05, 0.08), window + Vector3(0, 0.12, 0.02), "iron"))
	add_child(RaidArt.box(Vector3(1.6, 1.15, 0.1), window - Vector3(0, 0, 0.04), "stone_dark"))
	for side: float in [-0.75, 0.75]:
		add_child(RaidArt.cylinder(0.04, 0.5, altar + Vector3(side, 1.25, 0.2), "linen"))
		var flame := RaidArt.box(
			Vector3(0.05, 0.1, 0.05), altar + Vector3(side, 1.55, 0.2), "flame"
		)
		flame.material_override = RaidArt.glow(RaidArt.color("flame"), 3.0)
		add_child(flame)


func _fire(at: Vector3) -> CPUParticles3D:
	var fire := CPUParticles3D.new()
	fire.position = at
	fire.emitting = false
	fire.amount = 48
	fire.lifetime = 0.9
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 0.5
	fire.direction = Vector3.UP
	fire.spread = 18.0
	fire.gravity = Vector3(0, 2.5, 0)
	fire.initial_velocity_min = 0.6
	fire.initial_velocity_max = 1.4
	fire.scale_amount_min = 0.25
	fire.scale_amount_max = 0.55
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.8, 0.3, 0.9))
	ramp.set_color(1, Color(0.7, 0.12, 0.02, 0.0))
	ramp.add_point(0.45, Color(1.0, 0.42, 0.08, 0.7))
	fire.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.45, 0.6)
	fire.mesh = quad
	var material := CastleArt.puff().duplicate() as StandardMaterial3D
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fire.material_override = material
	add_child(fire)
	return fire
