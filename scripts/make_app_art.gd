extends SceneTree
## Renders the app icon and the boot splash into assets/ui/ from the master in art-src/ui/:
## the icon straight from the SVG, the splash (the crest and the game's name in the display
## face on the boot colour) through a viewport — so it needs a window and cannot run headless.
## Usage: godot --resolution 1280x720 --script res://scripts/make_app_art.gd
## Run "godot --headless --import" afterwards.

const MASTER := "res://art-src/ui/icon_app.svg"
const ICON := "res://assets/ui/icon_app.png"
const SPLASH := "res://assets/ui/splash_boot.png"
## Width of the master's view box.
const MASTER_SIZE := 256.0
## Large enough for the 256 px Windows icon and the 512 px macOS one.
const ICON_SIZE := 512
## The base canvas: the boot window shows the splash 1:1.
const SPLASH_SIZE := Vector2i(1280, 720)
const CREST_SIZE := 176
const CREST_GAP := 14.0
const NAME_SIZE := 108
const YEAR_SIZE := 36
const RULE_HEIGHT := 3.0
const SETTLE_FRAMES := 5


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	var master := FileAccess.get_file_as_bytes(MASTER)
	if master.is_empty():
		push_error("app art: cannot read %s" % MASTER)
		quit(1)
		return
	var failed := _save(_crest(master, ICON_SIZE), ICON)
	var viewport := _splash(master)
	for frame: int in SETTLE_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	var splash := viewport.get_texture().get_image()
	splash.convert(Image.FORMAT_RGB8)
	failed = _save(splash, SPLASH) or failed
	quit(1 if failed else 0)


func _crest(master: PackedByteArray, size: int) -> Image:
	var image := Image.new()
	var error := image.load_svg_from_buffer(master, size / MASTER_SIZE)
	if error != OK:
		push_error("app art: %s is not a readable SVG (%s)" % [MASTER, error_string(error)])
	return image


func _splash(master: PackedByteArray) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = SPLASH_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var ground := ColorRect.new()
	ground.color = ProjectSettings.get_setting("application/boot_splash/bg_color")
	viewport.add_child(ground)
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre := CenterContainer.new()
	viewport.add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	centre.add_child(column)
	var crest := TextureRect.new()
	crest.texture = ImageTexture.create_from_image(_crest(master, CREST_SIZE))
	crest.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	column.add_child(crest)
	var gap := Control.new()
	gap.custom_minimum_size.y = CREST_GAP
	column.add_child(gap)
	# The product name is "<name> <year>", as the main menu sets it.
	var product: String = ProjectSettings.get_setting("application/config/name")
	var words := product.rsplit(" ", true, 1)
	column.add_child(_heading(words[0], NAME_SIZE, UiPalette.GOLD))
	if words.size() > 1:
		var year_row := HBoxContainer.new()
		year_row.add_theme_constant_override("separation", 18)
		column.add_child(year_row)
		year_row.add_child(_rule())
		year_row.add_child(_heading(words[1], YEAR_SIZE, UiPalette.TEXT))
		year_row.add_child(_rule())
	return viewport


func _heading(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UiFonts.display())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label


func _rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.color = UiPalette.GOLD.darkened(0.15)
	rule.custom_minimum_size.y = RULE_HEIGHT
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rule


## True when the file could not be written.
func _save(image: Image, path: String) -> bool:
	var error := ERR_INVALID_DATA if image.is_empty() else image.save_png(path)
	print("app art: %s %dx%d (%s)" % [
		path, image.get_width(), image.get_height(), error_string(error)
	])
	return error != OK
