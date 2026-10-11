class_name BattleContacts
extends RefCounted
## Moves figures towards their formation slots, keeps figures of different companies apart
## and finds melee contacts between enemy companies through a bucket grid of figures.

## At least two horse radii plus the melee reach, so neighbours are always in adjacent cells.
const CELL_SIZE := 3.0
const ORDER_TARGET_BONUS := 1000000.0

var _grid: BattleGrid
var _include := PackedByteArray()
var _figure_radius := PackedFloat64Array()
var _best := PackedFloat64Array()


func _init(rules: BattleRules) -> void:
	_grid = BattleGrid.new(rules.field_size, CELL_SIZE)


func update(state: BattleState, rules: BattleRules, dt: float) -> void:
	_follow_slots(state, rules, dt)
	_collide(state, rules)


func _follow_slots(state: BattleState, rules: BattleRules, dt: float) -> void:
	var figures := state.fig_pos.size()
	_include.resize(figures)
	_include.fill(0)
	_figure_radius.resize(figures)
	for c: int in state.company_count():
		var alive := state.alive_figures(c)
		if alive == 0:
			continue
		var slots := BattleDeployment.company_slots(state, rules, c)
		var body := BattleDeployment.figure_radius(state, rules, c)
		var center := state.pos[c]
		var angle := state.facing[c]
		var step := (maxf(state.speed[c], state.stats[c].speed) * rules.catch_up_factor + 1.0) * dt
		for k: int in alive:
			var f := state.fig_start[c] + k
			var target := center + (slots[k] + state.fig_jitter[f]).rotated(angle)
			state.fig_pos[f] = state.fig_pos[f].move_toward(target, step)
			_include[f] = 1
			_figure_radius[f] = body


func _collide(state: BattleState, rules: BattleRules) -> void:
	var count := state.company_count()
	_best.resize(count)
	_best.fill(INF)
	state.contact.fill(-1)
	_grid.rebuild(state.fig_pos, _include)
	var cols := _grid.cols
	var starts := _grid.cell_start
	var items := _grid.items
	var positions := state.fig_pos
	var owners := state.fig_company
	for f: int in positions.size():
		if _include[f] == 0:
			continue
		var c := owners[f]
		var cx := _grid.cell_x(positions[f].x)
		var cy := _grid.cell_y(positions[f].y)
		for gy: int in range(maxi(cy - 1, 0), mini(cy + 2, _grid.rows)):
			for gx: int in range(maxi(cx - 1, 0), mini(cx + 2, cols)):
				var cell := gy * cols + gx
				for k: int in range(starts[cell], starts[cell + 1]):
					var g := items[k]
					var o := owners[g]
					if g <= f or o == c:
						continue
					var offset := positions[g] - positions[f]
					var touching := _figure_radius[f] + _figure_radius[g]
					var dist := offset.length()
					if dist >= touching + rules.melee_reach:
						continue
					if state.side[o] != state.side[c]:
						_touch(state, c, o)
						_touch(state, o, c)
					if dist < touching:
						var away := Vector2.DOWN if dist <= 0.0 else offset / dist
						var push := away * (touching - dist) * 0.5
						positions[f] -= push
						positions[g] += push
	_keep_on_field(state, rules)


## Records that company a reaches enemy b; a prefers its ordered target, then the nearest.
func _touch(state: BattleState, a: int, b: int) -> void:
	if state.status[a] != BattleState.Status.ACTIVE:
		return
	var score := state.pos[a].distance_squared_to(state.pos[b])
	if state.order_target[a] == b:
		score -= ORDER_TARGET_BONUS
	if score < _best[a]:
		_best[a] = score
		state.contact[a] = b


func _keep_on_field(state: BattleState, rules: BattleRules) -> void:
	for f: int in state.fig_pos.size():
		if _include[f] == 0:
			continue
		var at := state.fig_pos[f]
		for obstacle: Vector3 in rules.obstacles:
			var center := Vector2(obstacle.x, obstacle.y)
			var keep := obstacle.z + _figure_radius[f]
			var dist := at.distance_to(center)
			if dist < keep:
				at = center + (Vector2.RIGHT if dist <= 0.0 else center.direction_to(at)) * keep
		state.fig_pos[f] = at.clamp(Vector2.ZERO, rules.field_size)
