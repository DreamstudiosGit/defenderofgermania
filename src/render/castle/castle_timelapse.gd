class_name CastleTimelapse
extends Node3D
## The "Zeitraffer" when the castle view opens ("timelapse" in data/castle_art.json): pieces
## under construction rise out of the ground to their progress in a cloud of dust, so do pieces
## finished or bought since the province was last shown, and new village houses pop up one
## after another. What was shown is remembered per province for the rest of the session.

const RISING_KINDS: Array[CastleLayout.Kind] = [
	CastleLayout.Kind.CASTLE, CastleLayout.Kind.BUILDING, CastleLayout.Kind.DECORATION
]

## Province id -> {"pieces": {placement key: progress}, "houses": count} of its last showing.
static var _memory: Dictionary[String, Dictionary] = {}

var _risers: Array[Dictionary] = []
var _houses: Array[Dictionary] = []
var _time: float = 0.0
var _duration: float = 3.0


## Forgets every province shown so far.
static func forget() -> void:
	_memory.clear()


## Starts the time-lapse for the layout whose placements stand as `nodes` (same order).
func start(layout: CastleLayout, nodes: Array[MeshInstance3D]) -> void:
	stop()
	var settings := CastleArt.section("timelapse")
	_duration = float(settings.get("duration", 3.0))
	var previous: Dictionary = _memory.get(layout.province_id, {})
	var seen: Dictionary = previous.get("pieces", {})
	var known := not previous.is_empty()
	var shown: Dictionary = {}
	var houses_before := int(previous.get("houses", 0))
	var house_index := 0
	for i: int in layout.placements.size():
		var placement := layout.placements[i]
		var node := nodes[i]
		if node == null:
			continue
		if placement.kind == CastleLayout.Kind.HOUSE:
			if house_index >= houses_before:
				_add_house(node, house_index - houses_before, settings)
			house_index += 1
			continue
		if placement.kind not in RISING_KINDS:
			continue
		var key := placement.key()
		shown[key] = placement.progress
		var before := float(seen.get(key, 0.0))
		# Unfinished pieces always grow out of the ground; finished ones only when they are new.
		var from := 1.0
		if placement.progress < 1.0:
			from = before if before < placement.progress else 0.0
		elif known and before < 1.0:
			from = before
		if from < placement.progress:
			_add_riser(node, placement, from)
	_memory[layout.province_id] = {"pieces": shown, "houses": house_index}
	advance(0.0)


func stop() -> void:
	for riser: Dictionary in _risers:
		if is_instance_valid(riser["node"]):
			_advance_riser(riser, 1.0)
	for house: Dictionary in _houses:
		var node: Variant = house["node"]
		if is_instance_valid(node):
			(node as Node3D).transform = house["transform"]
			(node as Node3D).visible = true
	for child: Node in get_children():
		child.queue_free()
	_risers.clear()
	_houses.clear()
	_time = 0.0


func is_playing() -> bool:
	return not _risers.is_empty() or not _houses.is_empty()


func _process(delta: float) -> void:
	if is_playing():
		advance(delta)


## Moves the time-lapse on by `delta` seconds.
func advance(delta: float) -> void:
	_time += delta
	var t := clampf(_time / maxf(_duration, 0.01), 0.0, 1.0)
	var eased := ease(t, -2.0)
	for riser: Dictionary in _risers:
		_advance_riser(riser, eased)
	var finished: Array[Dictionary] = []
	for house: Dictionary in _houses:
		var local := clampf((_time - float(house["delay"])) / float(house["length"]), 0.0, 1.0)
		var node := house["node"] as Node3D
		var target: Transform3D = house["transform"]
		node.visible = local > 0.0
		var size := maxf(_pop(local), 0.001)
		node.transform = Transform3D(target.basis.scaled(Vector3.ONE * size), target.origin)
		if local >= 1.0:
			finished.append(house)
	for house: Dictionary in finished:
		_houses.erase(house)
	if t >= 1.0:
		for riser: Dictionary in _risers:
			(riser["dust"] as CPUParticles3D).emitting = false
		_risers.clear()


func _advance_riser(riser: Dictionary, eased: float) -> void:
	var node := riser["node"] as Node3D
	var target: Transform3D = riser["transform"]
	var progress := lerpf(float(riser["from"]), float(riser["to"]), eased)
	node.transform = CastleConstruction.posed(str(riser["piece"]), target, progress)


## Overshooting pop of a house: 0 -> a little over 1 -> 1.
static func _pop(t: float) -> float:
	var back := 1.7
	var u := t - 1.0
	return 1.0 + (back + 1.0) * u * u * u + back * u * u


func _add_riser(node: MeshInstance3D, placement: CastleLayout.Placement, from: float) -> void:
	var riser := {
		"node": node, "transform": placement.transform, "piece": placement.piece,
		"from": from, "to": placement.progress, "dust": _dust(node, placement),
	}
	_risers.append(riser)


func _add_house(node: MeshInstance3D, order: int, settings: Dictionary) -> void:
	_houses.append({
		"node": node, "transform": node.transform,
		"delay": order * float(settings.get("house_interval", 0.05)),
		"length": float(settings.get("house_pop", 0.35)),
	})
	node.visible = false


## A dust cloud round the foot of a rising piece.
func _dust(node: MeshInstance3D, placement: CastleLayout.Placement) -> CPUParticles3D:
	var settings := CastleArt.section("timelapse")
	var box := node.mesh.get_aabb() if node.mesh != null else AABB()
	var dust := CPUParticles3D.new()
	dust.amount = int(settings.get("dust_puffs", 18))
	dust.lifetime = float(settings.get("dust_life", 1.6))
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var extent := box.size * placement.transform.basis.get_scale() * 0.5
	dust.emission_box_extents = Vector3(maxf(extent.x, 1.0), 0.3, maxf(extent.z, 1.0))
	dust.direction = Vector3.UP
	dust.spread = 60.0
	dust.gravity = Vector3(0.0, 0.6, 0.0)
	dust.initial_velocity_min = 0.6
	dust.initial_velocity_max = 2.0
	dust.scale_amount_min = 0.6
	dust.scale_amount_max = 1.4
	var fade := Gradient.new()
	var color := CastleArt.color("timelapse", "dust_color", Color(0.77, 0.68, 0.53, 0.6))
	fade.set_color(0, color)
	fade.set_color(1, Color(color, 0.0))
	dust.color_ramp = fade
	var quad := QuadMesh.new()
	var size := float(settings.get("dust_size", 2.5))
	quad.size = Vector2(size, size)
	quad.material = CastleArt.puff()
	dust.mesh = quad
	var center := placement.transform * box.get_center()
	dust.position = Vector3(center.x, placement.transform.origin.y + 0.3, center.z)
	dust.rotation.y = placement.transform.basis.get_euler().y
	add_child(dust)
	dust.emitting = true
	return dust

