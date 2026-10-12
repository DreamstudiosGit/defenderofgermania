class_name BattleChoice
extends Control
## Before a battle: attacker against defender (companies, health, leader, strength K), the
## battlefield and the auto-resolve win chance; the player fights it out live or lets it be
## auto-resolved. Emits chosen(play_live).

signal chosen(play_live: bool)

var _title := CampaignStyle.heading("", 30)
var _field := CampaignStyle.label("", CampaignStyle.SMALL_SIZE + 1, CampaignStyle.MUTED)
var _sides := HBoxContainer.new()
var _chance := ProgressBar.new()
var _chance_label := CampaignStyle.label()
var _live := CampaignStyle.modal_button("")
var _auto := CampaignStyle.modal_button("")


func _init() -> void:
	var column := CampaignStyle.modal(self, Color(0.0, 0.0, 0.0, 0.6))
	for label: Label in [_title, _field]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
	_sides.add_theme_constant_override("separation", 40)
	column.add_child(_sides)
	_chance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_chance_label)
	_chance.max_value = 1.0
	_chance.show_percentage = false
	_chance.custom_minimum_size = Vector2(420, 16)
	_chance.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_chance)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	column.add_child(buttons)
	_live.name = "live"
	_live.text = tr("CAMPAIGN_BATTLE_LIVE")
	_live.pressed.connect(_choose.bind(true))
	buttons.add_child(_live)
	_auto.name = "auto"
	_auto.text = tr("CAMPAIGN_BATTLE_AUTO")
	_auto.pressed.connect(_choose.bind(false))
	buttons.add_child(_auto)
	visible = false


## Shows the battle in province_id; focuses "fight yourself".
func open(setup: BattleSetup, rules: GameRules, province_id: String) -> void:
	_title.text = tr("CAMPAIGN_BATTLE_TITLE") % CampaignFormat.province_name(province_id)
	var field := PackedStringArray([tr("CAMPAIGN_TERRAIN_" + setup.terrain.to_upper())])
	if setup.defender_wall > 0:
		field.append(tr("CAMPAIGN_BATTLE_WALL") % setup.defender_wall)
	if setup.is_winter:
		field.append(tr("CAMPAIGN_BATTLE_WINTER"))
	_field.text = " · ".join(field)
	var strength := AutoResolve.strengths(rules.combat, setup)
	for child: Node in _sides.get_children():
		_sides.remove_child(child)
		child.queue_free()
	_sides.add_child(_side(rules, setup.attacker, tr("BATTLE_ROLE_ATTACKER"), strength[0]))
	_sides.add_child(_side(rules, setup.defender, tr("BATTLE_ROLE_DEFENDER"), strength[1]))
	var chance := AutoResolve.win_chance(rules.combat, strength[0], strength[1])
	if setup.defender.company_count() == 0 and not setup.defender.has_leader:
		chance = 1.0
	_chance.value = chance
	_chance_label.text = tr("CAMPAIGN_BATTLE_CHANCE") % CampaignFormat.percent(chance)
	_chance_label.tooltip_text = tr("CAMPAIGN_BATTLE_CHANCE_HINT")
	visible = true
	_live.grab_focus()


func _side(rules: GameRules, side: BattleSide, role: String, strength: float) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 250
	var name := CampaignStyle.heading(CampaignFormat.owner_name(side.owner), 22)
	name.add_theme_color_override("font_color", CampaignFormat.owner_color(rules.map, side.owner))
	column.add_child(name)
	column.add_child(CampaignStyle.label(role, CampaignStyle.SMALL_SIZE, CampaignStyle.MUTED))
	var counts: Dictionary[String, int] = {}
	var health: Dictionary[String, float] = {}
	for i: int in side.company_count():
		counts[side.units[i]] = counts.get(side.units[i], 0) + 1
		health[side.units[i]] = health.get(side.units[i], 0.0) + side.health[i]
	if counts.is_empty():
		column.add_child(CampaignStyle.label(tr("CAMPAIGN_BATTLE_NO_TROOPS")))
	for unit: String in counts:
		column.add_child(CampaignStyle.label(tr("CAMPAIGN_BATTLE_COMPANIES") % [
			counts[unit],
			CampaignFormat.unit_name(unit),
			CampaignFormat.percent(health[unit] / counts[unit]),
		]))
	if side.has_leader:
		column.add_child(CampaignStyle.label(tr("CAMPAIGN_BATTLE_LEADER") % side.leadership))
	var power := CampaignStyle.label(
		tr("CAMPAIGN_BATTLE_STRENGTH") % CampaignFormat.number(strength, 1),
		CampaignStyle.SMALL_SIZE,
		CampaignStyle.MUTED
	)
	column.add_child(power)
	return column


func _choose(play_live: bool) -> void:
	visible = false
	chosen.emit(play_live)
