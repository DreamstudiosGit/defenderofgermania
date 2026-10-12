class_name MerchantEffects
extends Node3D
## Comic effects of the raid, never blood: dust puffs (the battle's), crossbow bolts in flight,
## stars circling dazed heads and short sound words popping up where things happen.

const STARS_PER_HEAD := 3
const STAR_CAPACITY := 36
const STAR_RADIUS := 0.45
const STAR_RATE := 4.0
const BOLT_SECONDS := 0.35
const BOLT_ARC := 0.8
const POPUP_SECONDS := 1.1
const POPUP_RISE := 1.4
const POPUP_CAPACITY := 8

var _dust := BattleDust.new()
## BattleDust advances its puffs in update_view; an empty battle state adds no trails.
var _no_battle := BattleState.new()
var _stars: MerchantBatch
var _bolts: Array[MeshInstance3D] = []
var _bolt_from: Array[Vector3] = []
var _bolt_to: Array[Vector3] = []
var _bolt_age := PackedFloat64Array()
var _popups: Array[Label3D] = []
var _popup_age := PackedFloat64Array()
var _next_popup: int = 0


func _ready() -> void:
	add_child(_dust)
	var star := PrismMesh.new()
	star.size = Vector3(0.22, 0.22, 0.06)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.85, 0.25)
	gold.emission_enabled = true
	gold.emission = Color(0.6, 0.45, 0.05)
	gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star.material = gold
	_stars = MerchantBatch.new(star, STAR_CAPACITY)
	add_child(_stars)
	for i: int in POPUP_CAPACITY:
		var popup := Label3D.new()
		popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		popup.font_size = 96
		popup.outline_size = 22
		popup.pixel_size = 0.009
		popup.no_depth_test = true
		popup.visible = false
		add_child(popup)
		_popups.append(popup)
		_popup_age.append(POPUP_SECONDS)


func clear() -> void:
	_dust.clear()
	for bolt: MeshInstance3D in _bolts:
		bolt.queue_free()
	_bolts.clear()
	_bolt_from.clear()
	_bolt_to.clear()
	_bolt_age.clear()
	for i: int in POPUP_CAPACITY:
		_popup_age[i] = POPUP_SECONDS
		_popups[i].visible = false


func dust(at: Vector3, count: int, spread: float) -> void:
	_dust.burst(Vector2(at.x, at.z), count, spread)


## Popups close to one still rising stack upwards instead of overlapping.
func popup(text: String, at: Vector3, color: Color) -> void:
	for i: int in POPUP_CAPACITY:
		var near := _popups[i].position - at
		if _popup_age[i] < POPUP_SECONDS * 0.6 and absf(near.x) < 2.5 and near.y > -0.4:
			at.y = maxf(at.y, _popups[i].position.y + 0.9)
	var label := _popups[_next_popup]
	label.text = text
	label.modulate = color
	label.outline_modulate = color.darkened(0.75)
	label.position = at
	label.visible = true
	_popup_age[_next_popup] = 0.0
	_next_popup = (_next_popup + 1) % POPUP_CAPACITY


func bolt(from: Vector3, to: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.03
	mesh.bottom_radius = 0.03
	mesh.height = 0.7
	mesh.radial_segments = 6
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.3, 0.15)
	mesh.material = wood
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	add_child(instance)
	_bolts.append(instance)
	_bolt_from.append(from)
	_bolt_to.append(to)
	_bolt_age.append(0.0)


func update_view(dazed: PackedVector3Array, time: float, delta: float) -> void:
	_dust.update_view(_no_battle, PackedVector2Array(), delta)
	var slot := 0
	for head: Vector3 in dazed:
		for k: int in STARS_PER_HEAD:
			if slot >= STAR_CAPACITY:
				break
			var angle := time * STAR_RATE + k * TAU / STARS_PER_HEAD
			var at := head + Vector3(cos(angle) * STAR_RADIUS, 0.1 * sin(angle * 2.0), sin(angle) * 0.25)
			_stars.place(slot, Transform3D(Basis(Vector3.BACK, angle * 2.0), at))
			slot += 1
	for i: int in range(slot, STAR_CAPACITY):
		_stars.hide_instance(i)
	_advance_bolts(delta)
	for i: int in POPUP_CAPACITY:
		if _popup_age[i] >= POPUP_SECONDS:
			continue
		_popup_age[i] += delta
		var share := _popup_age[i] / POPUP_SECONDS
		_popups[i].position.y += POPUP_RISE * delta
		_popups[i].scale = Vector3.ONE * (1.0 + 0.4 * maxf(0.0, 1.0 - share * 6.0))
		_popups[i].modulate.a = clampf((1.0 - share) * 3.0, 0.0, 1.0)
		_popups[i].visible = share < 1.0


func _advance_bolts(delta: float) -> void:
	for i: int in range(_bolts.size() - 1, -1, -1):
		_bolt_age[i] += delta
		var share := clampf(_bolt_age[i] / BOLT_SECONDS, 0.0, 1.0)
		var at := _bolt_from[i].lerp(_bolt_to[i], share) + Vector3.UP * sin(share * PI) * BOLT_ARC
		var ahead := _bolt_to[i] - _bolt_from[i]
		var direction := ahead.normalized() if ahead.length() > 0.01 else Vector3.RIGHT
		var basis := Basis(Quaternion(Vector3.UP, direction))
		_bolts[i].transform = Transform3D(basis, at)
		if _bolt_age[i] > BOLT_SECONDS + 1.5:
			_bolts[i].queue_free()
			_bolts.remove_at(i)
			_bolt_from.remove_at(i)
			_bolt_to.remove_at(i)
			_bolt_age.remove_at(i)
