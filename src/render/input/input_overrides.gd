class_name InputOverrides
extends RefCounted
## The player's own bindings: whatever differs from the defaults of data/input.json, kept in
## user://input.cfg apart from the options. One section per scene, one entry per action and
## device family ("keys" also holds mouse buttons, "pad" applies to every controller):
##   [battle]
##   keys/attack=["key:Enter"]
##   pad/attack=["pad:x"]
## An entry that names an unknown scene or action, a locked action or anything that is no
## event of its family is ignored, so a hand-edited or outdated file never breaks the start.

## Where the bindings live; tests point it elsewhere.
static var path := "user://input.cfg"


## Registers the table and puts the player's bindings over its defaults (App, at boot).
static func load_file() -> void:
	InputTable.register()
	InputTable.restore()
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	for scene: String in file.get_sections():
		for key: String in file.get_section_keys(scene):
			var parts := key.split("/")
			var family := InputTable.FAMILIES.find(parts[0])
			if parts.size() == 2 and family >= 0:
				var tokens := _tokens(file.get_value(scene, key))
				InputTable.bind(scene, parts[1], family as InputTable.Family, tokens)


## Writes every binding that differs from its default.
static func save_file() -> Error:
	var file := ConfigFile.new()
	for scene: String in InputTable.scenes():
		for action: String in InputTable.actions(scene):
			for family: InputTable.Family in InputTable.Family.values():
				if not InputTable.is_default(scene, action, family):
					var key := "%s/%s" % [InputTable.FAMILIES[family], action]
					file.set_value(scene, key, Array(InputTable.tokens(scene, action, family)))
	var folder := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(folder):
		var made := DirAccess.make_dir_recursive_absolute(folder)
		if made != OK:
			return made
	return file.save(path)


## Gives an action other events (InputNotation tokens) for the keyboard or for the
## controllers and saves; ERR_INVALID_PARAMETER when the table does not accept them.
static func set_binding(
	scene: String, action: String, family: InputTable.Family, tokens: PackedStringArray
) -> Error:
	if not InputTable.bind(scene, action, family, tokens):
		return ERR_INVALID_PARAMETER
	return save_file()


## Puts one action's default back for one device family and saves.
static func clear(scene: String, action: String, family: InputTable.Family) -> Error:
	return set_binding(scene, action, family, InputTable.defaults(scene, action, family))


## Puts the defaults back, for one scene or for everything, and saves.
static func reset(scene: String = "") -> Error:
	InputTable.restore(scene)
	return save_file()


static func _tokens(value: Variant) -> PackedStringArray:
	var tokens := PackedStringArray()
	if value is Array:
		var items: Array = value
		for item: Variant in items:
			if not item is String:
				return PackedStringArray()
			tokens.append(item)
	return tokens
