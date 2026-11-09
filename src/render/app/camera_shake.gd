class_name CameraShake
extends RefCounted
## Screen shake for any Camera3D: hits add trauma, which fades on its own; the offset grows
## with the square of the trauma, so small hits stay subtle. It moves the camera's
## h_offset / v_offset only, so the scene's own camera code and its picking rays are left
## alone. The player's "screen shake" option scales it down to nothing.

const DECAY_PER_SECOND := 1.8
const FREQUENCY := 26.0

var _trauma := 0.0
var _time := 0.0
var _noise := FastNoiseLite.new()


func _init() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 1.0


## Adds trauma: 0.2 a nudge, 0.5 a heavy hit, 1 the most.
func add(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func is_shaking() -> bool:
	return _trauma > 0.0


## Call every frame; `reach` is the largest offset in the camera's units (metres), so pass a
## share of what the camera sees.
func apply(camera: Camera3D, delta: float, reach: float) -> void:
	_time += delta
	_trauma = maxf(0.0, _trauma - DECAY_PER_SECOND * delta)
	var power := _trauma * _trauma * reach * App.shake_scale()
	camera.h_offset = power * _noise.get_noise_1d(_time * FREQUENCY)
	camera.v_offset = power * _noise.get_noise_1d(_time * FREQUENCY + 97.0)
