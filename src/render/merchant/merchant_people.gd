class_name MerchantPeople
extends Node3D
## The raiders and the escorts in the side view. The leader rides on the near verge and leans
## in to the box while pulling; escorts raise a shield (blocks), draw the spear back with a "!"
## over their head (the moment to parry), thrust, wobble when parried and lie in the ditch
## with stars when beaten. Companies crouch behind their bushes until the ambush, then storm
## out, brawl with escorts in a dust cloud and pull drivers. Presentation only.

const LEADER_Z := 2.6
const LEADER_PULL_Z := 1.55
const ESCORT_Z := 1.45
const ESCORT_FIGHT_Z := 1.95
const ESCORT_DOWN_Z := 3.1
const COMPANY_Z := 2.3
const HIDE_Z := 5.2
const FIGURE_OFFSETS: Array[Vector2] = [
	Vector2(-0.7, 0.0), Vector2(0.6, 0.45), Vector2(-0.1, 0.95), Vector2(0.9, 1.25),
]
const LUNGE_SECONDS := 0.25
const SHAKE_SECONDS := 0.4
const THRUST_SECONDS := 0.25
const FOLLOW_RATE := 8.0
const WARNING_COLOR := Color(1.0, 0.55, 0.12)
## A raised shield faces the foe but turns towards the camera so the side view shows it.
const SHIELD_TURN := Vector2(0.6, 0.8)

## Points above dazed heads this frame, for the stars.
var dazed := PackedVector3Array()
## Where companies brawl this frame, for the dust.
var brawls := PackedVector3Array()

var _cfg: MerchantConfig
var _leader: MerchantBatch
var _escorts: MerchantBatch
var _spears: MerchantBatch
var _shields: MerchantBatch
var _companies: Array[MerchantBatch] = []
var _warnings: Array[Label3D] = []
var _leader_z := LEADER_Z
var _lunge: float = 0.0
var _shake: float = 0.0
var _company_spears := PackedInt32Array()


func setup(sim: MerchantSim, house_colors: PackedColorArray, neutral: PackedColorArray) -> void:
	_cfg = sim.cfg
	var s := sim.state
	var house := sim.setup.house
	_leader = _batch(BattleModels.unit_mesh("leader", house), 1, house_colors)
	_escorts = _batch(BattleModels.unit_mesh("spearmen", "neutral"), s.escort_count(), neutral)
	_company_spears.clear()
	for c: int in s.company_count():
		var unit := s.company_unit[c]
		var model := BattleModels.unit_mesh(unit, house)
		_companies.append(_batch(model, _cfg.company_figures, house_colors))
		if unit == "spearmen":
			_company_spears.append(c)
	var spear_count := s.escort_count() + _company_spears.size() * _cfg.company_figures
	_spears = _batch(BattleModels.mesh("weapon_spear"), spear_count)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.42
	disc.bottom_radius = 0.42
	disc.height = 0.07
	disc.radial_segments = 16
	var paint := StandardMaterial3D.new()
	paint.albedo_color = neutral[0].darkened(0.15) if neutral.size() > 0 else Color.BURLYWOOD
	paint.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	disc.material = paint
	_shields = _batch(disc, s.escort_count())
	for e: int in s.escort_count():
		var warning := Label3D.new()
		warning.text = "!"
		warning.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		warning.font_size = 120
		warning.outline_size = 24
		warning.pixel_size = 0.008
		warning.modulate = WARNING_COLOR
		warning.no_depth_test = true
		warning.visible = false
		add_child(warning)
		_warnings.append(warning)


func lunge() -> void:
	_lunge = LUNGE_SECONDS


func shake() -> void:
	_shake = SHAKE_SECONDS


func leader_point() -> Vector3:
	return _leader.multimesh.get_instance_transform(0).origin


func update_view(
	sim: MerchantSim, leader_x: float, escort_x: PackedFloat64Array,
	company_x: PackedFloat64Array, time: float, delta: float
) -> void:
	dazed.clear()
	brawls.clear()
	_lunge = maxf(0.0, _lunge - delta)
	_shake = maxf(0.0, _shake - delta)
	_draw_leader(sim, leader_x, time, delta)
	for e: int in sim.state.escort_count():
		_draw_escort(sim, e, escort_x[e], time)
	var spear := sim.state.escort_count()
	for c: int in sim.state.company_count():
		spear = _draw_company(sim, c, company_x[c], time, spear)


func _draw_leader(sim: MerchantSim, x: float, time: float, delta: float) -> void:
	var s := sim.state
	var goal := LEADER_PULL_Z if s.pull_wagon >= 0 else LEADER_Z
	_leader_z = lerpf(_leader_z, goal, 1.0 - exp(-FOLLOW_RATE * delta))
	var facing := float(s.leader_facing)
	var at := Vector3(x, 0.0, _leader_z)
	at.x += facing * 0.6 * sin(PI * _lunge / LUNGE_SECONDS)
	at.z += sin(_shake * 60.0) * 0.12
	var basis := MerchantBatch.upright(Vector3.ZERO, facing).basis
	if s.captured:
		basis = Basis(Vector3.RIGHT, 1.25) * basis
		at.y = 0.2
	elif s.pull_wagon >= 0:
		basis = Basis(Vector3.RIGHT, -0.18) * basis
	var movement := clampf(absf(s.leader_velocity) / _cfg.leader_speed, 0.0, 1.0)
	_leader.place(0, Transform3D(basis, at), movement, time)
	if s.stun > 0.0 or s.captured:
		dazed.append(at + Vector3(0.0, 3.9, 0.0))


