extends GutTest
## The player's bindings file: a rebind is applied and written, only what differs from the
## defaults is stored, the file is applied over the defaults when it loads, and nothing in a
## broken or outdated file breaks the start. The file is the test's own.

const PATH := "user://test_input_overrides/input.cfg"
const KEYS := InputTable.Family.KEYS
const PAD := InputTable.Family.PAD

var _path_before: String


func before_all() -> void:
	_path_before = InputOverrides.path
	InputOverrides.path = PATH


func before_each() -> void:
	_remove_file()
	InputOverrides.load_file()


func after_each() -> void:
	_remove_file()


func after_all() -> void:
	InputOverrides.path = _path_before
	InputOverrides.load_file()


func test_without_a_file_the_defaults_apply() -> void:
	assert_true(InputTable.is_default("battle", "attack", KEYS))
	assert_eq(_keys_of(&"battle_kb_attack"), [KEY_SPACE])


func test_a_rebind_applies_and_survives_a_restart() -> void:
	var enter := PackedStringArray(["key:Enter"])
	assert_eq(InputOverrides.set_binding("battle", "attack", KEYS, enter), OK)
	assert_eq(_keys_of(&"battle_kb_attack"), [KEY_ENTER], "applied at once")
	InputTable.restore()
	assert_eq(_keys_of(&"battle_kb_attack"), [KEY_SPACE])
	InputOverrides.load_file()
	assert_eq(InputTable.tokens("battle", "attack", KEYS), enter)
	assert_eq(_keys_of(&"battle_kb_attack"), [KEY_ENTER], "applied over the defaults at boot")


func test_only_what_differs_from_the_defaults_is_stored() -> void:
	InputOverrides.set_binding("battle", "attack", PAD, PackedStringArray(["pad:x", "axis:rt"]))
	var file := ConfigFile.new()
	assert_eq(file.load(PATH), OK)
	assert_eq(file.get_sections(), PackedStringArray(["battle"]))
	assert_eq(file.get_section_keys("battle"), PackedStringArray(["pad/attack"]))
	assert_eq(file.get_value("battle", "pad/attack"), ["pad:x", "axis:rt"])


func test_a_controller_rebind_reaches_both_joypads_after_loading() -> void:
	InputOverrides.set_binding("raid", "act", PAD, PackedStringArray(["pad:y"]))
	InputTable.restore()
	InputOverrides.load_file()
	for action: StringName in [&"raid_pad0_act", &"raid_pad1_act"]:
		var events := InputMap.action_get_events(action)
		assert_eq(events.size(), 1)
		assert_eq((events[0] as InputEventJoypadButton).button_index, JOY_BUTTON_Y)
	assert_eq(InputMap.action_get_events(&"raid_pad1_act")[0].device, 1)


func test_clear_puts_one_binding_back() -> void:
	InputOverrides.set_binding("battle", "attack", KEYS, PackedStringArray(["key:Enter"]))
	InputOverrides.set_binding("battle", "rally", KEYS, PackedStringArray(["key:T"]))
	assert_eq(InputOverrides.clear("battle", "attack", KEYS), OK)
	assert_true(InputTable.is_default("battle", "attack", KEYS))
	var file := ConfigFile.new()
	file.load(PATH)
	assert_eq(file.get_section_keys("battle"), PackedStringArray(["keys/rally"]))


func test_reset_restores_one_scene_or_everything() -> void:
	InputOverrides.set_binding("battle", "attack", KEYS, PackedStringArray(["key:Enter"]))
	InputOverrides.set_binding("raid", "act", KEYS, PackedStringArray(["key:Enter"]))
	assert_eq(InputOverrides.reset("battle"), OK)
	var file := ConfigFile.new()
	file.load(PATH)
	assert_eq(file.get_sections(), PackedStringArray(["raid"]), "the other scene is kept")
	assert_eq(InputOverrides.reset(), OK)
	assert_true(InputTable.is_default("raid", "act", KEYS))
	file = ConfigFile.new()
	file.load(PATH)
	assert_eq(file.get_sections().size(), 0)


func test_a_refused_binding_writes_nothing() -> void:
	var start := PackedStringArray(["key:M"])
	assert_eq(InputOverrides.set_binding("battle", "menu", KEYS, start), ERR_INVALID_PARAMETER)
	assert_false(FileAccess.file_exists(PATH))


func test_invalid_entries_are_ignored_and_valid_ones_still_apply() -> void:
	_write_file("\n".join([
		"[battle]",
		"keys/attack=[\"key:Enter\"]",
		"keys/formation=[\"pad:a\"]",
		"keys/rally=[\"key:NoSuchKey\"]",
		"keys/menu=[\"key:M\"]",
		"keys/dance=[\"key:M\"]",
		"keys/up=[]",
		"keys/down=\"key:M\"",
		"keys/left=[7]",
		"pad/slot_1=[\"pad:x\"]",
		"mouse/right=[\"key:M\"]",
		"right=[\"key:M\"]",
		"[nowhere]",
		"keys/attack=[\"key:M\"]",
		"",
	]))
	InputOverrides.load_file()
	assert_eq(InputTable.tokens("battle", "attack", KEYS), PackedStringArray(["key:Enter"]))
	var others: Array[String] = [
		"formation", "rally", "menu", "up", "down", "left", "right", "slot_1",
	]
	for action: String in others:
		assert_true(InputTable.is_default("battle", action, KEYS), action)
	assert_eq(InputTable.tokens("battle", "slot_1", PAD).size(), 0)


func test_a_broken_file_leaves_the_defaults() -> void:
	InputTable.bind("battle", "attack", KEYS, PackedStringArray(["key:Enter"]))
	_write_file("[battle\nkeys/attack=[[[")
	InputOverrides.load_file()
	assert_true(InputTable.is_default("battle", "attack", KEYS), "loading starts from the defaults")
	assert_engine_error_count(1)


func _keys_of(action: StringName) -> Array:
	var codes := []
	for event: InputEvent in InputMap.action_get_events(action):
		codes.append((event as InputEventKey).physical_keycode)
	return codes


func _write_file(content: String) -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _remove_file() -> void:
	DirAccess.remove_absolute(PATH)
	DirAccess.remove_absolute(PATH.get_base_dir())
