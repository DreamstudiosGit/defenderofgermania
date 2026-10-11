class_name BattleMarkers
extends MeshInstance3D
## Ground lines for the human players' active group: facing arrows, move targets, charge
## lines and the archers' aim cone with its range.

const HEIGHT := 0.15
const ARROW := 9.0
const ARROW_HEAD := 2.5
const CROSS := 1.5
const CONE_STEPS := 8

var _lines := ImmediateMesh.new()


func _ready() -> void:
	mesh = _lines
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.no_depth_test = true
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## humans[s] is true for human-controlled sides; colors are per side.
func update_view(
	state: BattleState,
	rules: BattleRules,
	positions: PackedVector2Array,
	humans: Array[bool],
	colors: Array[Color]
) -> void:
	_lines.clear_surfaces()
	if state.phase == BattleState.Phase.OVER or not (humans[0] or humans[1]):
		return
	_lines.surface_begin(Mesh.PRIMITIVE_LINES)
	var drawn := 0
	for c: int in state.company_count():
		var s := state.side[c]
		if not humans[s] or state.status[c] != BattleState.Status.ACTIVE:
			continue
		if state.group[c] != state.active_group[s] or c >= positions.size():
			continue
		_lines.surface_set_color(colors[s])
		_draw_company(state, rules, c, positions[c])
		drawn += 1
	if drawn == 0:
		_line(Vector2.ZERO, Vector2.ZERO)
	_lines.surface_end()


func _draw_company(state: BattleState, rules: BattleRules, c: int, at: Vector2) -> void:
	var facing := state.facing_vector(c)
	var tip := at + facing * (state.radius[c] + ARROW)
	_line(at + facing * state.radius[c], tip)
	_line(tip, tip - facing.rotated(0.5) * ARROW_HEAD)
	_line(tip, tip - facing.rotated(-0.5) * ARROW_HEAD)
	match state.order[c]:
		BattleState.Order.MOVE:
			var target := state.order_point[c]
			_line(at, target)
			_line(target - Vector2(CROSS, CROSS), target + Vector2(CROSS, CROSS))
			_line(target - Vector2(CROSS, -CROSS), target + Vector2(CROSS, -CROSS))
		BattleState.Order.CHARGE, BattleState.Order.FIRE:
			var target := state.order_target[c]
			if BattleTargeting.is_valid_target(state, c, target):
				_line(at, state.pos[target])
		BattleState.Order.CAV_CHARGE:
			var left := rules.charge_max_distance - state.charge_run[c]
			_line(at, at + state.order_point[c] * maxf(0.0, left))
	var reach := state.stats[c].attack_range
	if reach > 0.0:
		var angle := state.facing[c]
		var previous := at + Vector2.from_angle(angle - rules.aim_cone) * reach
		_line(at, previous)
		for i: int in range(1, CONE_STEPS + 1):
			var a := angle - rules.aim_cone + rules.aim_cone * 2.0 * i / CONE_STEPS
			var point := at + Vector2.from_angle(a) * reach
			_line(previous, point)
			previous = point
		_line(at, previous)


func _line(from: Vector2, to: Vector2) -> void:
	_lines.surface_add_vertex(Vector3(from.x, HEIGHT, from.y))
	_lines.surface_add_vertex(Vector3(to.x, HEIGHT, to.y))
