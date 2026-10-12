class_name AdministrationPanel
extends PanelContainer
## The administration phase in tabs: levers (tax, ration), grain market, building and
## recruiting in the selected province, and the court (decorations, leader, ransom). Every
## action is emitted as a Command; the controller executes it and calls refresh().

signal command_requested(command: Command)

enum Tab { LEVERS, GRAIN, BUILD, RECRUIT, COURT }

const TITLES: Array[String] = [
	"CAMPAIGN_TAB_LEVERS",
	"CAMPAIGN_TAB_GRAIN",
	"CAMPAIGN_TAB_BUILD",
	"CAMPAIGN_TAB_RECRUIT",
	"CAMPAIGN_TAB_COURT",
]

var _tabs := TabContainer.new()
var _sections: Array[AdministrationSection] = [
	LeversSection.new(),
	GrainTradeSection.new(),
	BuildSection.new(),
	RecruitSection.new(),
	CourtSection.new(),
]


func _init() -> void:
	theme = CampaignStyle.theme()
	custom_minimum_size = Vector2(420, 0)
	add_child(_tabs)
	for i: int in _sections.size():
		var section := _sections[i]
		section.name = TITLES[i]
		_tabs.add_child(section)
		_tabs.set_tab_title(i, tr(TITLES[i]))
		section.command_requested.connect(command_requested.emit)


## province_id is the selected province ("" for none); building and recruiting act there.
func refresh(state: GameState, rules: GameRules, house: String, province_id: String) -> void:
	for section: AdministrationSection in _sections:
		section.refresh(state, rules, house, province_id)


func show_tab(tab: Tab) -> void:
	_tabs.current_tab = tab


## Focuses the tab bar, so a controller can switch tabs with left and right.
func focus_tabs() -> void:
	_tabs.get_tab_bar().grab_focus()


## ui_cancel inside a tab goes back to the tab bar.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or not is_visible_in_tree():
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and _tabs.is_ancestor_of(focus) and focus != _tabs.get_tab_bar():
		get_viewport().set_input_as_handled()
		focus_tabs()
