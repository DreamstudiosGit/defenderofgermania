class_name HouseState
extends RefCounted
## Per-house resources, economy levers and the house's leader.

const NO_ARMY := -1

var id: String
var gold: float
var grain: float
var prestige: float
var tax_rate: int
var ration: int
var home_province: String
var decorations: Array[String] = []
var is_banned: bool = false
var leadership: int = 0
var lance: int = 0
var blade: int = 0
## Army the leader rides with; NO_ARMY while at the home castle or captured.
var leader_army: int = NO_ARMY
## Owner holding the leader captive ("" while free): a house id or a non-house owner.
var leader_captor: String = ""
## One-off prestige changes (battles) collected until the next settlement.
var pending_prestige: float = 0.0
## Settlements left to win a new home castle; 0 while the house holds one.
var exile_rounds: int = 0
var is_eliminated: bool = false
## Round of the house's last adventure (joust, castle raid, merchant train): one a round.
var adventure_turn: int = -1
## First round in which a leader wounded on a castle raid gives his aura again.
var wounded_until: int = 0


static func from_dict(r: DataReader, data: Dictionary) -> HouseState:
	var house := HouseState.new()
	house.id = r.text(data, "id")
	house.gold = r.number(data, "gold")
	house.grain = r.number(data, "grain")
	house.prestige = r.number(data, "prestige")
	house.tax_rate = r.integer(data, "tax_rate")
	house.ration = r.integer(data, "ration")
	house.home_province = r.text(data, "home_province")
	house.decorations = r.strings(data, "decorations")
	house.is_banned = r.flag(data, "banned")
	var leader := r.object(data, "leader")
	house.leadership = r.integer(leader, "leadership")
	house.lance = r.integer(leader, "lance")
	house.blade = r.integer(leader, "blade")
	house.leader_army = r.integer(leader, "army")
	house.leader_captor = r.text(leader, "captor")
	house.pending_prestige = r.number(data, "pending_prestige")
	house.exile_rounds = r.integer(data, "exile_rounds")
	house.is_eliminated = r.flag(data, "eliminated")
	house.adventure_turn = r.integer(data, "adventure_turn")
	house.wounded_until = r.integer(data, "wounded_until")
	return house


func is_leader_captured() -> bool:
	return not leader_captor.is_empty()


func to_dict() -> Dictionary:
	var leader := {
		"leadership": leadership,
		"lance": lance,
		"blade": blade,
		"army": leader_army,
		"captor": leader_captor,
	}
	return {
		"id": id,
		"gold": gold,
		"grain": grain,
		"prestige": prestige,
		"tax_rate": tax_rate,
		"ration": ration,
		"home_province": home_province,
		"decorations": decorations,
		"banned": is_banned,
		"leader": leader,
		"pending_prestige": pending_prestige,
		"exile_rounds": exile_rounds,
		"eliminated": is_eliminated,
		"adventure_turn": adventure_turn,
		"wounded_until": wounded_until,
	}
