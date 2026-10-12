class_name JoustInput
extends RefCounted
## One rider's input for one joust tick, device independent. The simulation validates every
## field, so the computer, local players and replays share this path.

const NO_PRESS := -1.0

## Where the lance hand should go, -1..1 per axis of the aim range (x right, y up).
var aim := Vector2.ZERO
## Shield direction in the rider's own view (x right, y up), length up to 1; zero holds it still.
var shield := Vector2.ZERO
## A spur press during this tick, as the fraction (0..1) of the tick when it happened.
var spur: float = NO_PRESS
## Couching the lance for the impact, as a fraction of the tick like spur.
var strike: float = NO_PRESS
