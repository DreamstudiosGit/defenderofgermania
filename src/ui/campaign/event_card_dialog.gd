class_name EventCardDialog
extends Control
## The event phase of a human house: the round's news, its cards that already acted and the
## card waiting for a choice, one button per choice; a refused choice says why under the
## buttons and in its tooltip. Emits choice_requested(choice) and, once nothing waits, closed.

signal choice_requested(choice: String)
signal closed

const WIDTH := 640.0

var _title := CampaignStyle.heading("", 30)
var _entries := VBoxContainer.new()
var _choices := HFlowContainer.new()
var _notes := CampaignStyle.paragraph()
var _continue := CampaignStyle.modal_button("")


func _init() -> void:
	var column := CampaignStyle.modal(self, Color(0.0, 0.0, 0.0, 0.6))
	column.custom_minimum_size.x = WIDTH
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_entries.add_theme_constant_override("separation", 14)
	column.add_child(_entries)
	_choices.alignment = FlowContainer.ALIGNMENT_CENTER
	_choices.add_theme_constant_override("h_separation", 16)
	_choices.add_theme_constant_override("v_separation", 10)
	column.add_child(_choices)
	_notes.custom_minimum_size.x = WIDTH
	_notes.add_theme_color_override("font_color", CampaignStyle.MUTED)
	column.add_child(_notes)
	_continue.name = "continue"
	_continue.text = tr("CAMPAIGN_EVENTS_CONTINUE")
	_continue.pressed.connect(_on_continue_pressed)
	column.add_child(_continue)
	visible = false


## Shows what the house's event phase holds and focuses the first possible choice (or
## "continue" when nothing waits).
func open(state: GameState, rules: GameRules, house: String) -> void:
	_title.text = tr("CAMPAIGN_EVENTS_TITLE") % CampaignFormat.house_name(house)
	_title.add_theme_color_override("font_color", CampaignFormat.owner_color(rules.map, house))
	_clear(_entries)
	_clear(_choices)
	var news := EventFormat.grouped(state.events.news)
	if not news.is_empty():
		_entries.add_child(CampaignStyle.heading(tr("CAMPAIGN_EVENTS_REALM"), 18))
	for entry: Dictionary in news:
		var places: PackedStringArray = entry["places"]
		_add_entry(entry["event"], ", ".join(places), "")
	var pending := state.events.next_pending()
	var answered := state.events.drawn.filter(
		func(card: EventState.EventCard) -> bool: return card != pending and card.house == house
	)
	if not answered.is_empty():
		_entries.add_child(CampaignStyle.heading(tr("CAMPAIGN_EVENTS_HOUSE"), 18))
	for card: EventState.EventCard in answered:
		_add_entry(card.event, EventFormat.place(card), EventFormat.outcome(card, rules.events))
	_notes.text = ""
	_continue.visible = pending == null
	if pending != null:
		_entries.add_child(CampaignStyle.heading(tr("CAMPAIGN_EVENTS_CHOOSE"), 18))
		_add_entry(pending.event, EventFormat.place(pending), "")
		_offer_choices(state, rules, pending)
	visible = true
	_focus_first()


func _offer_choices(state: GameState, rules: GameRules, card: EventState.EventCard) -> void:
	var notes := PackedStringArray()
	for choice: EventData.ChoiceDef in rules.events.events[card.event].choices:
		var button := Button.new()
		button.name = "choice_" + choice.id
		button.text = EventFormat.choice_label(card.event, choice.id)
		button.custom_minimum_size.x = 180
		var command := ChooseEventCommand.new(rules, card.house, choice.id)
		var error := command.validate(state)
		var lines := EventFormat.choice_lines(choice)
		if not error.is_empty():
			button.disabled = true
			button.focus_mode = Control.FOCUS_NONE
			lines.append(tr(error))
			notes.append("%s: %s" % [button.text, tr(error)])
		button.tooltip_text = "\n".join(lines)
		button.pressed.connect(func() -> void: choice_requested.emit(choice.id))
		_choices.add_child(button)
	_notes.text = "\n".join(notes)


func _add_entry(event_id: String, place: String, outcome: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(CampaignStyle.heading(EventFormat.title(event_id), 20))
	if not place.is_empty():
		box.add_child(CampaignStyle.label(place, CampaignStyle.SMALL_SIZE, CampaignStyle.MUTED))
	var story := CampaignStyle.paragraph(EventFormat.text(event_id), CampaignStyle.FONT_SIZE)
	story.custom_minimum_size.x = WIDTH
	box.add_child(story)
	if not outcome.is_empty():
		box.add_child(CampaignStyle.label(outcome, CampaignStyle.SMALL_SIZE + 1))
	_entries.add_child(box)


func _focus_first() -> void:
	for button: Node in _choices.get_children():
		if not (button as Button).disabled:
			(button as Button).grab_focus()
			return
	if _continue.visible:
		_continue.grab_focus()


func _clear(container: Container) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _on_continue_pressed() -> void:
	visible = false
	closed.emit()
