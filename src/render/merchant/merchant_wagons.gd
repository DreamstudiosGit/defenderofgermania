class_name MerchantWagons
extends Node3D
## The train: wagons with spinning wheels, cargo piled by its value and a value tag, two
## draught horses abreast and a driver on the box. A pulled driver tumbles into the verge and
## sits there dazed; horses whose harness was cut trot off to graze; a wagon whose driver is
## gone pulls onto the far verge; wagons at the gate roll in and vanish. Presentation only.

## Wagon-local points (+z towards the horses); the wagon turns so +z runs along the road.
const WHEELS: Array[Vector3] = [
	Vector3(0.86, 0.5, 1.05), Vector3(-0.86, 0.5, 1.05),
	Vector3(0.86, 0.5, -1.15), Vector3(-0.86, 0.5, -1.15),
]
const WHEEL_RADIUS := 0.5
const CARGO_SPOTS: Array[Vector3] = [
	Vector3(-0.35, 1.06, -1.05), Vector3(0.35, 1.06, -1.05), Vector3(-0.35, 1.06, 0.05),
	Vector3(0.35, 1.06, 0.05), Vector3(0.0, 1.55, -0.5),
]
const CARGO_KINDS: Array[String] = [
	"prop_cargo_bale", "prop_barrel_wood", "prop_cargo_crate", "prop_barrel_wood",
	"prop_cargo_bale",
]
const CARGO_SCALE: Dictionary[String, float] = {"prop_barrel_wood": 0.75}
## Bales lie along the bed; the rest turn a little per spot.
const CARGO_TURN: Dictionary[String, float] = {"prop_cargo_bale": PI / 2}
const HORSE_AHEAD := 2.95
const HORSE_SIDE := 0.5
const DRIVER_AT := Vector3(0.0, 0.85, 1.2)
const SWERVE_Z := -1.8
const SWERVE_SECONDS := 1.2
const TUMBLE_SECONDS := 0.7
const VERGE := Vector3(-1.0, 0.0, 3.2)
const GRAZE := Vector3(7.0, 0.0, -3.4)
const GRAZE_SECONDS := 3.5
const DAZED_SECONDS := 6.0
const ROLL_IN_SECONDS := 3.0
const TAG_HEIGHT := 3.3
const TAG_ROLLING := Color(1.0, 0.97, 0.88)
const TAG_STOPPED := Color(1.0, 0.82, 0.25)

## Points above dazed heads this frame, for the stars.
var dazed := PackedVector3Array()

var _cfg: MerchantConfig
var _bodies: MerchantBatch
var _wheels: MerchantBatch
var _horses: MerchantBatch
var _drivers: MerchantBatch
var _cargo: Dictionary[String, MerchantBatch] = {}
## Per cargo model: (wagon, spot) of each piece in its batch.
var _pieces: Dictionary[String, Array] = {}
var _tags: Array[Label3D] = []
var _frames: Array[Transform3D] = []
var _gone := PackedByteArray()
## Raid seconds when each wagon stopped or arrived; -1 while it rolls.
var _since := PackedFloat64Array()


func setup(sim: MerchantSim, neutral: PackedColorArray) -> void:
	_cfg = sim.cfg
	var count := sim.state.wagon_count()
	_bodies = _batch(BattleModels.mesh("prop_wagon_merchant", true), count)
	_wheels = _batch(BattleModels.mesh("prop_wagon_wheel", true), count * WHEELS.size())
	_horses = _batch(BattleModels.mesh("unit_draught_horse", true), count * 2)
	_drivers = _batch(BattleModels.unit_mesh("levy", "neutral"), count, neutral)
	_plan_cargo(sim)
	_since.resize(count)
	_since.fill(-1.0)
	_frames.resize(count)
	_gone.resize(count)
	for w: int in count:
		var tag := Label3D.new()
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.font_size = 72
		tag.outline_size = 18
		tag.pixel_size = 0.008
		tag.no_depth_test = true
		tag.text = tr("MERCHANT_CARGO_VALUE") % sim.state.wagon_value[w]
		add_child(tag)
		_tags.append(tag)


## wagon_x: interpolated positions; time: raid seconds for the motion clocks.
func update_view(sim: MerchantSim, wagon_x: PackedFloat64Array, time: float) -> void:
	var s := sim.state
	dazed.clear()
	for w: int in s.wagon_count():
		var status := s.wagon_status[w]
		if status != MerchantState.Wagon.ROLLING and _since[w] < 0.0:
			_since[w] = time
		var after := time - _since[w] if _since[w] >= 0.0 else 0.0
		var arrived := status == MerchantState.Wagon.ARRIVED
		var x := wagon_x[w] + (_cfg.wagon_speed * after if arrived else 0.0)
		var origin := Vector3(x, 0.0, MerchantStage.road_z(x, s.gate_x))
		var stop := s.wagon_stop[w] if status == MerchantState.Wagon.STOPPED else -1
		if stop == MerchantState.Stop.DRIVER:
			origin.z = lerpf(0.0, SWERVE_Z, clampf(after / SWERVE_SECONDS, 0.0, 1.0))
		_gone[w] = 1 if arrived and after > ROLL_IN_SECONDS else 0
		_frames[w] = Transform3D(Basis(Vector3.UP, PI / 2), origin)
		var moving := status == MerchantState.Wagon.ROLLING or arrived
		_draw_wagon(w, x, moving, time)
		_draw_horses(w, stop == MerchantState.Stop.HARNESS, moving, after, time)
		_draw_driver(w, stop == MerchantState.Stop.DRIVER, after, time)
		var tag := _tags[w]
		tag.visible = not arrived
		tag.position = origin + Vector3(0.0, TAG_HEIGHT, 0.0)
		tag.modulate = TAG_STOPPED if stop >= 0 else TAG_ROLLING
		tag.outline_modulate = Color(0.16, 0.1, 0.05)
	_draw_cargo(time)


