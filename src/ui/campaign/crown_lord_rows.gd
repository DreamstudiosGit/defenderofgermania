class_name CrownLordRows
extends RefCounted
## The realm tab's rows for the electors and the neutral secular lords: the house's favour on a
## bar with the thresholds that matter and the best rival, how an elector votes and why, and
## the gift, embassy and homage buttons. The section owns the buttons and emits their commands.

## The gift's caption (cost and gain) is longer than the embassy's next to it.
const GIFT_STRETCH := 1.1


## One row per elector, in data order.
static func show_electors(
	section: AdministrationSection,
	parent: VBoxContainer,
	state: GameState,
	map: MapData,
	house: String
) -> void:
	var crown := map.crown
	var votes := CrownRules.votes(state, map)
	for id: String in map.electors():
		var row := _row(parent, id, CampaignFormat.owner_name(map.provinces[id].owner, id))
		var marks := PackedFloat32Array([crown.vote_threshold])
		var hints := PackedStringArray([
			CampaignFormat.t("CAMPAIGN_CROWN_MARK_VOTE") % CrownFormat.amount(crown.vote_threshold)
		])
		if id in crown.archbishops.values():
			marks.append(crown.archbishop_min_favour)
			hints.append(
				CampaignFormat.t("CAMPAIGN_CROWN_MARK_CROWNS")
				% CrownFormat.amount(crown.archbishop_min_favour)
			)
		_show_favour(row, state, map, id, house, marks, " · ".join(hints))
		(row.get_node("head/church") as Label).visible = map.provinces[id].is_church
		var vote := row.get_node("vote") as Label
		vote.text = CrownFormat.vote(state, map, id, house, votes[id])
		vote.add_theme_color_override("font_color", _vote_color(votes[id], house))
		var actions := row.get_node("actions") as HBoxContainer
		_offer_gift(section, actions, state, map, id, house)
		_offer_embassy(section, actions, state, map, id, house)


## One row per neutral secular lord who is still his own master.
static func show_lords(
	section: AdministrationSection,
	parent: VBoxContainer,
	state: GameState,
	map: MapData,
	house: String
) -> void:
	var crown := map.crown
	var keep: Array[String] = []
	for def: MapData.ProvinceDef in map.provinces.values():
		var is_lord := def.owner == CrownRules.NEUTRAL and CrownRules.keeps_favour(map, def.id)
		if not is_lord or state.provinces[def.id].owner != CrownRules.NEUTRAL:
			continue
		var id := def.id
		keep.append("lord_" + id)
		var row := _row(parent, id, CampaignFormat.province_name(id))
		var hint := CampaignFormat.t("CAMPAIGN_CROWN_MARK_HOMAGE") % CrownFormat.amount(
			crown.homage_threshold
		)
		var marks := PackedFloat32Array([crown.homage_threshold])
		_show_favour(row, state, map, id, house, marks, hint)
		var ready := state.crown.favour_of(id, house) >= crown.homage_threshold
		var status := row.get_node("vote") as Label
		status.text = CampaignFormat.t("CAMPAIGN_CROWN_HOMAGE_READY")
		status.add_theme_color_override("font_color", CampaignStyle.GOOD)
		status.visible = ready
		var actions := row.get_node("actions") as HBoxContainer
		_offer_gift(section, actions, state, map, id, house)
		var buttons: Array[String] = ["gift_" + id]
		if ready:
			buttons.append("homage_" + id)
			var homage := HomageCommand.new(map, house, id)
			var caption := CampaignFormat.t("CAMPAIGN_CROWN_HOMAGE") % CrownFormat.amount(
				crown.homage_cost
			)
			var details := CampaignFormat.t("CAMPAIGN_CROWN_HOMAGE_HINT") % (
				CampaignFormat.province_name(id)
			)
			section.offer(_action(section, actions, "homage_" + id), caption, homage, state, details)
		section.prune(actions, buttons)
	var none: Array[String] = []
	for row: Node in parent.get_children():
		if row is VBoxContainer and String(row.name) not in keep:
			section.prune(row.get_node("actions") as HBoxContainer, none)
			parent.remove_child(row)
			row.queue_free()


## The row of the lord of province id, created on first use: name and church mark, favour
## with its bar and the best rival, the vote or homage status, and the action buttons.
static func _row(parent: VBoxContainer, id: String, title: String) -> VBoxContainer:
	var existing := parent.get_node_or_null(NodePath("lord_" + id))
	if existing is VBoxContainer:
		return existing
	var row := VBoxContainer.new()
	row.name = "lord_" + id
	row.add_theme_constant_override("separation", 3)
	var head := _line(row, "head", 8)
	_named(head, CampaignStyle.label(title), "title")
	var church := CampaignStyle.label(
		CampaignFormat.t("CAMPAIGN_CROWN_CHURCH"), CampaignStyle.SMALL_SIZE, CampaignStyle.GOLD
	)
	church.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	church.visible = false
	_named(head, church, "church")
	var favour := _line(row, "favour_line", 8)
	_named(favour, CampaignStyle.label("", CampaignStyle.SMALL_SIZE), "favour")
	_named(favour, FavourBar.new(), "bar")
	_named(favour, CampaignStyle.label("", CampaignStyle.SMALL_SIZE), "rival")
	_named(row, CampaignStyle.paragraph(), "vote")
	_line(row, "actions", 6)
	parent.add_child(row)
	return row


