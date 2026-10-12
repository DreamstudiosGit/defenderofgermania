extends SceneTree

const VARIANTS: Array[String] = ["summer_meadow", "river_valley", "autumn_woodland"]


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var packed := load("res://src/render/battle/combat_art_preview.tscn") as PackedScene
	var preview := packed.instantiate()
	root.add_child(preview)
	var failed := false
	for variant: String in VARIANTS:
		preview.call("show_landscape", variant)
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var path := "res://art-src/combat/landscape_%s.png" % variant
		var error := image.save_png(ProjectSettings.globalize_path(path))
		failed = failed or error != OK
		print("landscape preview: %s, error %d" % [path, error])
		if variant == "summer_meadow":
			await create_timer(1.0).timeout
			await RenderingServer.frame_post_draw
			var moving := root.get_texture().get_image()
			var water_area := Rect2i(image.get_width() / 2 + 100, 0, 120, 90)
			var tree_area := Rect2i(30, 120, 150, image.get_height() - 380)
			var water := _changed_pixels(image, moving, water_area)
			var wind := _changed_pixels(image, moving, tree_area)
			print("landscape animation after 1 s: water %d pixels; wind %d pixels" % [water, wind])
			failed = failed or water == 0 or wind == 0
			moving.save_png(ProjectSettings.globalize_path("res://art-src/combat/landscape_motion.png"))
	quit(1 if failed else 0)


func _changed_pixels(first: Image, second: Image, area: Rect2i) -> int:
	var changed := 0
	for y: int in range(area.position.y, area.end.y, 2):
		for x: int in range(area.position.x, area.end.x, 2):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.02:
				changed += 1
	return changed
