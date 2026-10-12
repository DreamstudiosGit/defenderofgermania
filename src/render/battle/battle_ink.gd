class_name BattleInk
extends MeshInstance3D
## Full-screen ink, grain and vignette pass over the battle (battle_ink.gdshader), tuned by the
## "ink" section of data/combat_art.json.

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
	var ink: Dictionary = BattleModels.settings().get("ink", {})
	for key: String in ink:
		var value: Variant = ink[key]
		if key == "color":
			material.set_shader_parameter("ink", Color.from_string(str(value), Color.BLACK))
		elif key != "outline_width":
			material.set_shader_parameter(key, value)
	material_override = material
