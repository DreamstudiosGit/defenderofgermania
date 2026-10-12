class_name JoustSetup
extends RefCounted
## What the campaign passes into a joust. Rider 0 is the player's house, rider 1 the opponent.
## Rewards (prize, prestige, favour, a fief changing hands) are the caller's business.

const DEFAULT_HOUSE := "staufer"
const DEFAULT_OPPONENT := "welfen"
const DEFAULT_LANCE := 2
const DEFAULT_SKILL := 1

var house: String = DEFAULT_HOUSE
var lance: int = DEFAULT_LANCE
## Owner id of the opponent: a house id, "elector" or "neutral".
var opponent: String = DEFAULT_OPPONENT
var opponent_lance: int = DEFAULT_LANCE
## Error pattern of the computer opponent, 0 (clumsy) to 3 (champion).
var opponent_skill: int = DEFAULT_SKILL
## Province of the tournament's host, "" when nobody hosts (fief joust, practice).
var host_province: String = ""
var practice: bool = false


static func practice_default() -> JoustSetup:
	var setup := JoustSetup.new()
	setup.practice = true
	return setup


## Riders' owner ids in rider order.
func owners() -> Array[String]:
	return [house, opponent]


func lances() -> PackedInt32Array:
	return PackedInt32Array([maxi(lance, 0), maxi(opponent_lance, 0)])
