extends Node
## Campaign scene: the war table, the campaign panels, live battles and adventures
## (CampaignActions) around one CampaignSession. Setup screen first; a handover screen covers
## the table between two human houses (hot-seat); after every settlement the report shows what
## changed; each turn opens with the house's event cards. F3 or Back+Y shows the computer
## opponents' utilities (AiDebugOverlay).

const MARGIN := 8.0
const TOP := 80.0
const SIDE_WIDTH := 340.0
const ADMIN_WIDTH := 450.0
const FIRST_SEED := 1198

var session: CampaignSession = null
## The computer opponents; their logs feed the debug overlay.
var ai: AiPlayer = null

var _map: MapData
var _table := MapTable.new()
var _ui := CanvasLayer.new()
var _root := Control.new()
var _hud := CampaignHud.new()
var _admin := AdministrationPanel.new()
var _province_panel := ProvincePanel.new()
var _army_panel := ArmyPanel.new()
var _toast := ErrorToast.new()
var _tooltip := FocusTooltip.new()
var _setup := SetupScreen.new()
var _ai_overlay := AiDebugOverlay.new()
var _handover := HandoverScreen.new()
var _report := SettlementReport.new()
var _victory := VictoryScreen.new()
var _events := EventCardDialog.new()
var _actions := CampaignActions.new()
var _castle := CastleView.new()
var _province := ""
var _army := MapTable.NO_ARMY
var _seen_house := ""
## Round and house whose event dialog was closed ("<turn>:<house>").
var _events_seen := ""
var _seen_settlement: GameState = null


func _ready() -> void:
	_map = MapData.load_file()
	if DisplayServer.get_name() != "headless":
		get_viewport().msaa_3d = Viewport.MSAA_4X
	add_child(_table)
	_table.build(_map)
	_table.province_clicked.connect(_on_province_clicked)
	_table.army_clicked.connect(_on_army_clicked)
	_build_ui()
	_open_setup()


## Starts a new campaign with these human houses; computers maps the others to [personality,
## difficulty], by default the data's opponents.
func start(
	humans: Array[String], seed_value: int, computers: Dictionary[String, Array] = {}
) -> void:
	_setup.visible = false
	_victory.visible = false
	var rules := GameRules.load_files()
	var config := AiConfig.load_file()
	ai = AiPlayer.new(rules, config)
	if computers.is_empty():
		computers = AiPlayer.opponents(config, rules.map.houses, humans)
	session = CampaignSession.create(rules, humans, seed_value, computers, ai.play_phase)
	_actions.session = session
	_seen_house = ""
	_events_seen = ""
	_seen_settlement = null
	_select_home()
	_after_change()


## Runs a command for the active human house and shows what follows from it.
func execute(command: Command) -> String:
	var error := session.execute(command)
	if not error.is_empty():
		_toast.show_error(error)
	_after_change()
	return error


## Order of screens after every change: victory, settlement report, handover, event cards,
## then the table.
func _after_change() -> void:
	if session.state.is_over():
		_refresh()
		_victory.open(session.state, session.rules)
		return
	if session.before_settlement != null and session.before_settlement != _seen_settlement:
		_seen_settlement = session.before_settlement
		_report.open(_seen_settlement, session.state, session.rules, session.humans)
		return
	var house := session.active_house()
	if house != _seen_house:
		_seen_house = house
		_select_home()
		if session.humans.size() > 1:
			_refresh()
			_handover.open(session.state, session.rules, house)
			return
	_refresh()
	if _wants_events(house):
		_events.open(session.state, session.rules, house)


## A human house in its event phase must answer its cards; afterwards the dialog shows once a
## turn what the round and the house's cards brought.
func _wants_events(house: String) -> bool:
	if not session.is_human_turn():
		return false
	var events := session.state.events
	if session.state.phase == GameState.Phase.EVENT:
		return true
	var has_news := not events.drawn.is_empty() or not events.news.is_empty()
	return has_news and _events_seen != _turn_key(house)


func _turn_key(house: String) -> String:
	return "%d:%s" % [session.state.turn, house]


## An event choice that starts an adventure first asks whether to play its minigame live.
func _choose_event(choice: String) -> void:
	_events.visible = false
	_actions.run(ChooseEventCommand.new(session.rules, session.active_house(), choice))


## A battle or minigame covers the war table; the table rests meanwhile.
func _on_covering(hidden: bool) -> void:
	_table.visible = not hidden
	_ui.visible = not hidden
	if not hidden:
		_table.camera.current = true


## After a command from the table or the panels: errors, the moved army stays selected.
func _on_action_finished(command: Command, error: String) -> void:
	if not error.is_empty():
		_toast.show_error(error)
	var move := command as MoveArmyCommand
	if move != null:
		var army := session.state.army(move.army_id)
		_army = move.army_id if army != null else MapTable.NO_ARMY
		_province = army.province if army != null else move.target
	_after_change()


func _on_events_closed() -> void:
	_events_seen = _turn_key(session.active_house())
	_after_change()


