class_name BattleField
extends Node3D
## Graybox battlefield: sunny light and sky, a meadow with surroundings, tinted deployment
## zones and the rules' obstacles as simple tree and rock meshes.

const MEADOW := Color(0.56, 0.62, 0.30)
const SURROUNDINGS := Color(0.38, 0.47, 0.22)
const BARK := Color(0.36, 0.25, 0.15)
const LEAVES := Color(0.18, 0.40, 0.18)
const STONE := Color(0.55, 0.53, 0.50)
const ZONE_ALPHA := 0.18

var _zones: Array[MeshInstance3D] = []


func build(rules: BattleRules, armies: Array[BattleRules.ArmyPreset]) -> void:
	_add_environment()
	var size := rules.field_size
	_add_plane(size * 3.0, Vector3(size.x / 2, -0.05, size.y / 2), _material(SURROUNDINGS))
	_add_plane(size, Vector3(size.x / 2, 0.0, size.y / 2), _material(MEADOW))
	for s: int in BattleState.SIDES:
		var color := armies[s].color if s < armies.size() else Color.WHITE
		color.a = ZONE_ALPHA
		var zone_x := rules.deploy_depth / 2 if s == 0 else size.x - rules.deploy_depth / 2
		var zone := _add_plane(
			Vector2(rules.deploy_depth, size.y), Vector3(zone_x, 0.03, size.y / 2), _material(color)
		)
		_zones.append(zone)
	for i: int in rules.obstacles.size():
		var obstacle := rules.obstacles[i]
		var at := Vector3(obstacle.x, 0.0, obstacle.y)
		if rules.obstacle_kinds[i] == "tree":
			_add_tree(at, obstacle.z)
		else:
			_add_rock(at, obstacle.z)


func show_zones(visible_now: bool) -> void:
	for zone: MeshInstance3D in _zones:
		zone.visible = visible_now


func _add_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.35, 0.55, 0.85)
	sky_material.sky_horizon_color = Color(0.75, 0.82, 0.9)
	sky_material.ground_horizon_color = Color(0.6, 0.62, 0.5)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(-35.0), 0.0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)


func _add_plane(size: Vector2, at: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _add_tree(at: Vector3, radius: float) -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.35
	trunk.bottom_radius = 0.45
	trunk.height = 3.0
	_add_mesh(trunk, at + Vector3(0, 1.5, 0), BARK)
	var crown := CylinderMesh.new()
	crown.top_radius = 0.0
	crown.bottom_radius = radius
	crown.height = radius * 2.6
	_add_mesh(crown, at + Vector3(0, 2.5 + crown.height / 2, 0), LEAVES)


func _add_rock(at: Vector3, radius: float) -> void:
	var rock := SphereMesh.new()
	rock.radius = radius
	rock.height = radius * 1.2
	_add_mesh(rock, at + Vector3(0, radius * 0.3, 0), STONE)


func _add_mesh(mesh: Mesh, at: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color)
	instance.position = at
	add_child(instance)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
