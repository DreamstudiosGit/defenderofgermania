class_name JoustRiders
extends Node3D
## The two riders with their striped lances on the lists: gallop from the figures' UV2 limb
## masks, lances aimed at the simulation's tip, splinters when a lance breaks and a comic fall
## (no blood) when a rider leaves the saddle. Presentation only.

## Right hand of a seated knight in model space (the lance is held on the right).
const HAND := Vector3(-0.33, 1.72, 0.3)
## Seen through the helmet the couched lance sits higher, so it enters the eye slit.
const HAND_IN_HELMET := Vector3(-0.3, 2.02, 0.45)
const RAISED_LANCE := Vector3(-0.3, 0.55, 0.78)
const LOWERING_SECONDS := 0.45
const PIVOT := Vector3(0.0, 1.55, 0.0)
const FALL_SECONDS := 1.1
const FALL_FORWARD := 1.5
const FALL_SIDE := 1.6
const FALL_HEIGHT := 1.3
const LYING_HEIGHT := 0.35
const GRAVITY := 9.0
const CHEER_HOP := 0.35
const CHEER_RATE := 8.0
const SPLINTERS := 26
const DUST := 18
const WOOD := Color(0.54, 0.38, 0.22)

var _horses: Array[MultiMeshInstance3D] = []
var _bodies: Array[MultiMeshInstance3D] = []
var _lances: Array[Array] = []
var _broken: Array[bool] = [false, false]
var _fall_age: Array[float] = [-1.0, -1.0]
var _fall_from: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY]
var _splinters: Array[CPUParticles3D] = []
var _dust: CPUParticles3D
var _hide_body: int = -1
var _gait_phase: Array[float] = [0.0, 1.7]


## colors[r] holds the field and charge colour of rider r's owner.
func setup(owners: Array[String], colors: Array[PackedColorArray]) -> void:
	for child: Node in get_children():
		child.free()
	_horses.clear()
	_bodies.clear()
	_lances.clear()
	_splinters.clear()
	for r: int in JoustState.RIDERS:
		var meshes := JoustModels.rider_meshes(owners[r])
		_horses.append(_figure(meshes[0] if meshes.size() > 0 else null, colors[r]))
		_bodies.append(_figure(meshes[1] if meshes.size() > 1 else null, colors[r]))
		var parts: Array[MeshInstance3D] = []
		for mesh: ArrayMesh in JoustModels.lance_meshes():
			var part := MeshInstance3D.new()
			part.mesh = mesh
			part.set_instance_shader_parameter("house_primary", colors[r][0])
			part.set_instance_shader_parameter("house_secondary", colors[r][1])
			add_child(part)
			parts.append(part)
		_lances.append(parts)
		_splinters.append(_splinter_burst(colors[r]))
	_dust = _dust_burst()
	reset()


func reset() -> void:
	_broken = [false, false]
	_fall_age = [-1.0, -1.0]


## Hides a rider's body (the first-person view sits inside it); -1 shows both.
func hide_body(rider: int) -> void:
	_hide_body = rider


func handle_events(sim: JoustSim) -> void:
	for event: JoustEvent in sim.state.events:
		match event.kind:
			JoustEvent.Kind.PASS_START:
				_broken = [false, false]
			JoustEvent.Kind.HIT:
				var attacker := sim.state.riders[event.rider]
				if attacker.last_couched and attacker.last_zone >= 0 and attacker.last_perfect:
					_broken[event.rider] = true
					var tip := lance_tip(event.rider)
					_splinters[event.rider].global_position = tip
					_splinters[event.rider].restart()
			JoustEvent.Kind.UNSEAT:
				_fall_age[event.rider] = 0.0
				_fall_from[event.rider] = _bodies[event.rider].multimesh.get_instance_transform(0)


func update_view(sim: JoustSim, alpha: float, delta: float) -> void:
	var track := JoustTrack.at(sim, alpha)
	var dt := sim.tick_seconds()
	var time := (sim.state.tick + alpha) * dt
	for r: int in JoustState.RIDERS:
		var at := Transform3D(track.basis(r), track.position(r))
		var movement := clampf(track.speed / 8.0, 0.0, 1.0)
		var cheering := sim.state.phase in [JoustState.Phase.FINALE, JoustState.Phase.OVER]
		if cheering and sim.state.winner == r:
			at.origin.y += absf(sin(time * CHEER_RATE)) * CHEER_HOP
		var animation := Color(_gait_phase[r], movement, 0.0, time)
		_place(_horses[r], at, animation)
		_bodies[r].visible = r != _hide_body
		if _fall_age[r] >= 0.0:
			var landed := _fall_age[r] >= FALL_SECONDS
			_fall_age[r] += delta
			var body := _falling(r)
			if not landed and _fall_age[r] >= FALL_SECONDS:
				_dust.global_position = body * PIVOT
				_dust.restart()
			_place(_bodies[r], body, Color(_gait_phase[r], 0.0, 0.0, time))
		else:
			_place(_bodies[r], at, animation)
		_aim_lance(sim, r, at, alpha)


## World point of the hand that holds the lance.
func hand(rider: int) -> Vector3:
	var horse := _horses[rider]
	if horse == null or horse.multimesh == null:
		return Vector3.ZERO
	return horse.multimesh.get_instance_transform(0) * _hand_offset(rider)


func _hand_offset(rider: int) -> Vector3:
	return HAND_IN_HELMET if rider == _hide_body else HAND


func lance_tip(rider: int) -> Vector3:
	var parts: Array = _lances[rider]
	var rear: MeshInstance3D = parts[0]
	return rear.global_transform * Vector3(0.0, JoustModels.LANCE_LENGTH, 0.0)


