extends GutTest
## The castle view as a screen: its stage has the window's pixels times the render scale and
## rests while hidden, ui_cancel closes it and goes no further, focus sits on the button back
## and returns to where it was, the hint names the device in use, the time-lapse can be
## skipped and watched again, and the graphics quality switches the costly parts off.

const HOUSE := "welfen"

var _rules: GameRules
var _state: GameState
var _quality := 0
var _pixels := Vector2i(1920, 1080)
var _scale := 1.0
## ui_cancel presses that reached this node, the view's parent: those the view let pass.
var _cancels_passed := 0


func before_all() -> void:
	_rules = GameRules.load_files()


func before_each() -> void:
	_state = GameSetup.create(_rules.map, _rules.economy, 1)
	CastleTimelapse.forget()
	_quality = App.quality()
	_pixels = Vector2i(1920, 1080)
	_scale = 1.0
	_cancels_passed = 0


func after_each() -> void:
	App.settings.set_value(UserSettings.QUALITY, _quality)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_cancels_passed += 1


func test_stage_size_is_the_windows_pixels_times_the_render_scale() -> void:
	assert_eq(CastleView.stage_size(Vector2i(1280, 720), 1.0), Vector2i(1280, 720))
	assert_eq(CastleView.stage_size(Vector2i(1920, 1080), 1.0), Vector2i(1920, 1080))
	assert_eq(CastleView.stage_size(Vector2i(3840, 2160), 0.5), Vector2i(1920, 1080))
	assert_eq(CastleView.stage_size(Vector2i(1280, 800), 0.75), Vector2i(960, 600))
	assert_eq(CastleView.stage_size(Vector2i.ZERO, 1.0), Vector2i.ONE, "never without a pixel")


func test_the_stage_follows_the_window_and_the_render_scale() -> void:
	var view := _show()
	var stage := _stage(view)
	assert_eq(stage.size, Vector2i(1920, 1080), "a 1080p window is not rendered at 720p")
	_pixels = Vector2i(2560, 1440)
	get_window().size_changed.emit()
	assert_eq(stage.size, Vector2i(2560, 1440), "it follows a resize")
	_scale = 0.5
	App.settings.changed.emit(UserSettings.RENDER_SCALE)
	assert_eq(stage.size, Vector2i(1280, 720), "and the render scale option")
	assert_eq(stage.msaa_3d, SettingsApplier.MSAA_BY_QUALITY[App.quality()], "no forced MSAA")


func test_hidden_it_rests_and_reacts_to_nothing() -> void:
	var view := _show()
	var stage := _stage(view)
	var camera := view.find_child("Camera", true, false) as CastleCamera
	var timelapse := view.find_child("Timelapse", true, false) as CastleTimelapse
	watch_signals(view)
	assert_true(get_viewport().disable_3d, "the scene behind the view is not drawn")
	view.visible = false
	assert_false(get_viewport().disable_3d, "it is drawn again once the view is hidden")
	assert_eq(stage.size, CastleView.RESTING_SIZE, "no screen-sized render target is kept")
	assert_eq(stage.render_target_update_mode, SubViewport.UPDATE_DISABLED)
	assert_false(camera.is_processing(), "the camera reads no input")
	assert_false(timelapse.is_playing(), "the time-lapse has ended")
	assert_false((view.get_node("Overlay") as CanvasLayer).visible)
	get_window().size_changed.emit()
	assert_eq(stage.size, CastleView.RESTING_SIZE, "a resize does not wake it")
	_press("ui_cancel")
	_press("castle_timelapse")
	assert_signal_not_emitted(view, "closed")
	assert_false(timelapse.is_playing())
	assert_eq(_cancels_passed, 1, "ui_cancel passes a hidden view")
	view.visible = true
	assert_eq(stage.size, Vector2i(1920, 1080))
	assert_eq(stage.render_target_update_mode, SubViewport.UPDATE_ALWAYS)
	assert_true(camera.is_processing())


func test_ui_cancel_closes_and_is_consumed() -> void:
	var view := _show()
	watch_signals(view)
	_press("ui_cancel")
	assert_signal_emit_count(view, "closed", 1)
	assert_eq(_cancels_passed, 0, "the press does not reach the scene behind the view")


func test_focus_sits_on_the_button_back_and_returns_on_close() -> void:
	var origin := Button.new()
	add_child_autofree(origin)
	var view := CastleView.new()
	view.window_pixels = _window_pixels
	view.render_scale = _render_scale
	add_child_autofree(view)
	view.visible = false
	view.closed.connect(func() -> void: view.visible = false)
	origin.grab_focus()
	view.show_province(_state, _rules, _home_id())
	view.visible = true
	var close := view.find_child("Close", true, false) as Button
	assert_eq(get_viewport().gui_get_focus_owner(), close, "the button back has the focus")
	for direction: String in ["ui_left", "ui_right", "ui_up", "ui_down", "ui_focus_next"]:
		_press(direction)
	assert_eq(get_viewport().gui_get_focus_owner(), close, "and keeps it: arrows turn the castle")
	close.pressed.emit()
	assert_false(view.visible)
	assert_eq(get_viewport().gui_get_focus_owner(), origin, "focus is back where it was")


