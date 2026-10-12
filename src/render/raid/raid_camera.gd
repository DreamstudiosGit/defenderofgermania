class_name RaidCamera
extends Camera3D
## Orthographic side view that follows the leader with a little look-ahead. On a sneak path it
## keeps the corridor in view as well: the guard he sneaks past stays on screen.

## Height of a cellar or gallery at which the view sits halfway between it and the corridor.
const SNEAK_SPAN := 2.7
const SNEAK_DROP := 0.75
## Extra view height (metres) while both levels must fit.
const SNEAK_ZOOM := 1.2

var _target := Vector3.ZERO
var _height: float = 1.9
var _lead: float = 1.4
var _follow: float = 3.5
var _distance: float = 30.0
var _size: float = 5.6
var _away: float = 0.0


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	_size = RaidArt.number("camera", "size", 5.6)
	size = _size
	_height = RaidArt.number("camera", "height", 1.9)
	_lead = RaidArt.number("camera", "lead", 1.4)
	_follow = RaidArt.number("camera", "follow", 3.5)
	_distance = RaidArt.number("camera", "distance", 30.0)
	rotation_degrees = Vector3(RaidArt.number("camera", "pitch_deg", -5.0), 0.0, 0.0)
	near = 1.0
	far = _distance * 2.0


## Jumps to the leader (raid start); corridor is the floor height of the corridor at his x.
func snap(leader: Vector3, corridor: float) -> void:
	_away = _away_from(leader, corridor)
	_target = _goal(leader, corridor)
	_apply()


func follow(leader: Vector3, corridor: float, delta: float) -> void:
	var weight := 1.0 - exp(-_follow * delta)
	_away = lerpf(_away, _away_from(leader, corridor), weight)
	_target = _target.lerp(_goal(leader, corridor), weight)
	_apply()


func _away_from(leader: Vector3, corridor: float) -> float:
	return clampf(absf(leader.y - corridor) / SNEAK_SPAN, 0.0, 1.0)


func _goal(leader: Vector3, corridor: float) -> Vector3:
	var away := _away_from(leader, corridor)
	var y := lerpf(leader.y, (leader.y + corridor) * 0.5, away) + _height - SNEAK_DROP * away
	return Vector3(leader.x + _lead, y, 0.0)


func _apply() -> void:
	size = _size + SNEAK_ZOOM * _away
	position = _target + basis.z * _distance
