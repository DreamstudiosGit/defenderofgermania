class_name SiegeCamera
extends Camera3D
## Side view from beside the trebuchet ("camera" in data/combat_siege_art.json): while aiming
## it shows the trebuchet and the castle, during the flight it glides along with the stone to
## the castle, and it holds there while parts fall; impacts shake it a little.

var _aim_position := Vector3.ZERO
var _aim_target := Vector3.ZERO
var _castle_position := Vector3.ZERO
var _castle_target := Vector3.ZERO
var _from_position := Vector3.ZERO
var _from_target := Vector3.ZERO
var _to_position := Vector3.ZERO
var _to_target := Vector3.ZERO
var _blend: float = 1.0
var _glide: float = 2.4
## Mid-flight the camera steps back by this much and looks this far towards the projectile.
var _pull := Vector3(0, 10, 45)
var _follow_look: float = 0.35
var _shake: float = 0.0
var _position := Vector3.ZERO
var _target := Vector3.ZERO


func setup() -> void:
	var art := SiegeArt.section("camera")
	fov = float(art.get("fov", 30.0))
	near = 0.5
	far = 2000.0
	var aim: Dictionary = art.get("aim", {})
	var castle: Dictionary = art.get("castle", {})
	_aim_position = SiegeArt.vector(aim.get("position"), Vector3(-30, 22, -64))
	_aim_target = SiegeArt.vector(aim.get("target"), Vector3(110, 10, 10))
	_castle_position = SiegeArt.vector(castle.get("position"), Vector3(112, 30, -66))
	_castle_target = SiegeArt.vector(castle.get("target"), Vector3(172, 8, 6))
	_glide = float(art.get("glide", 2.4))
	_pull = SiegeArt.vector(art.get("follow_pull"), _pull)
	_follow_look = float(art.get("follow_look", 0.35))
	_position = _aim_position
	_target = _aim_target
	_to_position = _aim_position
	_to_target = _aim_target
	_blend = 1.0
	_apply()


func frame_aim() -> void:
	_glide_to(_aim_position, _aim_target)


func frame_castle() -> void:
	_glide_to(_castle_position, _castle_target)


## During the flight: from the aiming view to the castle view by flight progress, stepping
## back mid-flight and looking towards the projectile so the arc and the castle both show.
func follow(progress: float, projectile: Vector3) -> void:
	var share := smoothstep(0.0, 1.0, clampf(progress, 0.0, 1.0))
	var bump := sin(PI * clampf(progress, 0.0, 1.0))
	_position = _aim_position.lerp(_castle_position, share) + _pull * bump
	var look := _aim_target.lerp(_castle_target, share)
	_target = look.lerp(projectile, _follow_look * bump)
	_to_position = _position
	_to_target = _target
	_blend = 1.0


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount * SiegeArt.number("camera", "shake", 0.5))


func update(delta: float) -> void:
	if _blend < 1.0:
		_blend = minf(1.0, _blend + delta / maxf(_glide, 0.01))
		var share := smoothstep(0.0, 1.0, _blend)
		_position = _from_position.lerp(_to_position, share)
		_target = _from_target.lerp(_to_target, share)
	_shake = maxf(0.0, _shake - delta * 1.5)
	_apply()


func _glide_to(target_position: Vector3, target: Vector3) -> void:
	_from_position = _position
	_from_target = _target
	_to_position = target_position
	_to_target = target
	_blend = 0.0


func _apply() -> void:
	var jitter := Vector3(sin(Time.get_ticks_msec() * 0.07), cos(Time.get_ticks_msec() * 0.09),
		0.0) * _shake
	look_at_from_position(_position + jitter, _target + jitter, Vector3.UP)
