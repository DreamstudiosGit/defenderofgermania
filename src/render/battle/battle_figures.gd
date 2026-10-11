class_name BattleFigures
extends Node3D
## Draws all figures with one MultiMesh per layer (foot soldiers, horses, riders, spears, house
## rings), writing whole instance buffers once per frame and interpolating between ticks.

enum Layer { FOOT, HORSE, RIDER, SPEAR, RING }

## 12 transform floats (3x4, row-major) + 4 color floats per instance.
const FLOATS := 16
const HORSE_COLOR := Color(0.36, 0.24, 0.14)
const LEADER_HORSE_COLOR := Color(0.88, 0.86, 0.80)
const SPEAR_COLOR := Color(0.55, 0.42, 0.22)
const FLEEING_RING := Color(0.95, 0.95, 0.95)
const UNIT_TINT := {
	"levy": Color(0.62, 0.52, 0.40),
	"spearmen": Color(0.72, 0.72, 0.72),
	"crossbowmen": Color(0.50, 0.36, 0.22),
	"brabanters": Color(0.40, 0.40, 0.46),
	"knights": Color(0.85, 0.86, 0.90),
}
const TINT_WEIGHT := 0.2
const LINE_SPEAR_TILT := 0.35
const HEDGEHOG_SPEAR_TILT := 1.0
const SPEAR_LENGTH := 3.2
const CAVALRY_RING_SCALE := 1.7
const LEADER_SCALE := 1.2
const ACTIVE_RING_SCALE := 1.15
const HIDDEN := Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)

var _instances: Array[MultiMeshInstance3D] = []
var _buffers: Array[PackedFloat32Array] = []
## Per layer, the figure index drawn by each instance.
var _figures: Array[PackedInt32Array] = []
var _armies: Array[BattleRules.ArmyPreset] = []
var _alive := PackedInt32Array()
var _basis: Array[Basis] = []
var _ring_basis: Array[Basis] = []
var _rider_height := PackedFloat32Array()
var _foot_color := PackedColorArray()
var _horse_color := PackedColorArray()
var _rider_color := PackedColorArray()
var _ring_color := PackedColorArray()


func _init() -> void:
	var meshes: Array[Mesh] = [_capsule(0.32, 1.7), _box(), _capsule(0.28, 1.1), _spear(), _ring()]
	for layer: int in Layer.size():
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = meshes[layer]
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.material_override = _material(layer == Layer.RING)
		if layer == Layer.RING or layer == Layer.SPEAR:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
		_instances.append(instance)
		_buffers.append(PackedFloat32Array())
		_figures.append(PackedInt32Array())


func setup(state: BattleState, armies: Array[BattleRules.ArmyPreset]) -> void:
	_armies = armies
	for layer: int in Layer.size():
		_figures[layer] = PackedInt32Array()
	for f: int in state.fig_pos.size():
		var c := state.fig_company[f]
		_figures[Layer.RING].append(f)
		if state.group[c] == BattleState.Group.CAVALRY:
			_figures[Layer.HORSE].append(f)
			_figures[Layer.RIDER].append(f)
		else:
			_figures[Layer.FOOT].append(f)
			if state.unit_ids[c] == "spearmen":
				_figures[Layer.SPEAR].append(f)
	for layer: int in Layer.size():
		var count := _figures[layer].size()
		_instances[layer].multimesh.instance_count = count
		_buffers[layer].resize(count * FLOATS)


func update_view(state: BattleState, previous: PackedVector2Array, alpha: float) -> void:
	_prepare(state)
	var points := state.fig_pos
	if previous.size() == points.size():
		points = PackedVector2Array()
		points.resize(previous.size())
		for f: int in previous.size():
			points[f] = previous[f].lerp(state.fig_pos[f], alpha)
	for layer: int in Layer.size():
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
	_rider_height.resize(count)
	for colors: PackedColorArray in [_foot_color, _horse_color, _rider_color, _ring_color]:
		colors.resize(count)
	for c: int in count:
		_alive[c] = state.alive_figures(c)
		var leader := state.is_leader(c)
		var scale_factor := LEADER_SCALE if leader else 1.0
		_basis[c] = Basis(Vector3.UP, PI / 2 - state.facing[c]).scaled(Vector3.ONE * scale_factor)
		_rider_height[c] = 1.95 * scale_factor
		var army := _armies[state.side[c]]
		var tint: Color = UNIT_TINT.get(state.unit_ids[c], Color.GRAY)
		_foot_color[c] = army.color.lerp(tint, TINT_WEIGHT)
		_horse_color[c] = LEADER_HORSE_COLOR if leader else HORSE_COLOR
		_rider_color[c] = army.accent if leader else army.color
		var ring := army.color
		var size := CAVALRY_RING_SCALE if state.group[c] == BattleState.Group.CAVALRY else 1.0
		if state.status[c] == BattleState.Status.FLEEING:
			ring = FLEEING_RING
		elif state.group[c] == state.active_group[state.side[c]]:
			ring = ring.lerp(army.accent, 0.45)
			size *= ACTIVE_RING_SCALE
		_ring_color[c] = army.accent if leader else ring
		_ring_basis[c] = Basis().scaled(Vector3(size, 0.3, size))


func _draw_figure(
	state: BattleState, layer: int, f: int, at: Vector2, buffer: PackedFloat32Array, i: int
) -> void:
	var c := state.fig_company[f]
	if f - state.fig_start[c] >= _alive[c]:
		_write(buffer, i, HIDDEN, Vector3.ZERO, Color.TRANSPARENT)
		return
	match layer:
		Layer.FOOT:
			_write(buffer, i, _basis[c], Vector3(at.x, 0.85, at.y), _foot_color[c])
		Layer.HORSE:
			_write(buffer, i, _basis[c], Vector3(at.x, 0.7, at.y), _horse_color[c])
		Layer.RIDER:
			_write(buffer, i, _basis[c], Vector3(at.x, _rider_height[c], at.y), _rider_color[c])
		Layer.SPEAR:
			_write_spear(state, buffer, i, c, at)
		Layer.RING:
			_write(buffer, i, _ring_basis[c], Vector3(at.x, 0.06, at.y), _ring_color[c])


func _write_spear(
	state: BattleState, buffer: PackedFloat32Array, i: int, c: int, at: Vector2
) -> void:
	var hedgehog := state.formation[c] == 1
	var direction := state.facing[c]
	if hedgehog and at != state.pos[c]:
		direction = (at - state.pos[c]).angle()
	var tilt := HEDGEHOG_SPEAR_TILT if hedgehog else LINE_SPEAR_TILT
	var basis := Basis(Vector3.UP, PI / 2 - direction) * Basis(Vector3.RIGHT, tilt)
	var origin := Vector3(at.x, 0.9, at.y) + basis.y * (SPEAR_LENGTH * 0.4)
	_write(buffer, i, basis, origin, SPEAR_COLOR)


static func _write(
	buffer: PackedFloat32Array, i: int, basis: Basis, origin: Vector3, color: Color
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


static func _material(unshaded: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


static func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 2
	return mesh


static func _box() -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.7, 1.4, 1.9)
	return mesh


static func _spear() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.03
	mesh.bottom_radius = 0.04
	mesh.height = SPEAR_LENGTH
	mesh.radial_segments = 4
	mesh.rings = 1
	return mesh


static func _ring() -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.5
	mesh.outer_radius = 0.68
	mesh.rings = 16
	mesh.ring_segments = 4
	return mesh
