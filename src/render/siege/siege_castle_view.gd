class_name SiegeCastleView
extends Node3D
## The besieged castle in 3D: every layout part as a kit piece standing on its side-view
## rectangle (the line of fire runs along +X at z = 0), the wall or palisade ring around it and
## the decorations ("layouts" in data/combat_siege_art.json). It shows what the rules decided:
## hits flash and shake, wood burns and chars, destroyed parts tumble down under Jolt physics
## and leave rubble. The physics is presentation only; the rules never read it back.

const FLASH_SECONDS := 0.3
const SHAKE_SECONDS := 0.4
const SHAKE_METRES := 0.35
const FLASH := Color(1.0, 0.95, 0.8)

var _castle: SiegeCastle
var _effects: SiegeEffects
var _ring := SiegeRing.new()
var _holders: Array[Node3D] = []
var _homes := PackedVector3Array()
var _sizes := PackedVector3Array()
var _overlays: Array[StandardMaterial3D] = []
var _bodies: Array[StaticBody3D] = []
var _fires: Array[Node3D] = []
var _flash := PackedFloat64Array()
var _shake := PackedFloat64Array()
var _char := PackedFloat64Array()
var _fallen: Array[RigidBody3D] = []
var _fallen_age := PackedFloat64Array()
var _fallen_parts := PackedInt32Array()
var _charred := Color(0.1, 0.07, 0.05, 0.7)


func build(
	castle: SiegeCastle, layout_key: String, colors: PackedColorArray, effects: SiegeEffects
) -> void:
	clear()
	_castle = castle
	_effects = effects
	_charred = Color.from_string(str(SiegeArt.settings().get("charred", "")), _charred)
	var art: Dictionary = SiegeArt.section("layouts").get(layout_key, {})
	var parts: Dictionary = art.get("parts", {})
	for i: int in castle.part_count():
		_add_part(i, parts.get(castle.parts[i].id, {}), colors)
	_ring.name = "Ring"
	if _ring.get_parent() == null:
		add_child(_ring)
	_ring.build(art.get("ring", {}), castle.front, colors)
	for entry: Variant in art.get("decor", []):
		if entry is Dictionary:
			_add_decor(entry, colors)


func clear() -> void:
	for child: Node in get_children():
		if child != _ring:
			child.queue_free()
	_ring.clear()
	_holders.clear()
	_homes.clear()
	_sizes.clear()
	_overlays.clear()
	_bodies.clear()
	_fires.clear()
	_flash.clear()
	_shake.clear()
	_char.clear()
	_fallen.clear()
	_fallen_age.clear()
	_fallen_parts.clear()


## Point above a standing part for its HP bar.
func part_top(i: int) -> Vector3:
	var part := _castle.parts[i]
	return Vector3(_castle.front + (part.x0 + part.x1) * 0.5, part.y1 + 1.5, 0.0)


func apply(events: Array[SiegeEvent], impact: Vector3) -> void:
	for event: SiegeEvent in events:
		match event.kind:
			SiegeEvent.Kind.HIT:
				_flash[event.part] = FLASH_SECONDS
				_shake[event.part] = SHAKE_SECONDS
				_effects.burst(impact, _dust(event.part), 3.0)
			SiegeEvent.Kind.CRUSHED:
				_shake[event.part] = SHAKE_SECONDS
				_effects.burst(part_top(event.part), _dust(event.part), 3.0, 0.6)
			SiegeEvent.Kind.IGNITED:
				_ignite(event.part)
			SiegeEvent.Kind.BURNED:
				_char[event.part] = minf(1.0, _char[event.part] + 0.34)
			SiegeEvent.Kind.DESTROYED:
				_fall(event.part, event.cause)


func update(delta: float) -> void:
	for i: int in _holders.size():
		if not is_instance_valid(_holders[i]):
			continue
		_flash[i] = maxf(0.0, _flash[i] - delta)
		_shake[i] = maxf(0.0, _shake[i] - delta)
		var flash := _flash[i] / FLASH_SECONDS
		var tint := Color(_charred, _charred.a * _char[i]).lerp(Color(FLASH, 0.55), flash)
		_overlays[i].albedo_color = tint
		if _holders[i].get_parent() == self:
			var wobble := sin(_shake[i] * 60.0) * SHAKE_METRES * _shake[i] / SHAKE_SECONDS
			_holders[i].position = _homes[i] + Vector3(wobble, 0.0, wobble * 0.5)
	_update_fallen(delta)


func _add_part(i: int, art: Dictionary, colors: PackedColorArray) -> void:
	var part := _castle.parts[i]
	var holder := Node3D.new()
	holder.name = part.id
	var home := Vector3(_castle.front + (part.x0 + part.x1) * 0.5, part.y0, 0.0)
	home += SiegeArt.vector(art.get("offset"))
	holder.position = home
	add_child(holder)
	var piece := str(art.get("piece", ""))
	var size := Vector3(part.x1 - part.x0, part.y1 - part.y0, part.x1 - part.x0)
	var overlay := StandardMaterial3D.new()
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.albedo_color = Color(0, 0, 0, 0)
	if piece.is_empty():
		push_error("siege art: no piece for part %s" % part.id)
	else:
		var node := SiegeArt.instance(
			piece, float(art.get("yaw", -90.0)), SiegeArt.scale_of(art.get("scale", 1.0))
		)
		_paint(node, piece, colors)
		node.material_overlay = overlay
		holder.add_child(node)
		if node.mesh != null:
			size.z = (node.transform * node.mesh.get_aabb()).size.z
	_holders.append(holder)
	_homes.append(home)
	_sizes.append(size)
	_overlays.append(overlay)
	_fires.append(null)
	_flash.append(0.0)
	_shake.append(0.0)
	_char.append(0.0)
	_bodies.append(_static_body(holder, size))


