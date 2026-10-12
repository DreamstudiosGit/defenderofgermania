class_name SiegeTrebuchetView
extends Node3D
## The attacker's trebuchet: the battle's unit model (frame, sling and four crew) with its own
## clips — idle, and "attack" where the crew hauls, the arm swings and the stone flies — in
## two-step toon light, pennant and crew tunics in the attacking house's colour.

const MODEL := "res://assets/combat/unit_trebuchet.glb"
const HOUSE_SLOT := "house_primary"

var _player: AnimationPlayer
var _materials: Dictionary[String, Material] = {}


func build(house_color: Color) -> void:
	var art := SiegeArt.section("trebuchet")
	position = SiegeArt.vector(art.get("at"))
	rotation = Vector3(0.0, deg_to_rad(float(art.get("yaw", 90.0))), 0.0)
	scale = Vector3.ONE * float(art.get("scale", 1.0))
	var scene := load(MODEL) as PackedScene
	if scene == null:
		push_error("siege: cannot load %s" % MODEL)
		return
	var model := scene.instantiate()
	add_child(model)
	_paint(model, house_color)
	_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	idle()


func idle() -> void:
	if _player != null and _player.has_animation("idle"):
		_player.play("idle")


func throw() -> void:
	if _player != null and _player.has_animation("attack"):
		_player.play("attack")
		_player.queue("idle")


## Advances the clips by hand, so the view keeps pace with the minigame's own clock.
func update(delta: float) -> void:
	if _player != null:
		_player.advance(delta)


func _paint(node: Node, house_color: Color) -> void:
	var instance := node as MeshInstance3D
	if instance != null and instance.mesh != null:
		for surface: int in instance.mesh.get_surface_count():
			instance.set_surface_override_material(
				surface, _material(instance.get_active_material(surface), house_color)
			)
	var player := node as AnimationPlayer
	if player != null:
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for child: Node in node.get_children():
		_paint(child, house_color)


func _material(source: Material, house_color: Color) -> Material:
	var name := source.resource_name if source != null else ""
	if _materials.has(name):
		return _materials[name]
	var result := source
	if source is BaseMaterial3D:
		var toon := source.duplicate() as BaseMaterial3D
		toon.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		toon.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		if name == HOUSE_SLOT:
			toon.albedo_color = house_color
		result = toon
	_materials[name] = result
	return result
