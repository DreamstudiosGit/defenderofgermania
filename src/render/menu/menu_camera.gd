class_name MenuCamera
extends Camera3D
## Camera of the main menu: it glides slowly and endlessly over the war table on a closed
## loop and looks a little west of what it shows, so the realm fills the right of the screen
## beside the menu's text. It never reads input.

const PITCH_DEG := 40.0
const FOV := 34.0
const DISTANCE := 92.0
## The camera breathes in and out by this share of its distance.
const DISTANCE_SWAY := 0.07
const YAW_SWAY_DEG := 7.0
## Seconds for one lap of the look point; turn and distance repeat every LAPS_PER_LOOP laps.
const LAP_SECONDS := 150.0
const LAPS_PER_LOOP := 2
const LOOP_SECONDS := LAP_SECONDS * LAPS_PER_LOOP
## Share of the realm's half size the look point travels from the lap's centre.
const REACH := Vector2(0.30, 0.28)
## The lap's centre lies west of the realm's by this share of the realm's width.
const WEST_SHIFT := 0.36

var _centre := Vector2.ZERO
var _reach := Vector2.ZERO
var _ground := 0.0
var _time := 0.0


## realm: the provinces' area on the table (x, z); ground: height of the fields.
func setup(realm: Rect2, ground: float) -> void:
	_centre = realm.get_center() - Vector2(realm.size.x * WEST_SHIFT, 0.0)
	_reach = realm.size * 0.5 * REACH
	_ground = ground
	fov = FOV
	near = 0.5
	far = 2000.0
	_place()


func _process(delta: float) -> void:
	drift(delta)


## Moves the camera on by `delta` seconds.
func drift(delta: float) -> void:
	_time = fmod(_time + delta, LOOP_SECONDS)
	_place()


## Table point (x, z) in the middle of the view.
func look_point() -> Vector2:
	var lap := TAU * _time / LAP_SECONDS
	return _centre + Vector2(cos(lap), sin(lap)) * _reach


func _place() -> void:
	var sway := TAU * _time / LOOP_SECONDS
	var yaw := deg_to_rad(YAW_SWAY_DEG) * sin(sway)
	var pitch := deg_to_rad(PITCH_DEG)
	var away := DISTANCE * (1.0 + DISTANCE_SWAY * cos(sway))
	var level := cos(pitch) * away
	var look := look_point()
	position = Vector3(
		look.x + sin(yaw) * level, _ground + sin(pitch) * away, look.y + cos(yaw) * level
	)
	rotation = Vector3(-pitch, yaw, 0.0)
