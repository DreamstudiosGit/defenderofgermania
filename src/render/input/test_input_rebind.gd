extends GutTest
## Rebinding with conflicts: inside one scene and device family an event belongs to one
## action; the other action keeps its remaining events or swaps, fixed mouse paths, locked
## actions and the pause menu's events are refused, and every change is saved. The bindings
## file is the test's own.

const PATH := "user://test_input_rebind/input.cfg"
const KEYS := InputTable.Family.KEYS
const PAD := InputTable.Family.PAD
const BOUND := InputRebind.Result.BOUND
const SWAPPED := InputRebind.Result.SWAPPED
const TAKEN := InputRebind.Result.TAKEN
const UNCHANGED := InputRebind.Result.UNCHANGED
const REFUSED := InputRebind.Result.REFUSED

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


func test_a_free_event_is_bound_and_replaces_the_old_ones() -> void:
	var outcome := InputRebind.assign("battle", "up", KEYS, "key:I")
	assert_eq(outcome.result, BOUND)
	assert_true(outcome.saved)
	assert_eq(InputTable.tokens("battle", "up", KEYS), PackedStringArray(["key:I"]))
	assert_eq(InputRebind.holder_of("battle", KEYS, "key:Up"), "", "the arrow is free again")
	assert_true(FileAccess.file_exists(PATH))


func test_an_action_left_without_an_event_takes_the_old_ones_over() -> void:
	var outcome := InputRebind.assign("battle", "attack", KEYS, "key:F")
	assert_eq(outcome.result, SWAPPED)
	assert_eq(outcome.other, "formation")
	assert_eq(InputTable.tokens("battle", "attack", KEYS), PackedStringArray(["key:F"]))
	assert_eq(InputTable.tokens("battle", "formation", KEYS), PackedStringArray(["key:Space"]))
	InputTable.restore()
	InputOverrides.load_file()
	assert_eq(InputTable.tokens("battle", "formation", KEYS), PackedStringArray(["key:Space"]))


func test_an_action_with_more_events_keeps_the_rest() -> void:
	var outcome := InputRebind.assign("battle", "attack", KEYS, "key:Up")
	assert_eq(outcome.result, TAKEN)
	assert_eq(outcome.other, "up")
	assert_eq(InputTable.tokens("battle", "attack", KEYS), PackedStringArray(["key:Up"]))
	assert_eq(InputTable.tokens("battle", "up", KEYS), PackedStringArray(["key:W"]))


func test_one_of_its_own_events_becomes_the_only_one() -> void:
	var outcome := InputRebind.assign("battle", "up", KEYS, "key:Up")
	assert_eq(outcome.result, BOUND)
	assert_eq(InputTable.tokens("battle", "up", KEYS), PackedStringArray(["key:Up"]))
	outcome = InputRebind.assign("battle", "up", KEYS, "key:Up")
	assert_eq(outcome.result, UNCHANGED)


func test_a_controller_swap_reaches_both_joypads() -> void:
	var outcome := InputRebind.assign("battle", "attack", PAD, "pad:y")
	assert_eq(outcome.result, SWAPPED)
	assert_eq(outcome.other, "rally")
	for pad: int in InputTable.PADS:
		var rally := InputMap.action_get_events("battle_pad%d_rally" % pad)
		assert_eq((rally[0] as InputEventJoypadButton).button_index, JOY_BUTTON_A)
		assert_eq(rally[0].device, pad)
	assert_eq(InputTable.tokens("battle", "attack", KEYS), PackedStringArray(["key:Space"]))


func test_the_same_event_may_serve_another_scene_and_the_other_family() -> void:
	assert_eq(InputRebind.assign("raid", "act", KEYS, "key:F").result, BOUND)
	assert_eq(InputTable.tokens("battle", "formation", KEYS), PackedStringArray(["key:F"]))
	assert_eq(InputRebind.assign("castle", "zoom_in", PAD, "pad:x").result, BOUND)
	assert_eq(InputTable.tokens("castle", "zoom_in", KEYS).size(), 3, "its keys stay")


func test_a_fixed_mouse_path_is_refused() -> void:
	var outcome := InputRebind.assign("battle", "attack", KEYS, "mouse:right")
	assert_eq(outcome.result, REFUSED)
	assert_eq(outcome.holder_text, "INPUT_BATTLE_ORDER")
	assert_true(InputTable.is_default("battle", "attack", KEYS))
	assert_eq(InputRebind.assign("map", "up", KEYS, "mouse:left").holder_text, "INPUT_MAP_SELECT")
	assert_eq(InputRebind.assign("joust", "spur", KEYS, "mouse:right").result, BOUND)


func test_the_events_of_a_locked_action_are_refused() -> void:
	var outcome := InputRebind.assign("siege", "fire", KEYS, "key:H")
	assert_eq(outcome.result, REFUSED)
	assert_eq(outcome.holder_text, "INPUT_SIEGE_MENU")
	outcome = InputRebind.assign("siege", "fire", PAD, "pad:back")
	assert_eq(outcome.holder_text, "INPUT_SIEGE_MENU")
	outcome = InputRebind.assign("castle", "zoom_in", PAD, "pad:b")
	assert_eq(outcome.holder_text, "INPUT_CASTLE_CLOSE")
	outcome = InputRebind.assign("battle", "menu", KEYS, "key:M")
	assert_eq(outcome.result, REFUSED, "a locked action takes no event")
	assert_eq(outcome.holder_text, "")


func test_the_pause_menus_events_are_refused_everywhere() -> void:
	var outcome := InputRebind.assign("map", "zoom_in", PAD, "pad:start")
	assert_eq(outcome.result, REFUSED)
	assert_eq(outcome.holder_text, InputRebind.PAUSE_TEXT)
	assert_eq(InputRebind.reserved_by("map", KEYS, "key:Escape"), InputRebind.PAUSE_TEXT)
	assert_eq(InputRebind.reserved_by("map", KEYS, "key:Enter"), "")


func test_an_event_of_the_wrong_family_is_refused() -> void:
	var outcome := InputRebind.assign("battle", "attack", KEYS, "pad:x")
	assert_eq(outcome.result, REFUSED)
	assert_eq(outcome.holder_text, "")
	assert_eq(InputRebind.assign("battle", "slot_1", PAD, "pad:x").result, REFUSED)
	assert_false(FileAccess.file_exists(PATH), "nothing was written")


func _remove_file() -> void:
	DirAccess.remove_absolute(PATH)
	DirAccess.remove_absolute(PATH.get_base_dir())
