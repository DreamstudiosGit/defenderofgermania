class_name CrownState
extends RefCounted
## The road to the crown in a running game: where the true regalia lie, who forged them, the
## favour of every elector and neutral lord, patron cards, gifts of the year, penance and the
## promised Bohemian vote. Part of the save (GameState.to_dict).

## Province whose owner holds the true regalia (Trifels at the start).
var regalia_province: String = ""
## Houses that hold forged regalia.
var forged_regalia: Array[String] = []
## Favour of a lord (elector or neutral province) towards a house, keyed "<PROVINCE>:<house>".
var favour: Dictionary[String, float] = {}
## Patron cards a house has left, and the round it last played one.
var patron_cards: Dictionary[String, int] = {}
var patron_played: Dictionary[String, int] = {}
## Strength of a patron power's cards (england, france); 1 is full.
var patron_strength: Dictionary[String, float] = {}
## Gifts a house gave a lord this year, keyed "<PROVINCE>:<house>"; cleared every spring.
var gifts: Dictionary[String, int] = {}
## Round in which a house did penance; it may not campaign in that round.
var penance_turn: Dictionary[String, int] = {}
## House the King of Bohemia promised his vote (event "Böhmische Königswürde"), or "".
var bohemia_promised: String = ""


static func key(province_id: String, house: String) -> String:
	return "%s:%s" % [province_id, house]


func favour_of(province_id: String, house: String) -> float:
	return favour.get(key(province_id, house), 0.0)


func set_favour(province_id: String, house: String, value: float, maximum: float) -> void:
	favour[key(province_id, house)] = clampf(value, 0.0, maximum)


static func from_dict(r: DataReader, data: Dictionary) -> CrownState:
	var crown := CrownState.new()
	crown.regalia_province = r.text(data, "regalia_province")
	crown.forged_regalia = r.strings(data, "forged_regalia")
	crown.bohemia_promised = r.text(data, "bohemia_promised")
	var favour_data := r.object(data, "favour")
	for id: String in favour_data:
		crown.favour[id] = r.number(favour_data, id)
	var strength := r.object(data, "patron_strength")
	for id: String in strength:
		crown.patron_strength[id] = r.number(strength, id)
	for field: String in ["patron_cards", "patron_played", "gifts", "penance_turn"]:
		var counts := r.object(data, field)
		var target: Dictionary[String, int] = crown.get(field)
		for id: String in counts:
			target[id] = r.integer(counts, id, 0)
	return crown


func to_dict() -> Dictionary:
	return {
		"regalia_province": regalia_province,
		"forged_regalia": forged_regalia,
		"favour": favour,
		"patron_cards": patron_cards,
		"patron_played": patron_played,
		"patron_strength": patron_strength,
		"gifts": gifts,
		"penance_turn": penance_turn,
		"bohemia_promised": bohemia_promised,
	}
