extends GutTest
## The input table: with its defaults it registers exactly the actions, events and deadzones
## the seven hard-coded tables registered before (input_golden.txt, captured from them: one
## line per InputMap action, "<action> <deadzone> <event> ..."); it answers what the controls
## list asks, and rebinding rewrites the InputMap for the keyboard or for both controllers.
## To add an action: data/input.json, its lines in input_golden.txt (the failing test prints
## them) and the text key INPUT_<SCENE>_<ACTION> in data/i18n/texts.csv.

const GOLDEN := "res://src/render/input/input_golden.txt"
const PREFIXES: Array[String] = [
	"battle_", "map_", "castle_", "joust_", "siege_", "raid_", "merchant_",
]
const KEYS := InputTable.Family.KEYS
const PAD := InputTable.Family.PAD


func before_each() -> void:
	InputTable.register()
	InputTable.restore()


func after_all() -> void:
	# The player's own bindings, as App put them at boot.
	InputOverrides.load_file()


func test_the_defaults_register_what_the_old_tables_registered() -> void:
	var golden := FileAccess.get_file_as_string(GOLDEN).strip_edges().split("\n")
	var registered := _registered()
	var missing: Array[String] = []
	for line: String in golden:
		if line not in registered:
			missing.append(line)
	var unknown: Array[String] = []
	for line: String in registered:
		if line not in golden:
			unknown.append(line)
	assert_gte(golden.size(), 163, "the list only grows")
	assert_eq(" | ".join(missing), "", "in the golden list, not registered like that")
	assert_eq(" | ".join(unknown), "", "registered, not in the golden list")


func test_no_default_event_serves_two_actions_of_a_scene() -> void:
	for scene: String in InputTable.scenes():
		for family: InputTable.Family in [KEYS, PAD]:
			var owners: Dictionary[String, String] = {}
			if family == KEYS:
				for fixed_name: String in InputTable.fixed(scene):
					for token: String in InputTable.fixed_tokens(scene, fixed_name):
						owners[token] = fixed_name
			for action: String in InputTable.actions(scene):
				for token: String in InputTable.defaults(scene, action, family):
					var where := "%s: %s and %s" % [scene, owners.get(token, ""), action]
					assert_false(owners.has(token), "%s share %s" % [where, token])
					owners[token] = action


func test_the_table_lists_scenes_actions_and_events() -> void:
	var scenes: Array[String] = ["map", "castle", "battle", "joust", "siege", "raid", "merchant"]
	assert_eq(InputTable.scenes(), scenes)
	var first: Array[String] = ["up", "down"]
	assert_eq(InputTable.actions("map").slice(0, 2), first, "in the table's order")
	assert_eq(InputTable.actions("nowhere").size(), 0)
	assert_eq(InputTable.tokens("battle", "up", KEYS), PackedStringArray(["key:W", "key:Up"]))
	assert_eq(
		InputTable.tokens("battle", "up", PAD), PackedStringArray(["axis:left_y-", "pad:dpad_up"])
	)
	assert_eq(InputTable.tokens("battle", "slot_1", PAD).size(), 0, "no group slots on a pad")
	assert_eq(InputTable.tokens("joust", "aim_up", KEYS).size(), 0, "the mouse aims the lance")
	var events := InputTable.events("battle", "attack", PAD, 1)
	assert_eq(events.size(), 1)
	assert_eq((events[0] as InputEventJoypadButton).button_index, JOY_BUTTON_A)
	assert_eq(events[0].device, 1)
	assert_true(InputTable.is_locked("battle", "menu"))
	assert_false(InputTable.is_locked("battle", "attack"))
	var raw: Array[String] = ["order", "wheel"]
	assert_eq(InputTable.fixed("battle"), raw)
	assert_eq(InputTable.fixed_tokens("battle", "order"), PackedStringArray(["mouse:right"]))


func test_actions_are_named_per_device() -> void:
	var keyboard: Array[StringName] = [&"raid_kb_strike"]
	assert_eq(InputTable.action_names("raid", "strike", KEYS), keyboard)
	var pads: Array[StringName] = [&"raid_pad0_strike", &"raid_pad1_strike"]
	assert_eq(InputTable.action_names("raid", "strike", PAD), pads)
	var shared: Array[StringName] = [&"castle_zoom_in"]
	assert_eq(InputTable.action_names("castle", "zoom_in", KEYS), shared)
	assert_eq(InputTable.action_names("castle", "zoom_in", PAD), shared)
	assert_eq(InputTable.action_names("battle", "slot_1", PAD).size(), 0)


func test_every_scene_action_and_fixed_row_has_its_texts() -> void:
	var keys: Array[String] = []
	for scene: String in InputTable.scenes():
		keys.append(InputTable.scene_text(scene))
		for entry: String in InputTable.actions(scene) + InputTable.fixed(scene):
			keys.append(InputTable.action_text(scene, entry))
	assert_eq(InputTable.action_text("battle", "group_prev"), "INPUT_BATTLE_GROUP_PREV")
	var rows := {}
	var file := FileAccess.open("res://data/i18n/texts.csv", FileAccess.READ)
	while not file.eof_reached():
		var row := file.get_csv_line()
		rows[row[0]] = row
	for key: String in keys:
		var row: PackedStringArray = rows.get(key, PackedStringArray())
		assert_true(row.size() >= 3 and not row[1].is_empty() and not row[2].is_empty(), key)