func _draw_escort(sim: MerchantSim, e: int, x: float, time: float) -> void:
	var s := sim.state
	var state := s.escort_state[e]
	var goal := MerchantEscorts.target_x(s, e)
	var engaged := state >= MerchantState.Escort.APPROACH and state <= MerchantState.Escort.STAGGERED
	var facing := signf(goal - x) if engaged else 1.0
	facing = 1.0 if facing == 0.0 else facing
	var z := ESCORT_FIGHT_Z if engaged else ESCORT_Z
	var lean := 0.0
	var tilt := 0.25
	var reach := 0.0
	var walking := 1.0 if state <= MerchantState.Escort.APPROACH else 0.0
	match state:
		MerchantState.Escort.COVER:
			tilt = 1.1
		MerchantState.Escort.WINDUP:
			lean = -0.2
			tilt = -0.55
			reach = -0.3
		MerchantState.Escort.RECOVER:
			var thrust := s.escort_timer[e] > sim.escort.recover_seconds - THRUST_SECONDS
			tilt = 1.45 if thrust else 0.9
			reach = 0.5 if thrust else 0.0
			lean = 0.12 if thrust else 0.0
		MerchantState.Escort.STAGGERED:
			lean = sin(time * 18.0 + e) * 0.25
			tilt = -0.15
		MerchantState.Escort.BOUND:
			z = COMPANY_Z
			x += sin(time * 13.0 + e * 2.0) * 0.25
			tilt = 1.2
	var yaw := MerchantBatch.upright(Vector3.ZERO, facing).basis
	var at := Vector3(x, 0.0, z)
	var basis := Basis(Vector3.BACK, -lean * facing) * yaw
	if state == MerchantState.Escort.DOWN:
		at = Vector3(x, 0.25, ESCORT_DOWN_Z)
		basis = Basis(Vector3.RIGHT, PI / 2) * yaw
		dazed.append(at + Vector3(0.0, 0.6, 0.0))
		tilt = PI / 2
	_escorts.place(e, Transform3D(basis, at), walking, time + e * 0.5)
	_place_spear(e, at, facing, tilt, reach, state == MerchantState.Escort.DOWN)
	var shielded := MerchantEscorts.guarded(s, e)
	if shielded:
		var shield_at := at + Vector3(facing * 0.5, 1.2, 0.3)
		var face := Vector3(facing * SHIELD_TURN.x, 0.0, SHIELD_TURN.y)
		_shields.place(e, Transform3D(Basis(Quaternion(Vector3.UP, face)), shield_at))
	else:
		_shields.hide_instance(e)
	var warning := _warnings[e]
	warning.visible = state == MerchantState.Escort.WINDUP
	if warning.visible:
		var closing := 1.0 - s.escort_timer[e] / maxf(sim.escort.windup_seconds, 0.01)
		warning.position = at + Vector3(0.0, 3.0, 0.0)
		warning.scale = Vector3.ONE * (0.8 + closing * 0.8)


## Returns the next free spear slot.
func _draw_company(sim: MerchantSim, c: int, x: float, time: float, spear: int) -> int:
	var s := sim.state
	var state := s.company_state[c]
	var batch := _companies[c]
	var armed := c in _company_spears
	for f: int in _cfg.company_figures:
		var offset := FIGURE_OFFSETS[f % FIGURE_OFFSETS.size()]
		var facing := 1.0 if f % 2 == 0 or state != MerchantState.Company.FIGHTING else -1.0
		var at := Vector3(x + offset.x, 0.0, COMPANY_Z + offset.y * 0.6)
		var scale_y := 1.0
		var movement := 1.0 if state == MerchantState.Company.RUNNING else 0.0
		match state:
			MerchantState.Company.HIDDEN:
				at.z = HIDE_Z + offset.y * 0.4
				scale_y = 0.6
				facing = -1.0
			MerchantState.Company.FIGHTING, MerchantState.Company.PULLING:
				at.x += sin(time * 11.0 + f * 1.7) * 0.3
				movement = 0.5
			MerchantState.Company.IDLE:
				at.y = absf(sin(time * 7.0 + f)) * 0.35
		var basis := MerchantBatch.upright(Vector3.ZERO, facing).basis.scaled(
			Vector3(1.0, scale_y, 1.0)
		)
		batch.place(f, Transform3D(basis, at), movement, time + f * 0.3)
		if armed:
			var fighting := state == MerchantState.Company.FIGHTING
			_place_spear(spear, at, facing, 1.2 if fighting else 0.35, 0.0, false, scale_y)
			spear += 1
	if state == MerchantState.Company.FIGHTING:
		brawls.append(Vector3(x, 0.6, COMPANY_Z + 0.3))
	return spear


## The spear in the right hand as in the battle (BattleFigures): tilt 0 upright, PI/2 level.
func _place_spear(
	i: int, at: Vector3, facing: float, tilt: float, reach: float, lying: bool,
	scale_y: float = 1.0
) -> void:
	var yaw := MerchantBatch.upright(Vector3.ZERO, facing).basis
	var basis := yaw * Basis(Vector3.RIGHT, tilt)
	var hand := Vector3(at.x, 0.95 * scale_y + at.y, at.z) + yaw * Vector3(0.39, 0.0, 0.23)
	var origin := hand - basis.y * 0.95 + yaw.z * reach
	if lying:
		origin = at + yaw * Vector3(0.6, -0.15, 0.0)
	_spears.place(i, Transform3D(basis, origin))


func _batch(
	model: Mesh, count: int, colors: PackedColorArray = PackedColorArray()
) -> MerchantBatch:
	var batch := MerchantBatch.new(model, count, colors)
	add_child(batch)
	return batch