func _add_decor(entry: Dictionary, colors: PackedColorArray) -> void:
	var piece := str(entry.get("piece", ""))
	var node := SiegeArt.instance(
		piece, float(entry.get("yaw", -90.0)), SiegeArt.scale_of(entry.get("scale", 1.0))
	)
	_paint(node, piece, colors)
	var at := SiegeArt.vector(entry.get("at")) + Vector3(_castle.front, 0.0, 0.0)
	var attach := _castle.index_of(str(entry.get("attach", "")))
	if attach >= 0:
		node.position = at - _homes[attach]
		node.material_overlay = _overlays[attach]
		_holders[attach].add_child(node)
	else:
		node.position = at
		add_child(node)


static func _paint(node: MeshInstance3D, piece: String, colors: PackedColorArray) -> void:
	if SiegeArt.has_house_colors(piece) and colors.size() >= 2:
		node.set_instance_shader_parameter("house_primary", colors[0])
		node.set_instance_shader_parameter("house_secondary", colors[1])


func _static_body(holder: Node3D, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Body"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0.0, size.y * 0.5, 0.0)
	body.add_child(shape)
	holder.add_child(body)
	return body


func _ignite(i: int) -> void:
	if _fires[i] != null:
		return
	var size := _sizes[i]
	_fires[i] = _effects.fire(_holders[i], Vector3(0.0, size.y * 0.75, 0.0), size * 0.6)


func _dust(i: int) -> Color:
	var material := _castle.parts[i].material
	return SiegeArt.color("dust", "wood" if material == SiegeConfig.WOOD else "stone", Color.TAN)


## The part comes down: its own body leaves the static world and tumbles away from the
## trebuchet under Jolt, then sinks into its rubble heap.
func _fall(i: int, cause: SiegeEvent.Cause) -> void:
	var holder := _holders[i]
	if not is_instance_valid(holder) or holder.get_parent() != self:
		return
	if _fires[i] != null:
		_fires[i].queue_free()
		_fires[i] = null
	if cause == SiegeEvent.Cause.BURNT:
		_char[i] = 1.0
	_bodies[i].queue_free()
	var size := _sizes[i]
	var body := RigidBody3D.new()
	body.name = "Falling_%s" % _castle.parts[i].id
	body.mass = maxf(1.0, size.x * size.y * size.z * 0.05)
	add_child(body)
	body.global_position = holder.global_position
	holder.reparent(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size * 0.9
	shape.shape = box
	shape.position = Vector3(0.0, size.y * 0.5, 0.0)
	body.add_child(shape)
	var falling := SiegeArt.section("falling")
	var push := float(falling.get("push", 4.0)) * (0.3 if cause == SiegeEvent.Cause.BURNT else 1.0)
	var spin := float(falling.get("spin", 1.6)) * (1.0 if i % 2 == 0 else -1.0)
	body.linear_velocity = Vector3(push, push * 0.4, push * 0.25 * (1 if i % 2 == 0 else -1))
	body.angular_velocity = Vector3(spin * 0.3, spin * 0.2, -spin)
	_fallen.append(body)
	_fallen_age.append(0.0)
	_fallen_parts.append(i)
	_effects.burst(holder.global_position + Vector3(0.0, size.y * 0.5, 0.0), _dust(i),
		maxf(3.0, size.x), 1.4)


func _update_fallen(delta: float) -> void:
	var falling := SiegeArt.section("falling")
	var tumble := float(falling.get("seconds", 3.5))
	var sink := float(falling.get("sink_seconds", 1.2))
	for k: int in range(_fallen.size() - 1, -1, -1):
		var body := _fallen[k]
		_fallen_age[k] += delta
		var age := _fallen_age[k]
		if age < tumble:
			continue
		if not body.freeze:
			body.freeze = true
			_add_rubble(_fallen_parts[k])
		var size := _sizes[_fallen_parts[k]]
		body.position.y -= delta * (size.y + 2.0) / sink
		if age >= tumble + sink:
			body.queue_free()
			_fallen.remove_at(k)
			_fallen_age.remove_at(k)
			_fallen_parts.remove_at(k)


func _add_rubble(i: int) -> void:
	var part := _castle.parts[i]
	var rubble: Dictionary = SiegeArt.section("rubble")
	var piece := str(rubble.get(part.material, ""))
	if piece.is_empty():
		return
	var spread := clampf((part.x1 - part.x0) / 6.0, 0.5, 1.6)
	spread *= SiegeArt.number("falling", "rubble_scale", 1.0)
	var node := SiegeArt.instance(piece, 37.0 * i, Vector3(spread, spread, spread))
	node.position = Vector3(_castle.front + (part.x0 + part.x1) * 0.5 + 1.0, 0.0, 0.0)
	add_child(node)