func _refresh() -> void:
	var state := session.state
	var house := state.active_house() if not state.is_over() else _seen_house
	_hud.refresh(state, session.rules, house)
	_admin.visible = state.phase == GameState.Phase.ADMINISTRATION and not state.is_over()
	_admin.refresh(state, session.rules, house, _province)
	_province_panel.refresh(state, session.rules, house, _province)
	_army_panel.refresh(state, session.rules, house, _army)
	_table.update_view(state)
	_table.set_selection(_province, _army, _reachable())
	_ai_overlay.refresh(state, session.rules, ai)


## Provinces the selected army may enter now: only moves the rules accept, by adjacency.
func _reachable() -> Array[String]:
	var targets: Array[String] = []
	var army := session.state.army(_army) if _army != MapTable.NO_ARMY else null
	if army == null or not session.is_human_turn():
		return targets
	for neighbor: String in _map.provinces[army.province].neighbors:
		var move := MoveArmyCommand.new(session.rules, session.active_house(), army.id, neighbor)
		if move.validate(session.state).is_empty():
			targets.append(neighbor)
	return targets


func _on_province_clicked(province_id: String) -> void:
	if session == null or _blocked():
		return
	if _army != MapTable.NO_ARMY and province_id in _reachable():
		_move(_army, province_id)
		return
	_province = province_id
	_army = MapTable.NO_ARMY
	_refresh()


func _on_army_clicked(army_id: int) -> void:
	if session == null or _blocked():
		return
	var army := session.state.army(army_id)
	if army == null:
		return
	_province = army.province
	_army = army_id
	_refresh()


func _move(army_id: int, target: String) -> void:
	_actions.run(MoveArmyCommand.new(session.rules, session.active_house(), army_id, target))


func _select_home() -> void:
	var house: HouseState = session.state.houses.get(session.active_house())
	_province = house.home_province if house != null else ""
	_army = MapTable.NO_ARMY
	var armies := session.state.armies_of(session.active_house())
	if not armies.is_empty():
		_army = armies[0].id
		_province = armies[0].province


## The castle view covers the war table; the table and its camera rest meanwhile so WASD only
## orbits the castle.
func _open_castle(province_id: String) -> void:
	if session == null or _blocked():
		return
	_castle.show_province(session.state, session.rules, province_id)
	_castle.visible = true
	_ui.visible = false
	_table.process_mode = Node.PROCESS_MODE_DISABLED


func _close_castle() -> void:
	_castle.visible = false
	_ui.visible = true
	_table.process_mode = Node.PROCESS_MODE_INHERIT
	_table.camera.current = true


func _blocked() -> bool:
	for screen: Control in [_setup, _handover, _report, _victory, _events]:
		if screen.visible:
			return true
	return _castle.visible or _actions.is_running()


func _build_ui() -> void:
	add_child(_ui)
	_ui.add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = CampaignStyle.theme()
	_root.add_child(_hud)
	_hud.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, MARGIN
	)
	_hud.command_requested.connect(_on_command)
	_root.add_child(_admin)
	_admin.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_admin.offset_left = MARGIN
	_admin.offset_top = TOP
	_admin.offset_right = MARGIN + ADMIN_WIDTH
	_admin.offset_bottom = -MARGIN
	_admin.command_requested.connect(_on_command)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", MARGIN)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(side)
	side.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	side.offset_left = -MARGIN - SIDE_WIDTH
	side.offset_top = TOP
	side.offset_right = -MARGIN
	side.offset_bottom = -MARGIN
	side.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	side.add_child(_province_panel)
	side.add_child(_army_panel)
	_province_panel.army_selected.connect(_on_army_clicked)
	_province_panel.castle_requested.connect(_open_castle)
	_castle.closed.connect(_close_castle)
	add_child(_castle)
	# Hidden only once built: CastleView hides its screen layer on the visibility change.
	_castle.visible = false
	_root.add_child(_ai_overlay)
	_ai_overlay.place(SIDE_WIDTH + 2.0 * MARGIN)
	for screen: Control in [
		_toast, _setup, _handover, _report, _events, _actions.adventures.choice,
		_actions.battles.choice, _victory, _tooltip,
	]:
		_root.add_child(screen)
	_setup.start_requested.connect(start)
	_handover.confirmed.connect(_after_change)
	_events.choice_requested.connect(_choose_event)
	add_child(_actions)
	_actions.covering.connect(_on_covering)
	_actions.finished.connect(_on_action_finished)
	_army_panel.command_requested.connect(_on_command)
	_province_panel.command_requested.connect(_on_command)
	_events.closed.connect(_on_events_closed)
	_report.closed.connect(_after_change)
	_victory.new_game_requested.connect(_open_setup)


func _open_setup() -> void:
	_setup.open(GameRules.load_files(), AiConfig.load_file(), FIRST_SEED)


## Commands from the panels; one that starts a battle or an adventure asks how to play it.
func _on_command(command: Command) -> void:
	_actions.run(command)
