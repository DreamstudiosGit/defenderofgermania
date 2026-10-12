class_name SiegeEffects
extends Node3D
## Dust bursts where stones land and parts fall, and fires on burning wooden parts: soft puff
## particles tinted per effect ("dust" and "fire" in data/combat_siege_art.json). Presentation
## only.

var _bursts: Array[CPUParticles3D] = []
var _ages := PackedFloat64Array()


func burst(at: Vector3, color: Color, radius: float, amount_scale: float = 1.0) -> void:
	var particles := CPUParticles3D.new()
	particles.name = "Dust"
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = maxi(4, roundi(SiegeArt.number("dust", "amount", 40.0) * amount_scale))
	particles.lifetime = SiegeArt.number("dust", "lifetime", 1.6)
	particles.mesh = _quad(radius * 0.5 + 1.0)
	particles.material_override = CastleArt.puff()
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = radius
	particles.direction = Vector3.UP
	particles.spread = 70.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 6.0 + radius
	particles.gravity = Vector3(0.0, -3.0, 0.0)
	particles.damping_min = 2.0
	particles.damping_max = 4.0
	particles.scale_amount_min = 0.8
	particles.scale_amount_max = 1.8
	particles.color_ramp = _fade(color)
	particles.position = at
	add_child(particles)
	particles.emitting = true
	_bursts.append(particles)
	_ages.append(0.0)


## A fire on a part: flames and smoke over a box of the given size, as a child of `parent`.
func fire(parent: Node3D, center: Vector3, size: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "Fire"
	root.position = center
	parent.add_child(root)
	var amount := roundi(SiegeArt.number("fire", "amount", 26.0))
	var lifetime := SiegeArt.number("fire", "lifetime", 1.2)
	var flames := _emitter(size, amount, lifetime, 1.6)
	flames.color_ramp = _fade(SiegeArt.color("fire", "color", Color.ORANGE))
	flames.initial_velocity_min = 2.0
	flames.initial_velocity_max = 4.0
	root.add_child(flames)
	var smoke := _emitter(size, roundi(amount * 0.5), lifetime * 3.0, 2.6)
	smoke.color_ramp = _fade(SiegeArt.color("fire", "smoke", Color(0.3, 0.3, 0.3, 0.7)))
	smoke.initial_velocity_min = 3.0
	smoke.initial_velocity_max = 5.0
	smoke.position = Vector3(0.0, size.y * 0.3, 0.0)
	root.add_child(smoke)
	return root


func update(delta: float) -> void:
	for i: int in range(_bursts.size() - 1, -1, -1):
		_ages[i] += delta
		if _ages[i] > _bursts[i].lifetime + 0.5:
			_bursts[i].queue_free()
			_bursts.remove_at(i)
			_ages.remove_at(i)


func clear() -> void:
	for particles: CPUParticles3D in _bursts:
		particles.queue_free()
	_bursts.clear()
	_ages.clear()


## Flames trailing a flying fire pot; they stay where they were emitted.
static func trail_flames(color: Color) -> CPUParticles3D:
	var particles := _emitter(Vector3.ONE * 0.6, 24, 0.5, 1.4)
	particles.name = "Flames"
	particles.color_ramp = _fade(color)
	particles.gravity = Vector3(0.0, 2.0, 0.0)
	particles.local_coords = false
	particles.emitting = false
	return particles


static func _emitter(size: Vector3, amount: int, lifetime: float, puff: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = maxi(4, amount)
	particles.lifetime = lifetime
	particles.mesh = _quad(puff)
	particles.material_override = CastleArt.puff()
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = size * 0.5
	particles.direction = Vector3.UP
	particles.spread = 15.0
	particles.gravity = Vector3(0.6, 1.5, 0.0)
	particles.scale_amount_min = 0.7
	particles.scale_amount_max = 1.4
	particles.emitting = true
	return particles


static func _quad(size: float) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	return quad


static func _fade(color: Color) -> Gradient:
	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color, 0.0))
	return gradient
