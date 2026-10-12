class_name MerchantGauges
extends Control
## The leader's gauges, drawn: composure pips and crossbow bolts with the reload bar (bottom
## left), and — bottom centre — the pull progress or the crossbow's sway needle over the band
## in which a bolt cuts the harness.

const PIP := Color(0.95, 0.85, 0.6)
const PIP_EMPTY := Color(0.3, 0.25, 0.2, 0.8)
const BOLT := Color(0.9, 0.75, 0.45)
const BAND := Color(0.45, 0.8, 0.35)
const NEEDLE := Color(1.0, 0.96, 0.88)
const FRAME := Color(0.12, 0.08, 0.05, 0.85)
const PANEL := Vector2(260.0, 96.0)
const GAUGE := Vector2(360.0, 26.0)

var _sim: MerchantSim
var _labels := PackedStringArray()


func setup(sim: MerchantSim) -> void:
	_sim = sim
	_labels = PackedStringArray([tr("MERCHANT_COMPOSURE"), tr("MERCHANT_CROSSBOW")])
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if _sim != null and is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	if _sim == null or _sim.state.phase != MerchantState.Phase.RAID:
		return
	var s := _sim.state
	var font := get_theme_default_font()
	var corner := Vector2(24.0, size.y - PANEL.y - 24.0)
	draw_rect(Rect2(corner, PANEL), FRAME)
	draw_string(font, corner + Vector2(12, 26), _labels[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	for i: int in _sim.cfg.composure:
		var center := corner + Vector2(130.0 + i * 24.0, 20.0)
		draw_circle(center, 9.0, PIP if i < s.composure else PIP_EMPTY)
	draw_string(font, corner + Vector2(12, 66), _labels[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	for i: int in _sim.cfg.bolts:
		var foot := corner + Vector2(130.0 + i * 16.0, 74.0)
		var color := BOLT if i < s.bolts else PIP_EMPTY
		draw_line(foot, foot + Vector2(6.0, -20.0), color, 4.0)
	if s.reload > 0.0 and s.bolts > 0:
		var share := 1.0 - s.reload / _sim.cfg.reload_seconds
		var bar := Rect2(corner + Vector2(186.0, 58.0), Vector2(60.0, 10.0))
		draw_rect(bar, PIP_EMPTY)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), BOLT)
	_draw_action(font)


func _draw_action(font: Font) -> void:
	var s := _sim.state
	var origin := Vector2((size.x - GAUGE.x) * 0.5, size.y - 64.0)
	var rect := Rect2(origin, GAUGE)
	if s.pull_wagon >= 0:
		draw_rect(rect.grow(4.0), FRAME)
		var share := clampf(s.pull_progress / _sim.cfg.pull_seconds, 0.0, 1.0)
		draw_rect(Rect2(origin, Vector2(GAUGE.x * share, GAUGE.y)), PIP)
		return
	var aimed := s.reload <= 0.0 and s.bolts > 0 and _sim.crossbow_target() >= 0
	if not aimed:
		return
	draw_rect(rect.grow(4.0), FRAME)
	var center := origin.x + GAUGE.x * 0.5
	var half := GAUGE.x * 0.5
	var band := _sim.cfg.hit_window * half
	draw_rect(Rect2(center - band, origin.y, band * 2.0, GAUGE.y), BAND)
	var needle := center + clampf(_sim.sway(), -1.0, 1.0) * half
	draw_rect(Rect2(needle - 3.0, origin.y - 8.0, 6.0, GAUGE.y + 16.0), NEEDLE)
	draw_string(font, origin + Vector2(0.0, -14.0), tr("MERCHANT_PROMPT_AIM"),
		HORIZONTAL_ALIGNMENT_CENTER, GAUGE.x, 16)