func _draw_wagon(w: int, x: float, moving: bool, time: float) -> void:
	if _gone[w]:
		_bodies.hide_instance(w)
		for i: int in WHEELS.size():
			_wheels.hide_instance(w * WHEELS.size() + i)
		return
	var frame := _frames[w]
	_bodies.place(w, frame, 0.4 if moving else 0.0, time)
	var spin := Basis(Vector3.RIGHT, x / WHEEL_RADIUS)
	for i: int in WHEELS.size():
		_wheels.place(w * WHEELS.size() + i, Transform3D(frame.basis * spin, frame * WHEELS[i]))


func _draw_horses(w: int, cut: bool, moving: bool, after: float, time: float) -> void:
	for side: int in 2:
		var i := w * 2 + side
		if _gone[w]:
			_horses.hide_instance(i)
			continue
		var frame := _frames[w]
		var at := frame * Vector3((side * 2 - 1) * HORSE_SIDE, 0.0, HORSE_AHEAD)
		var basis := frame.basis
		var stride := 1.0 if moving else 0.0
		if cut:
			var share := clampf(after / GRAZE_SECONDS, 0.0, 1.0)
			var meadow := at + GRAZE + Vector3(side * 1.6, 0.0, side * 1.2)
			at = at.lerp(meadow, share)
			var yaw := share * (0.3 + 0.5 * (w % 3) + side * 0.8)
			basis = Basis(Vector3.UP, PI / 2 + yaw) * Basis(Vector3.RIGHT, 0.12 * share)
			stride = 1.0 - share
		_horses.place(i, Transform3D(basis, at), stride, time + side * 0.37)


func _draw_driver(w: int, pulled: bool, after: float, time: float) -> void:
	if _gone[w]:
		_drivers.hide_instance(w)
		return
	var frame := _frames[w]
	var seat := frame * DRIVER_AT
	if not pulled:
		_drivers.place(w, Transform3D(frame.basis.scaled(Vector3.ONE * 0.9), seat), 0.0, time)
		return
	var share := clampf(after / TUMBLE_SECONDS, 0.0, 1.0)
	var landing := Vector3(seat.x + VERGE.x, 0.0, VERGE.z)
	var at := seat.lerp(landing, share) + Vector3.UP * sin(share * PI) * 1.2
	var spin := Basis(Vector3.FORWARD, share * TAU * 1.25)
	var sitting := Basis(Vector3.RIGHT, -0.5 * share)
	_drivers.place(w, Transform3D((sitting * spin).scaled(Vector3.ONE * 0.9), at), 0.0, time)
	if share >= 1.0 and after < DAZED_SECONDS:
		dazed.append(at + Vector3(0.0, 1.5, 0.0))


func _draw_cargo(time: float) -> void:
	for kind: String in _pieces:
		var pieces: Array = _pieces[kind]
		var scale_factor: float = CARGO_SCALE.get(kind, 1.0)
		for i: int in pieces.size():
			var piece: Vector2i = pieces[i]
			if _gone[piece.x]:
				_cargo[kind].hide_instance(i)
				continue
			var frame := _frames[piece.x]
			var angle: float = CARGO_TURN.get(kind, piece.y * 0.7)
			var turn := Basis(Vector3.UP, angle).scaled(Vector3.ONE * scale_factor)
			var spot := Transform3D(frame.basis * turn, frame * CARGO_SPOTS[piece.y])
			_cargo[kind].place(i, spot, 0.0, time)


## A piece of cargo per value step, so the dearer wagons carry more.
func _plan_cargo(sim: MerchantSim) -> void:
	var spread := maxi(1, _cfg.cargo_max - _cfg.cargo_min)
	for w: int in sim.state.wagon_count():
		var value := sim.state.wagon_value[w] - _cfg.cargo_min
		var count := mini(2 + roundi(value * 3.0 / spread), CARGO_SPOTS.size())
		var pieces: Array = _pieces.get_or_add(CARGO_KINDS[w % CARGO_KINDS.size()], [])
		for spot: int in count:
			pieces.append(Vector2i(w, spot))
	for kind: String in _pieces:
		_cargo[kind] = _batch(BattleModels.mesh(kind, true), _pieces[kind].size())


func _batch(
	model: Mesh, count: int, colors: PackedColorArray = PackedColorArray()
) -> MerchantBatch:
	var batch := MerchantBatch.new(model, count, colors)
	add_child(batch)
	return batch