static func _line(row: VBoxContainer, key: String, separation: int) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", separation)
	_named(row, line, key)
	return line


static func _named(parent: Container, child: Control, key: String) -> void:
	child.name = key
	parent.add_child(child)


static func _show_favour(
	row: VBoxContainer,
	state: GameState,
	map: MapData,
	id: String,
	house: String,
	marks: PackedFloat32Array,
	thresholds: String
) -> void:
	var value := state.crown.favour_of(id, house)
	var rival := CrownFormat.rival(state, id, house)
	var tooltip := "%s\n%s" % [CrownFormat.favour_list(state, id), thresholds]
	var favour := row.get_node("favour_line/favour") as Label
	favour.text = CampaignFormat.t("CAMPAIGN_CROWN_FAVOUR") % CrownFormat.amount(value)
	favour.add_theme_color_override("font_color", CampaignFormat.owner_color(map, house))
	var bar := row.get_node("favour_line/bar") as FavourBar
	bar.color = CampaignFormat.owner_color(map, house)
	bar.show_favour(value, map.crown.favour_max, marks)
	var rival_label := row.get_node("favour_line/rival") as Label
	rival_label.visible = not rival.is_empty()
	if not rival.is_empty():
		var rival_favour := state.crown.favour_of(id, rival)
		rival_label.text = CampaignFormat.t("CAMPAIGN_CROWN_RIVAL") % [
			CampaignFormat.house_name(rival), CrownFormat.amount(rival_favour)
		]
		bar.show_rival(rival_favour, CampaignFormat.owner_color(map, rival))
	for part: Control in [favour, bar, rival_label, row.get_node("head/title") as Control]:
		part.tooltip_text = tooltip


static func _offer_gift(
	section: AdministrationSection,
	actions: HBoxContainer,
	state: GameState,
	map: MapData,
	id: String,
	house: String
) -> void:
	var multiplier: float = map.crown.house_favour_multiplier.get(house, 1.0)
	var gain := CrownRules.gift_favour(state, map, id, house) * multiplier
	var caption := CampaignFormat.t("CAMPAIGN_CROWN_GIFT") % [
		CrownFormat.amount(CrownRules.gift_cost(map, house)), CrownFormat.amount(gain)
	]
	var details := "%s\n%s" % [
		CampaignFormat.t("CAMPAIGN_CROWN_GIFT_HINT") % [
			CrownFormat.amount(gain), CrownFormat.amount(map.crown.gift_repeat_penalty * multiplier)
		],
		CrownFormat.favour_list(state, id),
	]
	var gift := _action(section, actions, "gift_" + id, GIFT_STRETCH)
	section.offer(gift, caption, GiftCommand.new(map, house, id), state, details)


static func _offer_embassy(
	section: AdministrationSection,
	actions: HBoxContainer,
	state: GameState,
	map: MapData,
	id: String,
	house: String
) -> void:
	var crown := map.crown
	var strength: float = state.crown.patron_strength.get(CrownRules.patron_of(map, house), 1.0)
	var multiplier: float = crown.house_favour_multiplier.get(house, 1.0)
	var gain := crown.patron_embassy_favour * strength * multiplier
	var caption := "%s · +%s" % [
		CampaignFormat.t("PATRON_CARD_" + PlayPatronCommand.EMBASSY.to_upper()),
		CrownFormat.amount(gain),
	]
	var details := CampaignFormat.t("CAMPAIGN_CROWN_EMBASSY_HINT") % CrownFormat.amount(gain)
	var command := PlayPatronCommand.new(map, house, PlayPatronCommand.EMBASSY, id)
	section.offer(_action(section, actions, "embassy_" + id), caption, command, state, details)


## A narrow action button sharing its line; it wraps its caption rather than widen the tab.
static func _action(
	section: AdministrationSection, actions: HBoxContainer, key: String, stretch: float = 1.0
) -> Button:
	var target := section.button(actions, key)
	target.theme_type_variation = CampaignStyle.CHOICE
	target.size_flags_stretch_ratio = stretch
	target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return target


static func _vote_color(voted: String, house: String) -> Color:
	if voted == house:
		return CampaignStyle.GOOD
	return CampaignStyle.MUTED if voted.is_empty() else CampaignStyle.BAD
