class_name CastleView
extends Node3D
## 3D view of one province's castle: the home castle (level 1-5 with the owner's decorations) or
## a province castle (level 0-3), the province's buildings, a village that grows with the
## population and every construction under way, raised by its progress in a time-lapse.
## The castle stands in its own world inside a SubViewport, so it neither sees nor lights the
## scene it is added to; a full-screen overlay shows it with the castle's name, the time-lapse
## button and a button back. The stage renders at the window's pixel size times the 3D render
## scale, so the picture is sharp at every resolution, and follows the graphics quality when
## the view opens. Emits `closed` on ui_cancel, castle_close (Esc, controller B) or the button
## and gives focus back to where it was. Hidden, it renders nothing and reacts to nothing;
## shown, it covers the window, so the 3D scene behind it is not drawn meanwhile.

signal closed

## The stage's size while the view is hidden: no screen-sized render target is kept for it.
const RESTING_SIZE := Vector2i(2, 2)

## Views showing right now; while there is one, the window behind them draws no 3D scene.
static var _showing: int = 0
## Whether the window's 3D scene was switched off before the first view opened.
static var _behind_was_off: bool = false

## Pixel size of the window the view fills and the 3D render scale (UserSettings.RENDER_SCALE);
## tests put their own in.
var window_pixels: Callable = _window_pixels
var render_scale: Callable = _render_scale

var _stage := SubViewport.new()
var _camera := CastleCamera.new()
var _world := CastleWorld.new()
var _pieces := Node3D.new()
var _timelapse := CastleTimelapse.new()
var _overlay := CastleOverlay.new()
var _built: bool = false
var _layout: CastleLayout = null
var _nodes: Array[MeshInstance3D] = []
var _focus_before: Control = null
var _is_open: bool = false


func _ready() -> void:
	_build()
	if is_visible_in_tree():
		_open()
	else:
		_rest()


## Builds or rebuilds the scene for the province and plays the time-lapse.
func show_province(state: GameState, rules: GameRules, province_id: String) -> void:
	_build()
	var layout := CastleLayout.plan(state, rules, province_id)
	if layout == null:
		return
	_timelapse.stop()
	for child: Node in _pieces.get_children():
		_pieces.remove_child(child)
		child.queue_free()
	_layout = layout
	_nodes.clear()
	var construction := -1.0
	for placement: CastleLayout.Placement in layout.placements:
		_nodes.append(_spawn(placement, layout))
		var castle_work := placement.source == ConstructionState.CASTLE
		if castle_work and placement.kind == CastleLayout.Kind.CASTLE:
			construction = maxf(construction, placement.progress)
	_world.show_yard(layout.site_key)
	_overlay.show_castle(tr(layout.name_key), _subtitle(layout), construction)
	apply_quality(App.quality())
	_camera.reset()
	_camera.make_current()
	_timelapse.start(layout, _nodes)
	_overlay.show_timelapse(_timelapse.is_playing())


## Size of the stage for a window of `pixels` at the 3D render scale `factor`, at least one
## pixel.
static func stage_size(pixels: Vector2i, factor: float) -> Vector2i:
	return Vector2i(maxi(roundi(pixels.x * factor), 1), maxi(roundi(pixels.y * factor), 1))


## Anti-aliasing of the stage and the world's costly parts for a level (UserSettings.Quality).
func apply_quality(level: int) -> void:
	_build()
	_stage.msaa_3d = SettingsApplier.MSAA_BY_QUALITY[level]
	_world.apply_quality(level)


## "Dankwarderode · Braunschweig" for a home castle, "Holstein & Lübeck · Welfen" for another
## province of a house, the province alone for the other lords.
func _subtitle(layout: CastleLayout) -> String:
	var province := tr("PROVINCE_" + layout.province_id)
	if layout.is_home:
		return "%s · %s" % [tr("CASTLE_HOME_" + layout.owner.to_upper()), province]
	if layout.is_owned_by_house:
		return "%s · %s" % [province, tr("BATTLE_HOUSE_" + layout.owner.to_upper())]
	return province


