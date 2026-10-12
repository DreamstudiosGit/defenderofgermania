class_name BattleRiver
extends MeshInstance3D

var _offset: float = -8.0


func build(field_size: Vector2, settings: Dictionary) -> void:
	_offset = float(settings.get("river_offset", -8.0))
	var width := float(settings.get("river_width", 5.4))
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	var sections := ceili(field_size.x + 48) + 1
	for i: int in sections:
		var center := center_at(float(i) - 24)
		for side: int in 2:
			vertices.append(center + Vector3(0, 0.026, (side - 0.5) * width))
			normals.append(Vector3.UP)
			uv.append(Vector2(side, float(i) / 12))
		if i > 0:
			var j := (i - 1) * 2
			indices.append_array([j, j + 2, j + 1, j + 2, j + 3, j + 1])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var water_mesh := ArrayMesh.new()
	water_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = water_mesh
	var water := ShaderMaterial.new()
	water.shader = BattleModels.WATER
	water.set_shader_parameter("albedo", Color(0.09, 0.42, 0.57))
	water.set_shader_parameter("roughness", 0.32)
	water.set_shader_parameter("axis_swapped", true)
	var parameters: Dictionary = BattleModels.settings().get("water", {})
	for key: String in parameters:
		var value: Variant = parameters[key]
		if value is String and key.ends_with("_color"):
			value = Color.from_string(value, Color.WHITE)
		water.set_shader_parameter(key, value)
	material_override = water
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func center_at(x: float) -> Vector3:
	return Vector3(x, 0, _offset + sin(x * 0.075) * 1.8 + sin(x * 0.19) * 0.35)
