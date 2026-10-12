class_name MerchantCamera
extends Camera3D
## Orthographic side view along the road, tilted down a little so the verges and the river
## read in depth. Follows the leader with a look-ahead in his riding direction; the intro
## glides from the gate back along the train to him.

const PITCH_DEG := 11.0
const HEIGHT := 11.0
const DISTANCE := 120.0
const LOOK_AHEAD := 4.0
const AIM_HEIGHT := 2.6
const FOLLOW_RATE := 3.0

var _x: float = 0.0
var _low: float = 0.0
var _high: float = 0.0


func setup(low: float, high: float, start_x: float) -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	keep_aspect = Camera3D.KEEP_HEIGHT
	size = HEIGHT
	far = 400.0
	rotation = Vector3(-deg_to_rad(PITCH_DEG), 0.0, 0.0)
	_low = low
	_high = high
	_x = start_x
	_place()


## Glides to x (with the look-ahead for facing); delta 0 jumps there.
func follow(x: float, facing: float, delta: float) -> void:
	var goal := clampf(x + facing * LOOK_AHEAD, _low, _high)
	var blend := 1.0 if delta <= 0.0 else 1.0 - exp(-FOLLOW_RATE * delta)
	_x = lerpf(_x, goal, blend)
	_place()


## The intro's pan: share 0 at the gate, 1 at the leader.
func pan(from_x: float, to_x: float, share: float) -> void:
	var eased := share * share * (3.0 - 2.0 * share)
	_x = clampf(lerpf(from_x, to_x, eased), _low, _high)
	_place()


func _place() -> void:
	var pitch := deg_to_rad(PITCH_DEG)
	var aim := Vector3(_x, AIM_HEIGHT, 0.0)
	position = aim + Vector3(0.0, sin(pitch), cos(pitch)) * DISTANCE
