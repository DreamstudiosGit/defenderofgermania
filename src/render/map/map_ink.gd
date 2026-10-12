class_name MapInk
extends MeshInstance3D
## Full-screen ink, grain and vignette pass over the map table: the battle's ink shader tuned
## by the "ink" section of data/map_art.json.

const SHADER := preload("res://src/render/battle/battle_ink.gdshader")


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	mesh = quad
	# The vertex shader covers the screen wherever the node is, so it must never be culled.
	extra_cull_margin = 16384.0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = SHADER
	var ink := MapArt.section("ink")
	for key: String in ink:
		if key == "color":
			material.set_shader_parameter("ink", MapArt.color("ink", "color", Color.BLACK))
		elif key != "outline_width":
			material.set_shader_parameter(key, ink[key])
	material_override = material
