extends GutTest
## What a release build relies on (scripts/build.mjs, docs/decisions/0009-packaging.md): the
## export presets pack the plain files the game reads and leave tests and tools out, and the
## icon and the boot splash that project.godot names exist and fit.

const PRESETS := "res://export_presets.cfg"
const PLATFORMS: Array[String] = ["Windows Desktop", "Linux", "macOS"]
## One of each kind that must stay out of a build.
const NOT_FOR_PLAYERS: Array[String] = [
	"res://src/core/test_campaign.gd",
	"res://addons/gut/gut.gd",
	"res://scripts/typecheck.gd",
	"res://src/render/map/map_preview.gd",
	"res://src/render/map/map_preview.tscn",
	"res://.gutconfig.json",
]

var _presets := ConfigFile.new()


func before_all() -> void:
	_presets.load(PRESETS)


func test_there_is_one_preset_per_platform() -> void:
	var platforms: Array[String] = []
	for preset: String in _preset_sections():
		platforms.append(_presets.get_value(preset, "platform"))
	assert_eq(platforms, PLATFORMS)


func test_every_preset_exports_all_resources() -> void:
	# Models are loaded through paths built from strings; "selected resources" would drop them.
	for preset: String in _preset_sections():
		assert_eq(_presets.get_value(preset, "export_filter"), "all_resources", preset)


func test_every_preset_packs_the_plain_files_the_game_reads() -> void:
	var files: Array[String] = []
	files.assign(LicenceTexts.FONTS.values())
	for file: String in DirAccess.get_files_at("res://data"):
		if file.get_extension() == "json":
			files.append("res://data/" + file)
	assert_gt(files.size(), LicenceTexts.FONTS.size(), "the data files were found")
	for preset: String in _preset_sections():
		var filters := _filters(preset, "include_filter")
		for file: String in files:
			assert_true(_matches(file, filters), "%s packs %s" % [preset, file])


func test_no_preset_packs_tests_or_tools() -> void:
	for preset: String in _preset_sections():
		var filters := _filters(preset, "exclude_filter")
		for file: String in NOT_FOR_PLAYERS:
			assert_true(_matches(file, filters), "%s leaves out %s" % [preset, file])


func test_no_preset_leaves_out_a_game_script() -> void:
	for preset: String in _preset_sections():
		var filters := _filters(preset, "exclude_filter")
		for file: String in ["res://src/core/save_games.gd", "res://src/render/app/app.gd"]:
			assert_false(_matches(file, filters), "%s keeps %s" % [preset, file])


func test_the_icon_is_square_with_clear_corners() -> void:
	var icon := _image("application/config/icon")
	assert_eq(icon.get_width(), icon.get_height())
	assert_gte(icon.get_width(), 256, "the largest size of a Windows icon")
	assert_eq(icon.get_pixel(0, 0).a, 0.0)


func test_the_splash_fills_the_base_canvas() -> void:
	var canvas := Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)
	assert_eq(_image("application/boot_splash/image").get_size(), canvas)


func test_the_splash_ends_in_the_boot_colour_which_is_the_curtains() -> void:
	var boot: Color = ProjectSettings.get_setting("application/boot_splash/bg_color")
	assert_true(boot.is_equal_approx(SceneCurtain.COLOR), "boot colour and curtain agree")
	var splash := _image("application/boot_splash/image")
	var last := splash.get_size() - Vector2i.ONE
	for corner: Vector2i in [Vector2i.ZERO, Vector2i(last.x, 0), Vector2i(0, last.y), last]:
		var pixel := splash.get_pixelv(corner)
		assert_eq([pixel.r8, pixel.g8, pixel.b8], [boot.r8, boot.g8, boot.b8], str(corner))


func _preset_sections() -> Array[String]:
	var sections: Array[String] = []
	for section: String in _presets.get_sections():
		if not section.ends_with(".options"):
			sections.append(section)
	return sections


func _filters(preset: String, key: String) -> PackedStringArray:
	var filters := PackedStringArray()
	var listed: String = _presets.get_value(preset, key, "")
	for filter: String in listed.split(","):
		if not filter.strip_edges().is_empty():
			filters.append(filter.strip_edges())
	return filters


## The exporter's rule: a filter matches a path with or without res://, ignoring case.
func _matches(path: String, filters: PackedStringArray) -> bool:
	for filter: String in filters:
		if path.matchn(filter) or path.trim_prefix("res://").matchn(filter):
			return true
	return false


## The image file a project setting names, read as the engine reads it at boot: as a file.
func _image(setting: String) -> Image:
	var path: String = ProjectSettings.get_setting(setting)
	var image := Image.new()
	image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	return image
