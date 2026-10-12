extends Control
## Preview of the campaign screens over a plain background, for screenshots and trying them
## out: a fresh game (seed 1), the Welfen to move, Brunswick selected. It stands in for the
## campaign controller: commands run on its own state and refused ones show in the toast.
## Arguments after "--": --view=<name> (VIEWS), --locale=de|en, --shot=<png path> saves a
## screenshot after a few frames and quits.

const VIEWS: Array[String] = [
	"main", "levers", "grain", "build", "recruit", "court", "province",
	"handover", "setup", "report", "battle", "victory",
]
const SHOT_FRAMES := 12
const MARGIN := 8.0
const SIDE_WIDTH := 360.0
const ADMIN_WIDTH := 450.0

var _rules: GameRules
var _state: GameState
var _house := "welfen"
var _province := "BSW"
var _army := -1
var _hud: CampaignHud
var _admin: AdministrationPanel
var _province_panel: ProvincePanel
var _army_panel: ArmyPanel
var _toast: ErrorToast
var _tooltip: FocusTooltip
var _screen: Control
var _shot := ""
var _frames := 0


func _ready() -> void:
	var args := _arguments()
	if args.has("locale"):
		TranslationServer.set_locale(args["locale"])
	_rules = GameRules.load_files()
	_state = GameSetup.create(_rules.map, _rules.economy, 1)
	# Preview only: the Welfen move first whatever the seed's turn order says.
	_state.active_index = _state.turn_order.find(_house)
	_army = _state.armies_of(_house)[0].id
	_build()
	_refresh()
	_show_view(args.get("view", "main"))
	_shot = args.get("shot", "")


func _process(_delta: float) -> void:
	if _shot.is_empty():
		return
	# The window's first mouse event would switch FocusTooltip off before the screenshot.
	_tooltip.steer_by_focus()
	_frames += 1
	if _frames == SHOT_FRAMES:
		var error := get_viewport().get_texture().get_image().save_png(_shot)
		print("campaign preview: saved %s (%s)" % [_shot, error_string(error)])
		get_tree().quit(0 if error == OK else 1)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode >= KEY_F1:
		var index := key.keycode - KEY_F1
		if index < VIEWS.size():
			_show_view(VIEWS[index])


func _build() -> void:
	theme = CampaignStyle.theme()
	var background := ColorRect.new()
	background.color = Color(0.21, 0.25, 0.21)
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud = CampaignHud.new()
	add_child(_hud)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, MARGIN)
	_hud.command_requested.connect(_on_command)
	_admin = AdministrationPanel.new()
	add_child(_admin)
	_admin.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_admin.offset_left = MARGIN
	_admin.offset_top = 80.0
	_admin.offset_right = MARGIN + ADMIN_WIDTH
	_admin.offset_bottom = -MARGIN
	_admin.command_requested.connect(_on_command)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", MARGIN)
	add_child(side)
	side.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	side.offset_left = -MARGIN - SIDE_WIDTH
	side.offset_top = 80.0
	side.offset_right = -MARGIN
	side.offset_bottom = -MARGIN
	side.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_province_panel = ProvincePanel.new()
	_province_panel.army_selected.connect(_on_army_selected)
	side.add_child(_province_panel)
	_army_panel = ArmyPanel.new()
	side.add_child(_army_panel)
	_toast = ErrorToast.new()
	add_child(_toast)
	_tooltip = FocusTooltip.new()
	add_child(_tooltip)


func _refresh() -> void:
	if not _state.is_over():
		_house = _state.active_house()
	_hud.refresh(_state, _rules, _house)
	_admin.refresh(_state, _rules, _house, _province)
	_province_panel.refresh(_state, _rules, _house, _province)
	_army_panel.refresh(_state, _rules, _house, _army)


func _show_view(view: String) -> void:
	_tooltip.steer_by_focus()
	match view:
		"levers":
			_admin.show_tab(AdministrationPanel.Tab.LEVERS)
			_focus(_admin, "tax_20")
		"grain":
			_admin.show_tab(AdministrationPanel.Tab.GRAIN)
			_hud.focus_number(1)
		"build":
			_admin.show_tab(AdministrationPanel.Tab.BUILD)
			_focus(_admin, "building_market_2")
		"recruit":
			_admin.show_tab(AdministrationPanel.Tab.RECRUIT)
			_focus(_admin, "unit_crossbowmen")
		"court":
			_admin.show_tab(AdministrationPanel.Tab.COURT)
			_focus(_admin, "decoration_fountain")
		"province":
			_admin.show_tab(AdministrationPanel.Tab.LEVERS)
			_focus(_province_panel, "satisfaction")
		"handover", "setup", "report", "battle", "victory":
			_open_screen(view)
		_:
			_admin.show_tab(AdministrationPanel.Tab.LEVERS)
			_hud.focus_number(0)
			_toast.show_error("TURN_NOT_ENOUGH_GOLD")


## Opens one of the modal screens with sample data; the preview's own state stays as it is.
func _open_screen(view: String) -> void:
	if _screen != null:
		_screen.queue_free()
	match view:
		"handover":
			var handover := HandoverScreen.new()
			_add_screen(handover)
			handover.open(_state, _rules, _house)
		"setup":
			var setup := SetupScreen.new()
			_add_screen(setup)
			setup.open(_rules.map, CampaignFormat.START_YEAR)
		"report":
			var before := GameState.from_dict(_state.to_dict())
			before.turn = GameState.Season.AUTUMN
			before.provinces["HOL"].constructions.append(ConstructionState.create("granary", 1))
			var after := GameState.from_dict(before.to_dict())
			EconomySettlement.settle(after, _rules.map, _rules.economy)
			var report := SettlementReport.new()
			_add_screen(report)
			report.open(before, after, _rules, ["welfen", "staufer"] as Array[String])
		"battle":
			var battle := BattleSetup.new()
			battle.terrain = _rules.map.provinces["BRM"].terrain
			battle.attacker = CampaignBattles.army_side(_state, _rules, _state.army(_army))
			battle.attacker.is_human = true
			battle.defender = Garrisons.side(_state, _rules, "BRM")
			var choice := BattleChoice.new()
			_add_screen(choice)
			choice.open(battle, _rules, "BRM")
		"victory":
			var done := GameState.from_dict(_state.to_dict())
			done.turn = _rules.map.campaign.max_rounds
			Victory.check(done, _rules)
			var victory := VictoryScreen.new()
			_add_screen(victory)
			victory.open(done, _rules)


func _add_screen(screen: Control) -> void:
	_screen = screen
	add_child(screen)
	move_child(_tooltip, -1)


func _focus(root: Node, node_name: String) -> void:
	var target := root.find_child(node_name, true, false) as Control
	if target != null:
		target.grab_focus()


func _on_command(command: Command) -> void:
	var error := command.execute(_state)
	if not error.is_empty():
		_toast.show_error(error)
	_refresh()


func _on_army_selected(army_id: int) -> void:
	_army = army_id
	_refresh()


func _arguments() -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	for argument: String in OS.get_cmdline_user_args():
		var parts := argument.trim_prefix("--").split("=", true, 1)
		result[parts[0]] = parts[1] if parts.size() > 1 else ""
	return result
