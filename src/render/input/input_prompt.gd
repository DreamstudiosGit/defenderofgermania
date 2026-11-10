class_name InputPrompt
extends Label
## A button prompt that names what the player has to press: "[Space] Attack" on keyboard and
## mouse, "(A) Attack" on a controller — the first binding of the device family in use
## (App.pad_in_use). It follows a change of device and rebinding, and hides while the action
## has no binding on that family: its `visible` is its own, so hide its parent to hide it for
## another reason.
##   InputPrompt.new("battle", "attack", "BATTLE_ATTACK")    an action of the table
##   InputPrompt.new("", "ui_cancel", "UI_BACK")             any other InputMap action:
##                                                           ui_accept, App.PAUSE_ACTION, …

## Follow the device in use instead of one family.
const FOLLOW := -1

## An InputTable.Family to show whatever the player uses (a seat's device in a couch duel),
## or FOLLOW.
var family := FOLLOW: set = set_family

var _scene: String
var _action: String
var _text_key: String


## `scene` is a scene of the table, or empty when `action` is an InputMap action by itself;
## `text_key` names what the action does (may be empty: the glyph alone).
func _init(scene: String, action: String, text_key: String = "") -> void:
	_scene = scene
	_action = action
	_text_key = text_key


func _ready() -> void:
	App.pad_in_use_changed.connect(_on_pad_changed)
	InputTable.notifier.bindings_changed.connect(show_binding)
	show_binding()


func set_family(value: int) -> void:
	family = value
	show_binding()


## Shows the binding in use now.
func show_binding() -> void:
	var shown := InputTable.Family.PAD if App.pad_in_use else InputTable.Family.KEYS
	if family != FOLLOW:
		shown = family as InputTable.Family
	var tokens := (
		InputGlyphs.action_tokens(StringName(_action), shown) if _scene.is_empty()
		else InputTable.tokens(_scene, _action, shown)
	)
	text = InputGlyphs.prompt(tokens, shown, tr(_text_key) if not _text_key.is_empty() else "")
	visible = not tokens.is_empty()


func _on_pad_changed(_pad: bool) -> void:
	show_binding()
