class_name AdventureChoice
extends Control
## Before an adventure: its name and what is at stake; the player plays the minigame live or
## lets the computer play the house's side. Emits chosen(play_live).

signal chosen(play_live: bool)

var _title := CampaignStyle.heading("", 30)
var _text := CampaignStyle.paragraph("", CampaignStyle.FONT_SIZE)
var _live := CampaignStyle.modal_button("")
var _auto := CampaignStyle.modal_button("")


func _init() -> void:
	var column := CampaignStyle.modal(self, Color(0.0, 0.0, 0.0, 0.6))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_text.custom_minimum_size.x = 520
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_text)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	column.add_child(buttons)
	_live.name = "live"
	_live.text = tr("CAMPAIGN_ADVENTURE_LIVE")
	_live.pressed.connect(_choose.bind(true))
	buttons.add_child(_live)
	_auto.name = "auto"
	_auto.text = tr("CAMPAIGN_ADVENTURE_AUTO")
	_auto.tooltip_text = tr("CAMPAIGN_ADVENTURE_AUTO_HINT")
	_auto.pressed.connect(_choose.bind(false))
	buttons.add_child(_auto)
	visible = false


## Shows the adventure (EVENT_ADVENTURE_<ID> and CAMPAIGN_ADVENTURE_<ID>_HINT); focuses
## "play it yourself".
func open(adventure: String) -> void:
	_title.text = tr("EVENT_ADVENTURE_" + adventure.to_upper())
	_text.text = tr("CAMPAIGN_ADVENTURE_%s_HINT" % adventure.to_upper())
	visible = true
	_live.grab_focus()


func _choose(play_live: bool) -> void:
	visible = false
	chosen.emit(play_live)
