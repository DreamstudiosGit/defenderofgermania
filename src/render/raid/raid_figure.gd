class_name RaidFigure
extends Node3D
## One close-up raid fighter: the skinned Blender model (unit_raider or unit_guard) with the
## battle's toon shader and ink hull, tinted in its owner's colours, the owner's crest on the
## helmet, posed by RaidAnimator.

const DIRECTORY := "res://assets/combat/"

var animator: RaidAnimator

var _meshes: Array[GeometryInstance3D] = []


## model: "raider" or "guard"; colors: field and charge colour of the owner.
func build(model: String, owner_id: String, colors: PackedColorArray) -> void:
	var path := DIRECTORY + "unit_%s.glb" % model
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("raid: cannot load %s" % path)
		return
	var root := scene.instantiate()
	add_child(root)
	var skeleton := root.find_child("Skeleton3D", true, false) as Skeleton3D
	var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if skeleton == null or player == null:
		push_error("raid: %s has no skeleton or clips" % path)
		return
	animator = RaidAnimator.new(skeleton, player)
	player.get_parent().remove_child(player)
	player.free()
	for node: Node in skeleton.get_children():
		var instance := node as MeshInstance3D
		if instance == null or instance.mesh == null:
			continue
		# Own mesh copy per figure: shared glTF meshes with per-figure override materials raise
		# null-material errors on free in the headless renderer.
		var mesh := instance.mesh.duplicate() as ArrayMesh
		for surface: int in mesh.get_surface_count():
			mesh.surface_set_material(surface, _figure_material(mesh.surface_get_material(surface)))
		instance.mesh = mesh
		_meshes.append(instance)
	var anchor := root.find_child("crest_anchor", false, false) as Node3D
	if anchor != null:
		_mount_crest(skeleton, anchor.transform, owner_id)
	var primary := colors[0] if colors.size() >= 2 else Color.WHITE
	var secondary := colors[1] if colors.size() >= 2 else Color.WHITE
	for mesh: GeometryInstance3D in _meshes:
		mesh.set_instance_shader_parameter("house_primary", primary)
		mesh.set_instance_shader_parameter("house_secondary", secondary)


func pose(clip_name: StringName, time: float, loop: bool = false) -> void:
	if animator != null:
		animator.show_pose(clip_name, time, loop)


func _process(delta: float) -> void:
	if animator != null:
		animator.update(delta)


func _mount_crest(skeleton: Skeleton3D, anchor: Transform3D, owner_id: String) -> void:
	var crests: Dictionary = BattleModels.settings().get("crests", {})
	var head := skeleton.find_bone("head")
	if not crests.has(owner_id) or head < 0:
		return
	var crest := BattleModels.mesh(str(crests[owner_id]), true)
	if crest == null:
		return
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = "head"
	skeleton.add_child(attachment)
	var instance := MeshInstance3D.new()
	instance.mesh = crest
	instance.transform = skeleton.get_bone_global_rest(head).affine_inverse() * anchor
	attachment.add_child(instance)
	_meshes.append(instance)


## The battle's figure shader (toon light, house colour masks) with the shared ink outline.
static func _figure_material(source: Material) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = BattleModels.MOTION
	var source_name := source.resource_name if source != null else ""
	material.set_shader_parameter("house_slot", BattleModels.HOUSE_SLOTS.get(source_name, 0))
	if source is StandardMaterial3D:
		var standard := source as StandardMaterial3D
		material.set_shader_parameter("albedo", standard.albedo_color)
		material.set_shader_parameter("metallic", standard.metallic)
		material.set_shader_parameter("roughness", standard.roughness)
	material.next_pass = BattleModels.outline()
	return material