## Where a rider's body is, in the saddle or on the ground after a fall.
func body_position(rider: int) -> Vector3:
	var body := _bodies[rider]
	if body == null or body.multimesh == null:
		return Vector3.ZERO
	return body.multimesh.get_instance_transform(0) * PIVOT


## Chest of a rider in the world, the centre of the target plane.
func chest(rider: int) -> Vector3:
	var horse := _horses[rider]
	if horse == null or horse.multimesh == null:
		return Vector3.ZERO
	return horse.multimesh.get_instance_transform(0).origin + Vector3.UP * JoustTrack.CHEST_HEIGHT


func _aim_lance(sim: JoustSim, r: int, at: Transform3D, alpha: float) -> void:
	var grip := at * _hand_offset(r)
	var parts: Array = _lances[r]
	var direction := at.basis * RAISED_LANCE.normalized()
	var state := sim.state
	var lowering := 0.0
	if state.phase == JoustState.Phase.AIM:
		lowering = clampf((state.phase_tick + alpha) * sim.tick_seconds() / LOWERING_SECONDS, 0, 1)
	elif state.phase == JoustState.Phase.CLASH:
		lowering = 1.0
	if lowering > 0.0:
		var other := 1 - r
		var axes := JoustTrack.target_axes(grip, chest(other))
		var rider := state.riders[r]
		var tip := rider.impact_tip if state.phase == JoustState.Phase.CLASH else rider.tip
		var aimed := (JoustTrack.target_point(chest(other), axes, tip) - grip).normalized()
		direction = direction.slerp(aimed, lowering).normalized()
	if _fall_age[r] >= 0.0:
		direction = at.basis * Vector3(0.0, -0.3, 1.0).normalized()
		grip = _falling(r) * PIVOT
	var lance_basis := _basis_along(direction)
	var butt := grip - direction * JoustModels.GRIP
	var rear: MeshInstance3D = parts[0]
	var front: MeshInstance3D = parts[1]
	rear.global_transform = Transform3D(lance_basis, butt)
	front.global_transform = rear.global_transform
	front.visible = not _broken[r]


## The body tumbles off the horse: on, up and away from the barrier with a somersault and a
## quarter, then lies on its back.
func _falling(r: int) -> Transform3D:
	var share := minf(_fall_age[r], FALL_SECONDS) / FALL_SECONDS
	var start := _fall_from[r]
	var forward := start.basis.z.normalized()
	var away := Vector3(0.0, 0.0, 1.0 if r == 0 else -1.0)
	var height := FALL_HEIGHT * sin(PI * share) - (PIVOT.y - LYING_HEIGHT) * share
	var offset := forward * FALL_FORWARD * share + away * FALL_SIDE * share + Vector3.UP * height
	var spun := Basis(start.basis.x.normalized(), -PI * 2.5 * share) * start.basis
	return Transform3D(spun, start * PIVOT + offset - spun * PIVOT)


func _figure(mesh: ArrayMesh, colors: PackedColorArray) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = 1
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.set_instance_shader_parameter("house_primary", colors[0])
	instance.set_instance_shader_parameter("house_secondary", colors[1])
	add_child(instance)
	return instance


static func _place(instance: MultiMeshInstance3D, at: Transform3D, animation: Color) -> void:
	if instance.multimesh.mesh == null:
		return
	instance.multimesh.set_instance_transform(0, at)
	instance.multimesh.set_instance_custom_data(0, animation)


## A basis whose +y points along `direction` (the lance meshes run along +y).
static func _basis_along(direction: Vector3) -> Basis:
	var up := direction.normalized()
	var helper := Vector3.UP if absf(up.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := helper.cross(up).normalized()
	return Basis(x, up, x.cross(up))


func _splinter_burst(colors: PackedColorArray) -> CPUParticles3D:
	var burst := CPUParticles3D.new()
	burst.emitting = false
	burst.one_shot = true
	burst.amount = SPLINTERS
	burst.lifetime = 1.4
	burst.explosiveness = 0.95
	burst.direction = Vector3.UP
	burst.spread = 80.0
	burst.initial_velocity_min = 2.5
	burst.initial_velocity_max = 6.0
	burst.gravity = Vector3(0, -GRAVITY, 0)
	burst.angular_velocity_min = -720.0
	burst.angular_velocity_max = 720.0
	burst.particle_flag_rotate_y = true
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, 0.4)
	mesh.material = _vertex_color_material()
	burst.mesh = mesh
	var palette := Gradient.new()
	palette.offsets = PackedFloat32Array([0.0, 0.33, 0.66])
	palette.colors = PackedColorArray([colors[0], colors[1], WOOD])
	palette.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	burst.color_initial_ramp = palette
	add_child(burst)
	return burst


func _dust_burst() -> CPUParticles3D:
	var burst := CPUParticles3D.new()
	burst.emitting = false
	burst.one_shot = true
	burst.amount = DUST
	burst.lifetime = 1.6
	burst.explosiveness = 0.9
	burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 0.6
	burst.direction = Vector3.UP
	burst.spread = 70.0
	burst.initial_velocity_min = 0.6
	burst.initial_velocity_max = 1.8
	burst.gravity = Vector3(0, 0.3, 0)
	burst.scale_amount_min = 0.6
	burst.scale_amount_max = 1.4
	var mesh := SphereMesh.new()
	mesh.radius = 0.35
	mesh.height = 0.7
	mesh.radial_segments = 8
	mesh.rings = 4
	var material := _vertex_color_material()
	material.albedo_color = Color(0.82, 0.72, 0.55)
	mesh.material = material
	burst.mesh = mesh
	add_child(burst)
	return burst


static func _vertex_color_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material
