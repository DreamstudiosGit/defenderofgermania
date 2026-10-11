extends SceneTree
## Parses every project script with the project's warning settings and enforces that
## src/systems/ never references src/render/ or src/ui/; exits 1 on any error.
## Usage: godot --headless --script res://scripts/typecheck.gd

const SKIP_DIRS: Array[String] = ["res://.godot", "res://addons", "res://art-src", "res://docs"]
const SYSTEMS_DIR := "res://src/systems/"
const FORBIDDEN_IN_SYSTEMS: Array[String] = ["res://src/render/", "res://src/ui/"]


func _init() -> void:
	var failed: Array[String] = []
	var own_path: String = (get_script() as Script).resource_path
	for path: String in _collect_scripts("res://"):
		if path == own_path:
			continue
		var script := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as GDScript
		if script == null or not script.can_instantiate():
			failed.append(path)
		elif path.begins_with(SYSTEMS_DIR):
			for forbidden: String in FORBIDDEN_IN_SYSTEMS:
				if forbidden in script.source_code:
					printerr("ERROR: %s references %s" % [path, forbidden])
					failed.append(path)
	for path: String in failed:
		printerr("typecheck failed: %s" % path)
	print("typecheck: %d file(s) with errors" % failed.size())
	quit(1 if failed else 0)


func _collect_scripts(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	if dir_path in SKIP_DIRS:
		return result
	for file: String in DirAccess.get_files_at(dir_path):
		if file.get_extension() == "gd":
			result.append(dir_path.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir_path):
		if not sub.begins_with("."):
			result.append_array(_collect_scripts(dir_path.path_join(sub)))
	return result