func test_rebinding_the_keyboard_changes_only_the_keyboard_action() -> void:
	var pad_before := _line(&"battle_pad0_attack")
	assert_true(InputTable.bind("battle", "attack", KEYS, PackedStringArray(["key:Enter"])))
	assert_eq(_line(&"battle_kb_attack"), "battle_kb_attack 0.500 key:Enter")
	assert_eq(_line(&"battle_pad0_attack"), pad_before)
	assert_false(InputTable.is_default("battle", "attack", KEYS))
	assert_true(InputTable.is_default("battle", "attack", PAD))


func test_rebinding_the_controller_changes_both_joypads_alike() -> void:
	assert_true(InputTable.bind("battle", "attack", PAD, PackedStringArray(["pad:x", "axis:rt"])))
	assert_eq(_line(&"battle_pad0_attack"), "battle_pad0_attack 0.500 button:0:2 axis:0:5:+1")
	assert_eq(_line(&"battle_pad1_attack"), "battle_pad1_attack 0.500 button:1:2 axis:1:5:+1")
	assert_eq(_line(&"battle_kb_attack"), "battle_kb_attack 0.500 key:Space")


func test_a_shared_scene_keeps_keys_and_controller_in_one_action() -> void:
	assert_true(InputTable.bind("castle", "zoom_in", PAD, PackedStringArray(["pad:y"])))
	assert_eq(
		_line(&"castle_zoom_in"),
		"castle_zoom_in 0.200 key:PageUp key:KpAdd key:Equal button:-1:3"
	)
	assert_true(InputTable.bind("castle", "zoom_in", KEYS, PackedStringArray(["mouse:back"])))
	assert_eq(_line(&"castle_zoom_in"), "castle_zoom_in 0.200 mouse:8 button:-1:3")


func test_events_that_do_not_fit_are_refused() -> void:
	var before := _registered()
	var none := PackedStringArray()
	assert_false(InputTable.bind("battle", "attack", KEYS, none), "no event at all")
	assert_false(InputTable.bind("battle", "attack", KEYS, PackedStringArray(["pad:a"])))
	assert_false(InputTable.bind("battle", "attack", PAD, PackedStringArray(["key:A"])))
	assert_false(InputTable.bind("battle", "attack", KEYS, PackedStringArray(["key:Nonsense"])))
	assert_false(InputTable.bind("battle", "attack", KEYS, PackedStringArray(["mouse:wheel"])))
	assert_false(InputTable.bind("battle", "menu", KEYS, PackedStringArray(["key:M"])), "locked")
	assert_false(InputTable.bind("battle", "slot_1", PAD, PackedStringArray(["pad:x"])))
	assert_false(InputTable.bind("battle", "dance", KEYS, PackedStringArray(["key:M"])))
	assert_false(InputTable.bind("nowhere", "attack", KEYS, PackedStringArray(["key:M"])))
	assert_eq(_registered(), before)


func test_restore_puts_one_scene_or_everything_back() -> void:
	var defaults := _registered()
	InputTable.bind("battle", "attack", KEYS, PackedStringArray(["key:Enter"]))
	InputTable.bind("raid", "act", KEYS, PackedStringArray(["key:Enter"]))
	InputTable.restore("battle")
	assert_true(InputTable.is_default("battle", "attack", KEYS))
	assert_false(InputTable.is_default("raid", "act", KEYS), "another scene keeps its bindings")
	InputTable.restore()
	assert_eq(_registered(), defaults)


func test_a_change_is_announced_and_releases_the_action() -> void:
	watch_signals(InputTable.notifier)
	Input.action_press(&"battle_kb_attack")
	InputTable.bind("battle", "attack", KEYS, PackedStringArray(["key:Enter"]))
	assert_signal_emit_count(InputTable.notifier, "bindings_changed", 1)
	assert_false(Input.is_action_pressed(&"battle_kb_attack"), "no action stuck on its old key")
	InputTable.restore("battle")
	assert_signal_emit_count(InputTable.notifier, "bindings_changed", 2)


func test_the_returned_events_are_the_callers_own() -> void:
	var tokens := InputTable.tokens("battle", "up", KEYS)
	tokens.clear()
	assert_eq(InputTable.tokens("battle", "up", KEYS).size(), 2)
	assert_true(InputTable.is_default("battle", "up", KEYS))


## Every scene action in the InputMap as a line of the golden list, sorted.
func _registered() -> Array[String]:
	var lines: Array[String] = []
	for action: StringName in InputMap.get_actions():
		for prefix: String in PREFIXES:
			if String(action).begins_with(prefix):
				lines.append(_line(action))
	lines.sort()
	return lines


func _line(action: StringName) -> String:
	var parts: Array[String] = [String(action), "%.3f" % InputMap.action_get_deadzone(action)]
	for event: InputEvent in InputMap.action_get_events(action):
		parts.append(_describe(event))
	return " ".join(parts)


## Written out by engine values on purpose: independent of InputNotation.
func _describe(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		return "key:%s" % OS.get_keycode_string(key.physical_keycode).replace(" ", "")
	if event is InputEventMouseButton:
		return "mouse:%d" % (event as InputEventMouseButton).button_index
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		return "button:%d:%d" % [button.device, button.button_index]
	var motion := event as InputEventJoypadMotion
	return "axis:%d:%d:%+d" % [motion.device, motion.axis, roundi(motion.axis_value)]
