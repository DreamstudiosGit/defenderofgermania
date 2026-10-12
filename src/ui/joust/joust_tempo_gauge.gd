class_name JoustTempoGauge
extends Control
## Run-up gauge: one pip per beat of the gait that pulses as the beat comes (green when spurred
## on it, dark when missed), and the tempo bar with the ideal mark; above it the lance sways
## harder, below it the hit lands softer.

const PIP := 9.0
const BAR_HEIGHT := 14.0
const GOLD := Color(1.0, 0.82, 0.3)
const INK := Color(0.08, 0.06, 0.05, 0.9)
const GOOD := Color(0.45, 0.85, 0.35)
const TOO_FAST := Color(0.95, 0.45, 0.2)
const FLASH_SECONDS := 0.35

var _beats := PackedByteArray()
var _beat_times := PackedFloat64Array()
var _time: float = 0.0
var _tempo: float = 0.0
var _ideal: float = 1.0
var _max: float = 1.0
var _window: float = 0.1
var _flash: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(380, 64)


func show_tempo(
	rider: JoustRider, sim: JoustSim, time: float
) -> void:
	_beats = rider.spurred
	_beat_times.resize(_beats.size())
	for b: int in _beats.size():
		_beat_times[b] = sim.beat_time(b)
	_time = time
	_tempo = rider.tempo
	_ideal = sim.cfg.tempo_ideal
	_max = sim.cfg.tempo_max
	_window = sim.cfg.beat_window_ms / 1000.0
	queue_redraw()


func off_beat() -> void:
	_flash = FLASH_SECONDS


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		queue_redraw()


func _draw() -> void:
	var width := size.x
	var count := _beats.size()
	for b: int in count:
		var at := Vector2(width * (b + 0.5) / maxi(count, 1), PIP + 2.0)
		var near := absf(_time - _beat_times[b])
		var pulse := clampf(1.0 - near / (_window * 2.5), 0.0, 1.0)
		var color := Color(1, 1, 1, 0.25 + 0.75 * pulse)
		if _beats[b] == 1:
			color = GOOD
		elif _time > _beat_times[b] + _window:
			color = Color(0.25, 0.22, 0.2)
		draw_circle(at, PIP + 2.0 + pulse * 4.0, INK)
		draw_circle(at, PIP + pulse * 4.0, color)
	var top := PIP * 2.0 + 18.0
	var bar := Rect2(0.0, top, width, BAR_HEIGHT)
	draw_rect(bar.grow(2.0), INK)
	draw_rect(bar, Color(0.2, 0.17, 0.14))
	var share := clampf(_tempo / _max, 0.0, 1.0)
	var fill := GOOD if _tempo <= _ideal + 0.001 else TOO_FAST
	if _flash > 0.0:
		fill = fill.lerp(Color(1, 0.2, 0.15), _flash / FLASH_SECONDS)
	draw_rect(Rect2(bar.position, Vector2(width * share, BAR_HEIGHT)), fill)
	var ideal_x := width * _ideal / _max
	draw_line(Vector2(ideal_x, top - 6.0), Vector2(ideal_x, top + BAR_HEIGHT + 6.0), GOLD, 3.0)
