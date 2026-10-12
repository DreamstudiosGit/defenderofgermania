class_name BattleDust
extends MultiMeshInstance3D
## Dust clouds of the battle: soft billboard puffs that rise, swell and fade. Charging riders
## trail dust, charge impacts and trebuchet stones throw up bursts. Presentation only.

const CAPACITY := 512
const LIFE := 1.6
const RISE := 0.8
const START_SIZE := 1.4
const END_SIZE := 4.0
const COLOR := Color(0.72, 0.62, 0.45, 0.55)
const TRAIL_SPEED := 4.0
const TRAIL_INTERVAL := 0.12
const HIDDEN := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)

var _rng := RandomNumberGenerator.new()
var _position := PackedVector3Array()
var _drift := PackedVector3Array()
var _age := PackedFloat64Array()
var _next := 0
var _trail_clock: float = 0.0


func _ready() -> void:
	_rng.seed = 1198
	_position.resize(CAPACITY)
	_drift.resize(CAPACITY)
	_age.resize(CAPACITY)
	_age.fill(LIFE)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.albedo_texture = _puff_texture()
	quad.material = material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = CAPACITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	clear()


func clear() -> void:
	_age.fill(LIFE)
	_trail_clock = 0.0
	for i: int in CAPACITY:
		multimesh.set_instance_transform(i, HIDDEN)


## Puffs still in the air.
func active() -> int:
	var count := 0
	for age: float in _age:
		if age < LIFE:
			count += 1
	return count


## count puffs scattered up to spread metres around a ground point.
func burst(at: Vector2, count: int, spread: float) -> void:
	for i: int in count:
		var offset := Vector2.from_angle(_rng.randf() * TAU) * spread * sqrt(_rng.randf())
		var drift := Vector3(offset.x, 0.0, offset.y).normalized() * _rng.randf_range(0.5, 1.5)
		_spawn(Vector3(at.x + offset.x, 0.3, at.y + offset.y), drift)


## Trails behind fast companies (charging riders) and advances the puffs.
func update_view(state: BattleState, positions: PackedVector2Array, delta: float) -> void:
	_trail_clock -= delta
	if _trail_clock <= 0.0 and state.phase == BattleState.Phase.FIGHT:
		_trail_clock = TRAIL_INTERVAL
		for c: int in mini(state.company_count(), positions.size()):
			if state.is_present(c) and state.speed[c] >= TRAIL_SPEED:
				var behind := positions[c] - state.facing_vector(c) * state.radius[c]
				burst(behind, 1, state.radius[c] * 0.6)
	for i: int in CAPACITY:
		if _age[i] >= LIFE:
			continue
		_age[i] += delta
		var t := minf(_age[i] / LIFE, 1.0)
		_position[i] += (_drift[i] + Vector3.UP * RISE) * delta
		var size := lerpf(START_SIZE, END_SIZE, t) if t < 1.0 else 0.0
		var basis := Basis().scaled(Vector3.ONE * size)
		multimesh.set_instance_transform(i, Transform3D(basis, _position[i]))
		var color := COLOR
		color.a *= 1.0 - t
		multimesh.set_instance_color(i, color)


func _spawn(at: Vector3, drift: Vector3) -> void:
	_position[_next] = at
	_drift[_next] = drift
	_age[_next] = 0.0
	_next = (_next + 1) % CAPACITY


static func _puff_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture
