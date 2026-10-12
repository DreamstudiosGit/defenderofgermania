class_name BattleTumblers
extends Node3D
## Comic falls instead of blood: when a company loses figures, each lost figure is thrown up,
## somersaults, lies on the grass for a moment and vanishes; some lose their helmet on the way.
## Fled companies leave the field and do not tumble. Presentation only.

const CAPACITY := 48
const FLIGHT := 0.9
const LIE := 1.2
const SHRINK := 0.3
const GRAVITY := 14.0
const HELMET_CHANCE := 0.5
const HELMET_COLOR := Color(0.45, 0.47, 0.5)
const HIDDEN := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)

var _rng := RandomNumberGenerator.new()
var _last_alive := PackedInt32Array()
var _armies: Array[BattleRules.ArmyPreset] = []
## Per "unit_side" layer: MultiMeshInstance3D, then the flying figures' state.
var _layers: Dictionary[String, MultiMeshInstance3D] = {}
var _start: Dictionary[String, PackedVector3Array] = {}
var _velocity: Dictionary[String, PackedVector3Array] = {}
var _spin: Dictionary[String, PackedVector3Array] = {}
var _age: Dictionary[String, PackedFloat64Array] = {}
var _next: Dictionary[String, int] = {}


func setup(state: BattleState, armies: Array[BattleRules.ArmyPreset]) -> void:
	_rng.seed = 1198
	_armies = armies
	_last_alive.resize(state.company_count())
	for c: int in state.company_count():
		_last_alive[c] = state.alive_figures(c)
	for key: String in _age:
		var ages := _age[key]
		ages.fill(FLIGHT + LIE + SHRINK)
		_age[key] = ages
		for i: int in CAPACITY:
			_layers[key].multimesh.set_instance_transform(i, HIDDEN)


## Fallen figures (helmets excluded) still flying, lying or shrinking.
func active() -> int:
	var count := 0
	for key: String in _age:
		if key == "helmet":
			continue
		for age: float in _age[key]:
			if age < FLIGHT + LIE + SHRINK:
				count += 1
	return count


func update_view(state: BattleState, delta: float) -> void:
	for c: int in mini(state.company_count(), _last_alive.size()):
		var alive := state.alive_figures(c)
		if state.status[c] == BattleState.Status.FLED:
			alive = 0
		elif alive < _last_alive[c]:
			for k: int in range(alive, _last_alive[c]):
				_throw(state, c, state.fig_pos[state.fig_start[c] + k])
		_last_alive[c] = alive
	for key: String in _layers:
		_advance(key, delta)


func _throw(state: BattleState, c: int, at: Vector2) -> void:
	var foe := state.contact[c]
	var away := Vector2.from_angle(_rng.randf() * TAU)
	if foe >= 0 and state.pos[foe] != at:
		away = state.pos[foe].direction_to(at).rotated(_rng.randf_range(-0.6, 0.6))
	var velocity := Vector3(away.x, 0.0, away.y) * _rng.randf_range(2.0, 4.0)
	velocity.y = _rng.randf_range(4.5, 6.5)
	var spin := Vector3(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1)).normalized()
	_add(_layer(state.unit_ids[c], state.side[c]), Vector3(at.x, 0.0, at.y), velocity, spin)
	if _rng.randf() < HELMET_CHANCE:
		velocity.y += 2.0
		_add(_layer("helmet", -1), Vector3(at.x, 1.6, at.y), velocity * 1.2, -spin)


func _add(key: String, at: Vector3, velocity: Vector3, spin: Vector3) -> void:
	if key.is_empty():
		return
	var i := _next[key]
	# Packed arrays are values: change a copy and store it back.
	var starts := _start[key]
	var velocities := _velocity[key]
	var spins := _spin[key]
	var ages := _age[key]
	starts[i] = at
	velocities[i] = velocity
	spins[i] = spin if spin != Vector3.ZERO else Vector3.RIGHT
	ages[i] = 0.0
	_start[key] = starts
	_velocity[key] = velocities
	_spin[key] = spins
	_age[key] = ages
	_next[key] = (i + 1) % CAPACITY


## Flight on a parabola with a somersault, then lying flat on the grass, then shrinking away.
func _advance(key: String, delta: float) -> void:
	var multimesh := _layers[key].multimesh
	var ages := _age[key]
	for i: int in CAPACITY:
		if ages[i] >= FLIGHT + LIE + SHRINK:
			continue
		ages[i] += delta
		var t := minf(ages[i], FLIGHT)
		var at := _start[key][i] + _velocity[key][i] * t + Vector3.DOWN * GRAVITY * 0.5 * t * t
		at.y = maxf(at.y, 0.1)
		var turn := minf(ages[i] / FLIGHT, 1.0) * (TAU + PI * 0.5)
		var size := clampf((FLIGHT + LIE + SHRINK - ages[i]) / SHRINK, 0.0, 1.0)
		var basis := Basis(_spin[key][i], turn).scaled(Vector3.ONE * size)
		multimesh.set_instance_transform(i, Transform3D(basis, at) if size > 0.0 else HIDDEN)
	_age[key] = ages


func _layer(unit_id: String, side: int) -> String:
	var key := unit_id if side < 0 else "%s_%d" % [unit_id, side]
	if _layers.has(key):
		return key
	var house := _armies[side].house if side >= 0 and side < _armies.size() else ""
	var mesh: Mesh = _helmet() if side < 0 else BattleModels.unit_mesh(unit_id, house)
	if mesh == null:
		return ""
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = CAPACITY
	for i: int in CAPACITY:
		multimesh.set_instance_transform(i, HIDDEN)
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	if side >= 0 and side < _armies.size():
		BattleFigures.paint_house(instance, _armies[side])
	add_child(instance)
	_layers[key] = instance
	var starts := PackedVector3Array()
	starts.resize(CAPACITY)
	_start[key] = starts
	_velocity[key] = starts.duplicate()
	_spin[key] = starts.duplicate()
	var ages := PackedFloat64Array()
	ages.resize(CAPACITY)
	ages.fill(FLIGHT + LIE + SHRINK)
	_age[key] = ages
	_next[key] = 0
	return key


static func _helmet() -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.2
	mesh.height = 0.2
	mesh.is_hemisphere = true
	mesh.radial_segments = 8
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.albedo_color = HELMET_COLOR
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mesh.material = material
	return mesh
