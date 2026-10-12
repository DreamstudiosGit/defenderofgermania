class_name JoustCrowd
extends Node3D
## Spectators on the stand's tiers and standing behind the near fence, in everyday colours and
## the riders' colours; they jump up when a lance lands. Presentation only.

const PER_TIER := 34
const STANDING_ROWS := 2
const PER_ROW := 44
const SKIN := Color(0.88, 0.64, 0.49)
const CLOTHES: Array[Color] = [
	Color(0.55, 0.16, 0.13), Color(0.18, 0.3, 0.55), Color(0.2, 0.42, 0.22),
	Color(0.75, 0.6, 0.2), Color(0.45, 0.4, 0.34), Color(0.85, 0.79, 0.64),
	Color(0.35, 0.2, 0.4), Color(0.6, 0.35, 0.2),
]
const CHEER_SECONDS := 2.2
const CHEER_HOP := 0.28

var _bodies := MultiMeshInstance3D.new()
var _heads := MultiMeshInstance3D.new()
var _rest: Array[Transform3D] = []
var _cheer_left: float = 0.0
var _time: float = 0.0


func build(colors: Array[PackedColorArray]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1198
	_rest.clear()
	var tint := PackedColorArray()
	var palette: Array[Color] = CLOTHES.duplicate()
	for owner: PackedColorArray in colors:
		palette.append_array([owner[0], owner[0]])
	var stand_width := JoustLists.STAND_HALF * 2.0 - 1.2
	for tier: int in JoustLists.TIERS:
		var z := JoustLists.STAND_FRONT - JoustLists.TIER_DEPTH * (tier + 0.5)
		for i: int in PER_TIER:
			var x := -JoustLists.STAND_HALF + 0.6 + stand_width * (i + rng.randf_range(0.1, 0.9)) / PER_TIER
			var at := Vector3(x, 0.55 * (tier + 1), z + rng.randf_range(-0.2, 0.2))
			_spectator(at, rng, palette, tint, PI)
	var row_width := JoustLists.HALF_LENGTH * 2.0 - 4.0
	for row: int in STANDING_ROWS:
		for i: int in PER_ROW:
			var x := -JoustLists.HALF_LENGTH + 2.0 + row_width * (i + rng.randf_range(0.1, 0.9)) / PER_ROW
			var z := JoustLists.HALF_WIDTH + 1.6 + row * 0.9 + rng.randf_range(-0.2, 0.2)
			_spectator(Vector3(x, 0.0, z), rng, palette, tint, 0.0)
	_bodies.multimesh = _batch(_body_mesh(), tint)
	_heads.multimesh = _batch(_head_mesh(), PackedColorArray())
	add_child(_bodies)
	add_child(_heads)


func cheer() -> void:
	_cheer_left = CHEER_SECONDS


func _process(delta: float) -> void:
	_time += delta
	if _cheer_left <= 0.0 or _rest.is_empty():
		return
	_cheer_left -= delta
	var strength := clampf(_cheer_left / CHEER_SECONDS * 2.0, 0.0, 1.0)
	for i: int in _rest.size():
		var hop := absf(sin(_time * 9.0 + i * 1.37)) * CHEER_HOP * strength
		var at := _rest[i].translated(Vector3.UP * hop)
		_bodies.multimesh.set_instance_transform(i, at)
		_heads.multimesh.set_instance_transform(i, at)


func _spectator(
	at: Vector3, rng: RandomNumberGenerator, palette: Array[Color], tint: PackedColorArray,
	facing: float
) -> void:
	var size := rng.randf_range(0.85, 1.1)
	var basis := Basis(Vector3.UP, facing + rng.randf_range(-0.4, 0.4)).scaled(Vector3.ONE * size)
	_rest.append(Transform3D(basis, at))
	tint.append(palette[rng.randi_range(0, palette.size() - 1)])


func _batch(mesh: Mesh, tint: PackedColorArray) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = not tint.is_empty()
	multimesh.mesh = mesh
	multimesh.instance_count = _rest.size()
	for i: int in _rest.size():
		multimesh.set_instance_transform(i, _rest[i])
		if not tint.is_empty():
			multimesh.set_instance_color(i, tint[i])
	return multimesh


static func _body_mesh() -> Mesh:
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.24
	capsule.height = 1.15
	capsule.radial_segments = 8
	capsule.rings = 2
	return _lifted(capsule, 0.58, JoustLists.material(Color.WHITE, true))


static func _head_mesh() -> Mesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.17
	sphere.height = 0.34
	sphere.radial_segments = 8
	sphere.rings = 4
	return _lifted(sphere, 1.3, JoustLists.material(SKIN, false))


static func _lifted(source: PrimitiveMesh, height: float, material: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.append_from(source, 0, Transform3D(Basis(), Vector3(0, height, 0)))
	st.commit(mesh)
	mesh.surface_set_material(0, material)
	return mesh
