extends Node3D

const VARIANTS: Array[String] = ["summer_meadow", "river_valley", "autumn_woodland"]

var landscape: String = "summer_meadow"
var _content: Node3D
var _camera: BattleCamera
var _figures: BattleFigures
var _sim: BattleSim
var _title := Label.new()
var _shields: Array[GroupShield] = []
var _clock: float = 0.0


func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_2X
	var canvas := CanvasLayer.new()
	add_child(canvas)
	canvas.add_child(_title)
	_title.position = Vector2(24, 18)
	_title.add_theme_font_size_override("font_size", 24)
	var hint := Label.new()
	canvas.add_child(hint)
	hint.position = Vector2(24, 50)
	hint.text = tr("COMBAT_ART_HINT")
	for side: int in BattleState.SIDES:
		var row := HBoxContainer.new()
		canvas.add_child(row)
		row.set_anchors_and_offsets_preset(
			Control.PRESET_BOTTOM_LEFT if side == 0 else Control.PRESET_BOTTOM_RIGHT,
			Control.PRESET_MODE_MINSIZE, 26
		)
		row.grow_horizontal = Control.GROW_DIRECTION_END if side == 0 else Control.GROW_DIRECTION_BEGIN
		row.grow_vertical = Control.GROW_DIRECTION_BEGIN
		row.add_theme_constant_override("separation", 14)
		var groups: Array[int] = [
			BattleState.Group.INFANTRY, BattleState.Group.CAVALRY, BattleState.Group.SIEGE
		]
		for group: int in groups:
			var shield := GroupShield.new()
			shield.group = group
			shield.companies = 1
			shield.active = side == 0 and group == BattleState.Group.INFANTRY
			row.add_child(shield)
			_shields.append(shield)
	show_landscape(landscape)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode >= KEY_1 and key.keycode <= KEY_3:
			show_landscape(VARIANTS[key.keycode - KEY_1])


func _process(delta: float) -> void:
	_clock += delta
	if _figures != null:
		_sim.state.tick = int(_clock / _sim.tick_seconds())
		_figures.update_view(_sim.state, _sim.state.fig_pos, 1.0)


func show_landscape(variant: String) -> void:
	if variant not in VARIANTS:
		push_error("combat art preview: unknown variant %s" % variant)
		return
	landscape = variant
	if _content != null:
		_content.free()
	_content = Node3D.new()
	add_child(_content)
	var cfg := CombatConfig.load_file()
	for i: int in _shields.size():
		_shields[i].house_color = cfg.battle.armies[i / 3].color
		_shields[i].accent = cfg.battle.armies[i / 3].accent
	var field := BattleField.new()
	_content.add_child(field)
	field.build(cfg.battle, cfg.battle.armies, variant)
	field.show_zones(false)
	_sim = BattleSim.new(cfg, cfg.battle.default_setup(), 1198)
	_figures = BattleFigures.new()
	_content.add_child(_figures)
	_figures.setup(_sim.state, cfg.battle.armies, _sim.tick_seconds())
	_figures.set_selection_sides([true, false])
	_camera = BattleCamera.new()
	_content.add_child(_camera)
	_camera.setup(cfg.battle.field_size, cfg.battle.field_size * 0.5)
	_camera.current = true
	var art := BattleModels.settings()
	var styles: Dictionary = art.get("landscapes", {})
	var style: Dictionary = styles[variant]
	_title.text = tr(str(style["title_key"]))

