class_name MerchantResult
extends RefCounted
## Outcome of a merchant train raid. Applying it (taler, a captured leader) is up to the
## campaign; the raid's prestige and Cologne's favour come from the event card.

var wagons_total: int = 0
var wagons_stopped: int = 0
## Cargo of the stopped wagons; nothing if the escorts captured the leader.
var taler: int = 0
var leader_captured: bool = false
## Seconds from the start of the chase to its end, without the intro.
var seconds: float = 0.0
