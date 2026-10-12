class_name BattleFigures
extends Node3D
## Batches Blender models by unit and side; UV2 limb masks animate in the vertex shader.

## Transform + ring color + animation phase, movement, contact and simulation time.
const FLOATS := 20
const SELECTION_BLUE := Color(0.12, 0.52, 1.0)
const LINE_SPEAR_TILT := 0.35
const HEDGEHOG_SPEAR_TILT := 1.0
const CAVALRY_RING_SCALE := 1.7
const LEADER_SCALE := 1.2
const ACTIVE_RING_SCALE := 1.15
const HIDDEN := Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)

var _instances: Array[MultiMeshInstance3D] = []
var _buffers: Array[PackedFloat32Array] = []
## Per layer, the figure index drawn by each instance.
var _figures: Array[PackedInt32Array] = []
var _layers: Array[String] = []
var _armies: Array[BattleRules.ArmyPreset] = []
var _alive := PackedInt32Array()
var _basis: Array[Basis] = []
var _ring_basis: Array[Basis] = []
var _ring_color := PackedColorArray()
var _movement := PackedFloat32Array()
var _tick_seconds: float = 0.0
var _motion_time: float = 0.0
var _selection_sides: Array[bool] = [false, false]


func setup(
	state: BattleState, armies: Array[BattleRules.ArmyPreset], tick_seconds: float
) -> void:
	_armies = armies
	_tick_seconds = tick_seconds
	for instance: MultiMeshInstance3D in _instances:
		instance.free()
	_instances.clear()
	_buffers.clear()
	_figures.clear()
	_layers.clear()
	var art := BattleModels.settings()
	var units: Dictionary = art.get("unit_models", {})
	for side: int in BattleState.SIDES:
		for unit_id: String in units:
			var figures := PackedInt32Array()
			for f: int in state.fig_pos.size():
				var c := state.fig_company[f]
				if state.side[c] == side and state.unit_ids[c] == unit_id:
					figures.append(f)
			if not figures.is_empty():
				_add_batch(BattleModels.unit_mesh(unit_id, side), figures, unit_id)
	var spears := PackedInt32Array()
	var rings := PackedInt32Array()
	for f: int in state.fig_pos.size():
		var c := state.fig_company[f]
		rings.append(f)
		if state.unit_ids[c] == "spearmen":
			spears.append(f)
	_add_batch(BattleModels.mesh("weapon_spear"), spears, "spear")
	_add_batch(_ring(), rings, "ring")


func _add_batch(mesh: Mesh, figures: PackedInt32Array, layer: String) -> void:
	if mesh == null or figures.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = figures.size()
	var instance := MultiMeshInstance3D.new()
	instance.name = "Figures_" + layer + "_%d" % _instances.size()
	instance.multimesh = multimesh
	if layer == "ring":
		instance.material_override = _material(true)
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	_instances.append(instance)
	var buffer := PackedFloat32Array()
	buffer.resize(figures.size() * FLOATS)
	_buffers.append(buffer)
	_figures.append(figures)
	_layers.append(layer)


func set_selection_sides(sides: Array[bool]) -> void:
	_selection_sides = sides.duplicate()


func selection_visible(state: BattleState, company: int) -> bool:
	var side := state.side[company]
	return (
		side < _selection_sides.size() and _selection_sides[side]
		and state.status[company] == BattleState.Status.ACTIVE
		and state.group[company] == state.active_group[side]
	)


func update_view(state: BattleState, previous: PackedVector2Array, alpha: float) -> void:
	_prepare(state)
	_motion_time = maxf(0.0, state.tick - 1 + alpha) * _tick_seconds
	var points := state.fig_pos
	if previous.size() == points.size():
		points = PackedVector2Array()
		points.resize(previous.size())
		for f: int in previous.size():
			points[f] = previous[f].lerp(state.fig_pos[f], alpha)
	for layer: int in _instances.size():
		var buffer := _buffers[layer]
		var figures := _figures[layer]
		for i: int in figures.size():
			_draw_figure(state, layer, figures[i], points[figures[i]], buffer, i)
		if not figures.is_empty():
			_instances[layer].multimesh.buffer = buffer


