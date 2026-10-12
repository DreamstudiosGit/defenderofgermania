class_name RaidSection
extends VBoxContainer
## Castle raid in the province panel: when the active house's leader can reach this foreign
## castle in the campaign phase, one button per target it holds (CastleRaidCommand); a refused
## raid says why in its tooltip.

signal command_requested(command: Command)

var _buttons := VBoxContainer.new()


func _init() -> void:
	add_theme_constant_override("separation", 4)
	add_child(HSeparator.new())
	add_child(CampaignStyle.heading(tr("CAMPAIGN_RAID"), 18))
	_buttons.add_theme_constant_override("separation", 4)
	add_child(_buttons)
	visible = false


func refresh(state: GameState, rules: GameRules, house: String, province_id: String) -> void:
	for child: Node in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	visible = (
		state.phase == GameState.Phase.CAMPAIGN
		and state.active_house() == house
		and province_id in CastleRaids.castles(state, rules, house)
	)
	if not visible:
		return
	for target: String in CastleRaids.targets(state, province_id):
		var command := CastleRaidCommand.new(rules, house, province_id, target)
		var button := Button.new()
		button.name = "raid_" + target
		button.text = tr("CAMPAIGN_RAID_" + target.to_upper())
		var error := command.validate(state)
		button.disabled = not error.is_empty()
		var hint := tr("CAMPAIGN_RAID_%s_HINT" % target.to_upper())
		button.tooltip_text = tr(error) if not error.is_empty() else hint
		button.pressed.connect(func() -> void: command_requested.emit(command))
		_buttons.add_child(button)
