class_name SiegeShotView
extends Node3D
## What flies: the dotted preview of the first 20 % of the flight while aiming, the stone or
## fire pot along the path the rules computed (with a pale trail, the pot trailing flames), and
## dark marks where the last shots came down, so the next one can be corrected.

var _dots := MultiMeshInstance3D.new()
var _projectile := Node3D.new()
var _stone: MeshInstance3D
var _pot: MeshInstance3D
var _flames: CPUParticles3D
var _trail := MeshInstance3D.new()
var _trail_mesh := ImmediateMesh.new()
var _trail_material := StandardMaterial3D.new()
var _marks: Array[MeshInstance3D] = []
var _path: SiegeBallistics.Launch
var _history := PackedVector3Array()
var _times := PackedFloat64Array()


func _ready() -> void:
	var preview := SiegeArt.section("preview")
	var dot := SphereMesh.new()
	var size := float(preview.get("dot_size", 1.0))
	dot.radius = size * 0.5
	dot.height = size
	dot.radial_segments = 8
	dot.rings = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = SiegeArt.color("preview", "color", Color.GOLD)
	dot.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = dot
	multimesh.instance_count = int(preview.get("dots", 14))
	_dots.multimesh = multimesh
	_dots.name = "Preview"
	add_child(_dots)
	var art := SiegeArt.section("projectile")
	var scale := Vector3.ONE * float(art.get("scale", 2.5))
	_stone = SiegeArt.instance("siege_stone", 0.0, scale)
	_pot = SiegeArt.instance("siege_fire_pot", 0.0, scale)
	_projectile.name = "Projectile"
	_projectile.add_child(_stone)
	_projectile.add_child(_pot)
	_flames = SiegeEffects.trail_flames(SiegeArt.color("projectile", "flame_color", Color.ORANGE))
	_projectile.add_child(_flames)
	add_child(_projectile)
	_projectile.visible = false
	_trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_material.vertex_color_use_as_albedo = true
	_trail_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail.mesh = _trail_mesh
	_trail.material_override = _trail_material
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)


## Dots along the visible start of the flight; an empty array hides them.
func show_preview(points: PackedVector2Array) -> void:
	var count := _dots.multimesh.instance_count
	for i: int in count:
		var transform := Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)
		if points.size() >= 2:
			var at := points[roundi(float(i) / maxi(count - 1, 1) * (points.size() - 1))]
			var fade := 1.0 - 0.5 * float(i) / count
			transform = Transform3D(Basis().scaled(Vector3.ONE * fade), Vector3(at.x, at.y, 0.0))
		_dots.multimesh.set_instance_transform(i, transform)


func launch(path: SiegeBallistics.Launch, fire_pot: bool) -> void:
	_path = path
	_history.clear()
	_times.clear()
	_stone.visible = not fire_pot
	_pot.visible = fire_pot
	_flames.emitting = fire_pot
	_projectile.visible = true
	fly(0.0)


## Puts the projectile `t` seconds into its flight and extends the trail.
func fly(t: float) -> void:
	if _path == null:
		return
	var at := Vector3(_path.x_at(t), _path.y_at(t), 0.0)
	_projectile.position = at
	_projectile.rotation = Vector3(0.0, 0.0, -t * 4.0)
	_history.append(at)
	_times.append(t)
	_draw_trail(t)


## The projectile lands: it disappears and leaves a mark on the ground where it came down.
func land(at: Vector3, on_ground: bool) -> void:
	_projectile.visible = false
	_flames.emitting = false
	_path = null
	_trail_mesh.clear_surfaces()
	if on_ground:
		_add_mark(at)


func clear() -> void:
	land(Vector3.ZERO, false)
	for mark: MeshInstance3D in _marks:
		mark.queue_free()
	_marks.clear()
	show_preview(PackedVector2Array())


func _draw_trail(now: float) -> void:
	_trail_mesh.clear_surfaces()
	var keep := SiegeArt.number("projectile", "trail_seconds", 1.4)
	var width := SiegeArt.number("projectile", "trail_width", 0.5)
	var color := SiegeArt.color("projectile", "trail_color", Color.WHITE)
	var first := 0
	while first < _times.size() and _times[first] < now - keep:
		first += 1
	if _history.size() - first < 2:
		return
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i: int in range(first, _history.size()):
		var age := clampf((now - _times[i]) / keep, 0.0, 1.0)
		var half := width * (1.0 - age) * 0.5
		_trail_mesh.surface_set_color(Color(color, 0.7 * (1.0 - age)))
		_trail_mesh.surface_add_vertex(_history[i] + Vector3(0.0, half, 0.0))
		_trail_mesh.surface_set_color(Color(color, 0.7 * (1.0 - age)))
		_trail_mesh.surface_add_vertex(_history[i] - Vector3(0.0, half, 0.0))
	_trail_mesh.surface_end()


func _add_mark(at: Vector3) -> void:
	var limit := int(SiegeArt.number("projectile", "marks", 4.0))
	while _marks.size() >= limit and not _marks.is_empty():
		var oldest: MeshInstance3D = _marks.pop_front()
		oldest.queue_free()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.6
	disc.bottom_radius = 1.6
	disc.height = 0.05
	disc.radial_segments = 12
	var material := StandardMaterial3D.new()
	material.albedo_color = SiegeArt.color("projectile", "mark_color", Color.SADDLE_BROWN)
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	disc.material = material
	var mark := MeshInstance3D.new()
	mark.name = "Mark"
	mark.mesh = disc
	mark.position = Vector3(at.x, 0.04, 0.0)
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mark)
	_marks.append(mark)