## Per-company values shared by all its figures, computed once per frame.
func _prepare(state: BattleState) -> void:
	var count := state.company_count()
	_alive.resize(count)
	_basis.resize(count)
	_ring_basis.resize(count)
	_ring_color.resize(count)
	_movement.resize(count)
	for c: int in count:
		_alive[c] = state.alive_figures(c)
		var leader := state.is_leader(c)
		var scale_factor := LEADER_SCALE if leader else 1.0
		_basis[c] = Basis(Vector3.UP, PI / 2 - state.facing[c]).scaled(Vector3.ONE * scale_factor)
		_movement[c] = clampf(state.speed[c] / maxf(state.stats[c].speed, 0.01), 0.0, 1.0)
		var size := CAVALRY_RING_SCALE if state.group[c] == BattleState.Group.CAVALRY else 1.0
		size *= ACTIVE_RING_SCALE
		_ring_color[c] = SELECTION_BLUE
		_ring_basis[c] = Basis().scaled(Vector3(size, 0.3, size))


func _draw_figure(
	state: BattleState, layer: int, f: int, at: Vector2, buffer: PackedFloat32Array, i: int
) -> void:
	var c := state.fig_company[f]
	if f - state.fig_start[c] >= _alive[c]:
		_write(buffer, i, HIDDEN, Vector3.ZERO, Color.TRANSPARENT)
		return
	match _layers[layer]:
		"spear":
			_write_spear(state, buffer, i, c, at)
		"ring":
			var basis := _ring_basis[c] if selection_visible(state, c) else HIDDEN
			_write(buffer, i, basis, Vector3(at.x, 0.045, at.y), _ring_color[c])
		_:
			var contact := 1.0 if state.contact[c] >= 0 else 0.0
			var animation := Color(f * 1.73, _movement[c], contact, _motion_time)
			_write(buffer, i, _basis[c], Vector3(at.x, 0.0, at.y), Color.WHITE, animation)


func _write_spear(
	state: BattleState, buffer: PackedFloat32Array, i: int, c: int, at: Vector2
) -> void:
	var hedgehog := state.formation[c] == 1
	var direction := state.facing[c]
	if hedgehog and at != state.pos[c]:
		direction = (at - state.pos[c]).angle()
	var tilt := HEDGEHOG_SPEAR_TILT if hedgehog else LINE_SPEAR_TILT
	var facing := Basis(Vector3.UP, PI / 2 - direction)
	var basis := facing * Basis(Vector3.RIGHT, tilt)
	var origin := Vector3(at.x, 0.95, at.y) + facing * Vector3(0.39, 0, 0.23) - basis.y * 0.95
	_write(buffer, i, basis, origin, Color.WHITE)


static func _write(
	buffer: PackedFloat32Array, i: int, basis: Basis, origin: Vector3, color: Color,
	animation: Color = Color(0, 0, 0, 0)
) -> void:
	var o := i * FLOATS
	buffer[o] = basis.x.x
	buffer[o + 1] = basis.y.x
	buffer[o + 2] = basis.z.x
	buffer[o + 3] = origin.x
	buffer[o + 4] = basis.x.y
	buffer[o + 5] = basis.y.y
	buffer[o + 6] = basis.z.y
	buffer[o + 7] = origin.y
	buffer[o + 8] = basis.x.z
	buffer[o + 9] = basis.y.z
	buffer[o + 10] = basis.z.z
	buffer[o + 11] = origin.z
	buffer[o + 12] = color.r
	buffer[o + 13] = color.g
	buffer[o + 14] = color.b
	buffer[o + 15] = color.a
	buffer[o + 16] = animation.r
	buffer[o + 17] = animation.g
	buffer[o + 18] = animation.b
	buffer[o + 19] = animation.a


static func _material(unshaded: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = SELECTION_BLUE
		material.emission_energy_multiplier = 0.5
	return material


static func _ring() -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.57
	mesh.outer_radius = 0.63
	mesh.rings = 32
	mesh.ring_segments = 4
	return mesh
