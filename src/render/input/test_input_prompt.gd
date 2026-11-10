extends GutTest
## The button prompt: it shows the first binding of the device family in use, follows a
## change of device and rebinding, can be pinned to one family, hides without a binding and
## also shows the actions outside the table (confirm, cancel, pause). Texts in English.

const KEYS := InputTable.Family.KEYS
const PAD := InputTable.Family.PAD

var _locale_before: String


func before_all() -> void:
	_locale_before = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func before_each() -> void:
	InputTable.register()
	InputTable.restore()
	App.pad_in_use = false


func after_all() -> void:
	TranslationServer.set_locale(_locale_before)
	App.pad_in_use = false
	InputOverrides.load_file()


func test_it_shows_the_binding_of_the_device_in_use() -> void:
	var prompt := _prompt("battle", "attack", "INPUT_BATTLE_ATTACK")
	assert_eq(prompt.text, "[Space] Attack")
	_use_pad(true)
	assert_eq(prompt.text, "(A) Attack")
	_use_pad(false)
	assert_eq(prompt.text, "[Space] Attack")


func test_it_follows_rebinding() -> void:
	var prompt := _prompt("battle", "attack", "INPUT_BATTLE_ATTACK")
	InputTable.bind("battle", "attack", KEYS, PackedStringArray(["key:Enter", "key:Space"]))
	assert_eq(prompt.text, "[Enter] Attack", "the first of several")
	InputTable.restore()
	assert_eq(prompt.text, "[Space] Attack")


func test_it_can_be_pinned_to_one_family() -> void:
	var prompt := _prompt("battle", "rally", "INPUT_BATTLE_RALLY")
	prompt.family = PAD
	assert_eq(prompt.text, "(Y) Rally", "a seat on a controller while the keyboard is in use")
	_use_pad(true)
	prompt.family = KEYS
	assert_eq(prompt.text, "[R] Rally")
	prompt.family = InputPrompt.FOLLOW
	assert_eq(prompt.text, "(Y) Rally")


func test_it_hides_where_the_action_has_no_binding() -> void:
	var prompt := _prompt("battle", "slot_1", "INPUT_BATTLE_SLOT_1")
	assert_true(prompt.visible)
	assert_eq(prompt.text, "[1] Group 1")
	_use_pad(true)
	assert_false(prompt.visible, "no group slots on a controller")
	assert_eq(prompt.text, "")
	_use_pad(false)
	assert_true(prompt.visible)


func test_it_shows_confirm_cancel_and_pause() -> void:
	var back := _prompt("", "ui_cancel", "UI_BACK")
	var pause := _prompt("", App.PAUSE_ACTION, "")
	assert_eq(back.text, "[Esc] Back")
	assert_eq(pause.text, "[Esc]", "the glyph alone without a text key")
	_use_pad(true)
	assert_eq(back.text, "(B) Back")
	assert_eq(pause.text, "(Start)")
	assert_eq(_prompt("", "ui_accept", "UI_OK").text, "(A) OK")


func _prompt(scene: String, action: String, text_key: String) -> InputPrompt:
	return add_child_autofree(InputPrompt.new(scene, action, text_key)) as InputPrompt


func _use_pad(pad: bool) -> void:
	App.pad_in_use = pad
	App.pad_in_use_changed.emit(pad)