func _build() -> void:
	if _built:
		return
	_built = true
	CastleInputMap.register()
	_stage.name = "Stage"
	_stage.own_world_3d = true
	_stage.size = RESTING_SIZE
	_stage.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_stage)
	_camera.name = "Camera"
	_stage.add_child(_camera)
	_world.name = "World"
	_stage.add_child(_world)
	_world.build(_camera)
	_pieces.name = "Pieces"
	_stage.add_child(_pieces)
	_timelapse.name = "Timelapse"
	_stage.add_child(_timelapse)
	_timelapse.ended.connect(_on_timelapse_ended)
	_overlay.name = "Overlay"
	add_child(_overlay)
	_overlay.show_stage(_stage.get_texture())
	_overlay.close_pressed.connect(_close)
	_overlay.timelapse_pressed.connect(_toggle_timelapse)
	_camera.reset()
	apply_quality(App.quality())
	_rest()


func _enter_tree() -> void:
	get_window().size_changed.connect(_fit_stage)
	App.settings.changed.connect(_on_setting_changed)
	if _built and is_visible_in_tree():
		_open()


func _exit_tree() -> void:
	get_window().size_changed.disconnect(_fit_stage)
	App.settings.changed.disconnect(_on_setting_changed)
	_rest()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and _built and is_inside_tree():
		if is_visible_in_tree():
			_open()
		else:
			_rest()


## The view shows: the stage renders at the window's size and the button back takes focus.
func _open() -> void:
	var viewport := get_viewport()
	if not _is_open:
		_is_open = true
		if _showing == 0:
			_behind_was_off = viewport.disable_3d
			viewport.disable_3d = true
		_showing += 1
	var focused := viewport.gui_get_focus_owner()
	if focused != null and not _overlay.is_ancestor_of(focused):
		_focus_before = focused
	_overlay.visible = true
	_camera.set_process(true)
	_timelapse.set_process(true)
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_fit_stage()
	_overlay.take_focus()


## The view is hidden: nothing of it renders, moves or sounds.
func _rest() -> void:
	if _is_open:
		_is_open = false
		_showing -= 1
		if _showing == 0:
			get_viewport().disable_3d = _behind_was_off
	_overlay.visible = false
	_camera.set_process(false)
	_timelapse.set_process(false)
	_timelapse.stop()
	_stage.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_stage.size = RESTING_SIZE


func _fit_stage() -> void:
	if _built and is_visible_in_tree():
		var pixels: Vector2i = window_pixels.call()
		var factor: float = render_scale.call()
		_stage.size = stage_size(pixels, factor)


func _window_pixels() -> Vector2i:
	return get_window().size


func _render_scale() -> float:
	return App.settings.get_float(UserSettings.RENDER_SCALE)


func _on_setting_changed(key: String) -> void:
	if key == UserSettings.RENDER_SCALE:
		_fit_stage()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("castle_close"):
		get_viewport().set_input_as_handled()
		Audio.play(&"ui_back")
		_close()
	elif event.is_action_pressed("castle_timelapse"):
		get_viewport().set_input_as_handled()
		_toggle_timelapse()
	elif event is InputEventMouse:
		_camera.handle_input(event)


## Tells the owner, who hides the view, then hands focus back to the control that had it.
func _close() -> void:
	var back := _focus_before
	_focus_before = null
	closed.emit()
	if is_instance_valid(back) and back.is_visible_in_tree():
		back.grab_focus()


## Skips a running time-lapse; otherwise the whole castle rises once more.
func _toggle_timelapse() -> void:
	if _layout == null:
		return
	if _timelapse.is_playing():
		_timelapse.finish()
	else:
		_timelapse.start(_layout, _nodes, true)
	_overlay.show_timelapse(_timelapse.is_playing())


func _on_timelapse_ended(completed: int) -> void:
	_overlay.show_timelapse(false)
	if completed > 0:
		Audio.play(&"map_build_done")


func _spawn(placement: CastleLayout.Placement, layout: CastleLayout) -> MeshInstance3D:
	var mesh := CastleArt.mesh(placement.piece)
	if mesh == null:
		return null
	var node := MeshInstance3D.new()
	node.name = "%s_%d" % [placement.piece, _pieces.get_child_count()]
	node.mesh = mesh
	node.transform = CastleConstruction.posed(
		placement.piece, placement.transform, placement.progress
	)
	if CastleArt.has_house_colors(placement.piece):
		node.set_instance_shader_parameter("house_primary", layout.primary)
		node.set_instance_shader_parameter("house_secondary", layout.secondary)
	if placement.progress >= 1.0:
		CastleSmoke.add(node, placement.piece, _pieces.get_child_count())
	_pieces.add_child(node)
	return node
