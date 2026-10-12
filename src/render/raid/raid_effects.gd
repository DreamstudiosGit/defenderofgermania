class_name RaidEffects
extends Node3D
## No blood: blows that land throw sparks, blocks and parries flash, a felled guard raises dust.
## Bursts come from a small pool of one-shot particle emitters.

const POOL := 10
## Height of a blow above the floor: high, middle, low.
const BLOW_HEIGHTS: Array[float] = [1.65, 1.15, 0.55]

var _pool: Array[CPUParticles3D] = []
var _next: int = 0
var _sparks: StandardMaterial3D
var _dust: StandardMaterial3D


func _ready() -> void:
	_sparks = StandardMaterial3D.new()
	_sparks.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sparks.cull_mode = BaseMaterial3D.CULL_DISABLED
	_sparks.vertex_color_use_as_albedo = true
	_sparks.vertex_color_is_srgb = true
	_dust = CastleArt.puff()
	for i: int in POOL:
		var particles := CPUParticles3D.new()
		particles.one_shot = true
		particles.emitting = false
		particles.explosiveness = 0.95
		add_child(particles)
		_pool.append(particles)


## Sparks where a blow lands: many for a hit, a bright few for a block or parry.
func sparks(at: Vector3, count: int, color: Color, spread: float = 3.0) -> void:
	var burst := _take(at)
	burst.amount = count
	burst.lifetime = 0.45
	burst.direction = Vector3(0, 0.8, 0.3)
	burst.spread = 80.0
	burst.particle_flag_align_y = true
	burst.gravity = Vector3(0, -9.0, 0)
	burst.initial_velocity_min = spread * 0.5
	burst.initial_velocity_max = spread
	burst.scale_amount_min = 0.5
	burst.scale_amount_max = 1.0
	burst.color = color
	var quad := QuadMesh.new()
	quad.size = Vector2(0.03, 0.18)
	burst.mesh = quad
	burst.material_override = _sparks
	burst.restart()


func dust(at: Vector3) -> void:
	var burst := _take(at)
	burst.amount = 14
	burst.lifetime = 0.9
	burst.direction = Vector3.UP
	burst.spread = 80.0
	burst.particle_flag_align_y = false
	burst.gravity = Vector3(0, 0.4, 0)
	burst.initial_velocity_min = 0.4
	burst.initial_velocity_max = 1.2
	burst.scale_amount_min = 0.6
	burst.scale_amount_max = 1.2
	burst.color = Color(0.55, 0.5, 0.42, 0.7)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.45, 0.45)
	burst.mesh = quad
	burst.material_override = _dust
	burst.restart()


func _take(at: Vector3) -> CPUParticles3D:
	var burst := _pool[_next]
	_next = (_next + 1) % _pool.size()
	burst.position = at
	return burst
