class_name CastleView
extends Node3D
## 3D view of one province's castle: the home castle (level 1-5 with the owner's decorations) or
## a province castle (level 0-3), the province's buildings, a village that grows with the
## population and every construction under way, raised by its progress in a time-lapse.
## The castle stands in its own world inside a SubViewport, so it neither sees nor lights the
## scene it is added to; a full-screen overlay shows it with the castle's name and a button back.
## Emits `closed` on ui_cancel, castle_close (Esc, controller B) or the button.

signal closed

var _stage := SubViewport.new()
var _camera := CastleCamera.new()
var _world := CastleWorld.new()
var _pieces := Node3D.new()
var _timelapse := CastleTimelapse.new()
var _overlay := CastleOverlay.new()
var _built: bool = false


func _ready() -> void:
	_build()


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
	var nodes: Array[MeshInstance3D] = []
	var construction := -1.0
	for placement: CastleLayout.Placement in layout.placements:
		nodes.append(_spawn(placement, layout))
		var castle_work := placement.source == ConstructionState.CASTLE
		if castle_work and placement.kind == CastleLayout.Kind.CASTLE:
			construction = maxf(construction, placement.progress)
	_world.show_yard(layout.site_key)
	_overlay.show_castle(tr(layout.name_key), _subtitle(layout), construction)
	_camera.reset()
	_camera.make_current()
	_timelapse.start(layout, nodes)


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
	_stage.msaa_3d = Viewport.MSAA_4X
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
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
	_overlay.name = "Overlay"
	add_child(_overlay)
	_overlay.show_stage(_stage.get_texture())
	_overlay.close_pressed.connect(closed.emit)
	_camera.reset()
	if is_inside_tree():
		_fit_stage()


func _enter_tree() -> void:
	if not get_viewport().size_changed.is_connected(_fit_stage):
		get_viewport().size_changed.connect(_fit_stage)
	if _built:
		_fit_stage()


func _exit_tree() -> void:
	if get_viewport().size_changed.is_connected(_fit_stage):
		get_viewport().size_changed.disconnect(_fit_stage)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and _built:
		var shown := is_visible_in_tree()
		_overlay.visible = shown
		_camera.set_process(shown)
		_stage.render_target_update_mode = (
			SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED
		)


func _fit_stage() -> void:
	var size := get_viewport().get_visible_rect().size
	_stage.size = Vector2i(maxi(int(size.x), 1), maxi(int(size.y), 1))


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("castle_close"):
		get_viewport().set_input_as_handled()
		closed.emit()
		return
	if event is InputEventMouse:
		_camera.handle_input(event)


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
