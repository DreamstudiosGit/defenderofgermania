extends Node
## Campaign scene: the war table, the campaign panels and live battles around one
## CampaignSession. Setup screen first; a handover screen covers the table between two human
## houses (hot-seat); after every settlement the report shows what changed.

const BATTLE_SCENE := preload("res://src/render/battle/battle_main.tscn")
const MARGIN := 8.0
const TOP := 80.0
const SIDE_WIDTH := 340.0
const ADMIN_WIDTH := 450.0
const FIRST_SEED := 1198

var session: CampaignSession = null

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
var _handover := HandoverScreen.new()
var _report := SettlementReport.new()
var _choice := BattleChoice.new()
var _victory := VictoryScreen.new()
var _battle: Node = null
var _castle := CastleView.new()
var _province := ""
var _army := MapTable.NO_ARMY
var _move_army := MapTable.NO_ARMY
var _move_target := ""
var _seen_house := ""
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
	_setup.open(_map, FIRST_SEED)


## Starts a new campaign with these human houses; the others pass until the AI (M7).
func start(humans: Array[String], seed_value: int) -> void:
	_setup.visible = false
	_victory.visible = false
	session = CampaignSession.create(GameRules.load_files(), humans, seed_value)
	_seen_house = ""
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


## Order of screens after every change: victory, settlement report, handover, then the table.
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
	_move_army = army_id
	_move_target = target
	var setup := session.battle_ahead(army_id, target)
	if setup == null:
		_finish_move()
		return
	_choice.open(setup, session.rules, target)


## Fights the battle of the pending move live, or lets the move auto-resolve it.
func _on_battle_chosen(play_live: bool) -> void:
	if not play_live:
		_finish_move()
		return
	var setup := session.battle_ahead(_move_army, _move_target)
	if setup == null:
		_finish_move()
		return
	var defender_human := setup.defender.owner in session.humans
	var devices := PackedInt32Array([
		BattleInputMap.Device.KEYBOARD, BattleInputMap.Device.PAD_1 if defender_human else -1
	])
	setup.attacker.is_human = true
	setup.defender.is_human = defender_human
	_battle = BATTLE_SCENE.instantiate()
	_battle.call("configure_campaign", setup, devices, _battle_seed())
	_battle.connect("battle_finished", _on_battle_finished)
	_table.visible = false
	_ui.visible = false
	add_child(_battle)


func _on_battle_finished(result: BattleResult) -> void:
	_battle.queue_free()
	_battle = null
	_table.visible = true
	_ui.visible = true
	_table.camera.current = true
	var error := session.move_after_battle(_move_army, _move_target, result)
	_after_move(error)


func _finish_move() -> void:
	var error := session.execute(
		MoveArmyCommand.new(session.rules, session.active_house(), _move_army, _move_target)
	)
	_after_move(error)


func _after_move(error: String) -> void:
	if not error.is_empty():
		_toast.show_error(error)
	var army := session.state.army(_move_army)
	_army = _move_army if army != null else MapTable.NO_ARMY
	_province = army.province if army != null else _move_target
	_move_army = MapTable.NO_ARMY
	_move_target = ""
	_after_change()


## Same campaign moment, same battle: the seed comes from the round and the moving army.
func _battle_seed() -> int:
	return session.state.turn * 1000 + _move_army


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
	for screen: Control in [_setup, _handover, _report, _choice, _victory]:
		if screen.visible:
			return true
	return _battle != null or _castle.visible


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
	_castle.visible = false
	_castle.closed.connect(_close_castle)
	add_child(_castle)
	for screen: Control in [_toast, _setup, _handover, _report, _choice, _victory, _tooltip]:
		_root.add_child(screen)
	_setup.start_requested.connect(start)
	_handover.confirmed.connect(_refresh)
	_report.closed.connect(_after_change)
	_choice.chosen.connect(_on_battle_chosen)
	_victory.new_game_requested.connect(func() -> void: _setup.open(_map, FIRST_SEED))


func _on_command(command: Command) -> void:
	execute(command)
