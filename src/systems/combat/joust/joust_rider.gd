class_name JoustRider
extends RefCounted
## One rider in a joust. Positions live in the target plane: metres from the opponent's chest
## as this rider sees him (x right, y up).

var owner: String
var lance: int
## Half-width of the perfect hit window in seconds.
var window: float
var sway_scale: float
var stance: float
var points: int = 0
var unseated: bool = false

## Pass state, reset when a run-up starts.
var tempo: float
var hand := Vector2.ZERO
var aim_target := Vector2.ZERO
var tip := Vector2.ZERO
var shield := Vector2.ZERO
var spurred := PackedByteArray()
var last_spur_on_beat: bool = false
## Seconds from the impact to the couching press (negative: early); NAN until pressed.
var strike_offset: float = NAN
var impact_tip := Vector2.ZERO
var impact_shield := Vector2.ZERO

## Outcome of this rider's last attack and of the lance that hit him.
var last_zone: int = -1
var last_couched: bool = false
var last_perfect: bool = false
var last_damage_taken: float = 0.0
var last_shielded: bool = false


func reset_pass(tempo_start: float, rest: Vector2, beats: int) -> void:
	tempo = tempo_start
	hand = rest
	aim_target = rest
	tip = rest
	shield = Vector2.ZERO
	spurred.resize(beats)
	spurred.fill(0)
	last_spur_on_beat = false
	strike_offset = NAN
	impact_tip = rest
	impact_shield = Vector2.ZERO
	last_zone = -1
	last_couched = false
	last_perfect = false
	last_damage_taken = 0.0
	last_shielded = false