func test_the_hint_names_the_device_in_use() -> void:
	var view := _show()
	var hint := view.find_child("Hint", true, false) as Label
	App.pad_in_use_changed.emit(true)
	assert_eq(hint.text, tr("CASTLE_HINT_PAD"))
	App.pad_in_use_changed.emit(false)
	assert_eq(hint.text, tr("CASTLE_HINT_KEYS"))
	App.pad_in_use_changed.emit(App.pad_in_use)
	assert_ne(tr("CASTLE_HINT_PAD"), "CASTLE_HINT_PAD", "the text exists")
	assert_ne(tr("CASTLE_HINT_KEYS"), tr("CASTLE_HINT_PAD"))


func test_the_time_lapse_can_be_skipped_and_watched_again() -> void:
	_home().castle_level = 3
	_home().constructions.append(ConstructionState.create(ConstructionState.CASTLE, 1))
	var view := _show()
	var timelapse := view.find_child("Timelapse", true, false) as CastleTimelapse
	var button := view.find_child("Replay", true, false) as Button
	watch_signals(timelapse)
	assert_true(timelapse.is_playing())
	assert_eq(button.text, tr("CASTLE_TIMELAPSE_SKIP"))
	_press("castle_timelapse")
	assert_false(timelapse.is_playing(), "the key skips it")
	assert_signal_emit_count(timelapse, "ended", 1)
	assert_eq(button.text, tr("CASTLE_TIMELAPSE"))
	for child: Node in view.find_child("Pieces", true, false).get_children():
		assert_true((child as Node3D).visible, "%s shows after the skip" % child.name)
	var keep := _piece(view, "castle_keep")
	var standing := keep.position.y
	button.pressed.emit()
	assert_true(timelapse.is_playing(), "the button plays the whole castle again")
	assert_lt(keep.position.y, standing, "even what stood before rises from the ground")
	timelapse.advance(CastleArt.number("timelapse", "duration", 3.0) + 30.0)
	assert_almost_eq(keep.position.y, standing, 0.001)
	assert_signal_emit_count(timelapse, "ended", 2)
	assert_gt(int(get_signal_parameters(timelapse, "ended")[0]), 0, "pieces were completed")


func test_a_building_finished_since_the_last_view_is_completed_by_the_time_lapse() -> void:
	var view := _show()
	var timelapse := view.find_child("Timelapse", true, false) as CastleTimelapse
	timelapse.finish()
	watch_signals(timelapse)
	view.show_province(_state, _rules, _home_id())
	assert_false(timelapse.is_playing(), "nothing new")
	_home().buildings.append("granary")
	view.show_province(_state, _rules, _home_id())
	timelapse.finish()
	assert_signal_emitted_with_parameters(timelapse, "ended", [1])


func test_quality_low_switches_the_costly_parts_off() -> void:
	App.settings.set_value(UserSettings.QUALITY, UserSettings.Quality.LOW)
	var view := _show()
	var camera := view.find_child("Camera", true, false) as Camera3D
	var sun := view.find_child("Sun", true, false) as DirectionalLight3D
	assert_false(camera.environment.ssao_enabled, "no ambient occlusion")
	assert_false(camera.environment.glow_enabled, "no glow")
	assert_false(camera.environment.ssil_enabled)
	assert_false(camera.environment.volumetric_fog_enabled)
	assert_eq(_stage(view).msaa_3d, Viewport.MSAA_DISABLED, "no anti-aliasing")
	assert_eq(sun.directional_shadow_mode, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
	App.settings.set_value(UserSettings.QUALITY, UserSettings.Quality.HIGH)
	assert_false(camera.environment.ssao_enabled, "the level counts when the view opens")
	view.show_province(_state, _rules, _home_id())
	assert_true(camera.environment.ssao_enabled)
	assert_true(camera.environment.glow_enabled)
	assert_eq(_stage(view).msaa_3d, Viewport.MSAA_4X)
	assert_eq(sun.directional_shadow_mode, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS)


func _window_pixels() -> Vector2i:
	return _pixels


func _render_scale() -> float:
	return _scale


func _show() -> CastleView:
	var view := CastleView.new()
	view.window_pixels = _window_pixels
	view.render_scale = _render_scale
	add_child_autofree(view)
	view.show_province(_state, _rules, _home_id())
	return view


func _stage(view: CastleView) -> SubViewport:
	return view.get_node("Stage") as SubViewport


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	get_viewport().push_input(event)


func _home_id() -> String:
	return _state.houses[HOUSE].home_province


func _home() -> ProvinceState:
	return _state.provinces[_home_id()]


func _piece(view: CastleView, piece: String) -> MeshInstance3D:
	for child: Node in view.find_child("Pieces", true, false).get_children():
		if child.name.begins_with(piece + "_"):
			return child as MeshInstance3D
	return null
