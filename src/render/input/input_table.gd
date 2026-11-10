class_name InputTable
extends RefCounted
## Every scene's input in one table. data/input.json names, per scene and action, the default
## keyboard / mouse events, the controller events and the deadzone; register() turns them
## into InputMap actions once at boot, and the player's own bindings replace the defaults
## from there (InputOverrides, bind()).
##
## Action names: "<scene>_kb_<action>" for keyboard and mouse, "<scene>_pad<n>_<action>" for
## controller n (joypad id n, below PADS). A scene with "shared": true has one action
## "<scene>_<action>" for the keyboard and every controller together.
##
## data/input.json:
##   scenes.<scene>.actions.<action>: {"keys": [events], "pad": [events], "deadzone": 0.5}
##       "keys" or "pad" is left out where the action does not exist for that device;
##       "pad_deadzone" where the controller's differs; "locked": true keeps the player from
##       rebinding it (the controls list shows it as a fixed row).
##   scenes.<scene>.fixed.<name>: [events]
##       mouse input the scene reads without an action (raw paths in readers and cameras);
##       shown as fixed rows and never given to an action of that scene.
## Events are written "<kind>:<name>" — "key:W", "mouse:left", "pad:a", "axis:left_y-",
## "axis:rt"; InputNotation lists every name.
## Texts: a scene is INPUT_SCENE_<SCENE>, an action or fixed row INPUT_<SCENE>_<NAME>.

enum Family { KEYS, PAD }

const PATH := "res://data/input.json"
## Controllers with an action set of their own: joypad ids 0 … PADS - 1.
const PADS := 2
const ALL_PADS := InputNotation.ALL_PADS
## The families' names in data/input.json and in the player's file.
const FAMILIES: Array[String] = ["keys", "pad"]

## A class without instances has no signals; this one stands in.
static var notifier := Notifier.new()

static var _scenes: Dictionary[String, Scene] = {}
static var _registered := false


class Notifier:
	extends RefCounted
	## An action got other events (rebinding, reset); prompts show them.
	signal bindings_changed


class Scene:
	var shared := false
	var actions: Dictionary[String, Action] = {}
	var fixed: Dictionary[String, PackedStringArray] = {}


class Action:
	var locked := false
	## By Family.
	var deadzones: Array[float] = [0.0, 0.0]
	var defaults: Array[PackedStringArray] = [PackedStringArray(), PackedStringArray()]
	var tokens: Array[PackedStringArray] = [PackedStringArray(), PackedStringArray()]


## Loads the table and adds every action of every scene to the InputMap; later calls do
## nothing.
static func register() -> void:
	if _registered:
		return
	_registered = true
	_load(PATH)
	for scene: String in _scenes:
		for action: String in _scenes[scene].actions:
			_write(scene, action)


## The scenes in the order of the table.
static func scenes() -> Array[String]:
	var names: Array[String] = []
	names.assign(_scenes.keys())
	return names


## The actions of a scene in the order of the table.
static func actions(scene: String) -> Array[String]:
	var names: Array[String] = []
	if _scenes.has(scene):
		names.assign(_scenes[scene].actions.keys())
	return names


## The names of a scene's raw mouse paths.
static func fixed(scene: String) -> Array[String]:
	var names: Array[String] = []
	if _scenes.has(scene):
		names.assign(_scenes[scene].fixed.keys())
	return names


static func fixed_tokens(scene: String, fixed_name: String) -> PackedStringArray:
	if not _scenes.has(scene) or not _scenes[scene].fixed.has(fixed_name):
		return PackedStringArray()
	return _scenes[scene].fixed[fixed_name].duplicate()


static func is_locked(scene: String, action: String) -> bool:
	var entry := _action(scene, action)
	return entry != null and entry.locked


## The events an action has now for one device family, as InputNotation tokens; empty where
## the action does not exist for that family. The caller's own copy.
static func tokens(scene: String, action: String, family: Family) -> PackedStringArray:
	var entry := _action(scene, action)
	return entry.tokens[family].duplicate() if entry != null else PackedStringArray()


static func defaults(scene: String, action: String, family: Family) -> PackedStringArray:
	var entry := _action(scene, action)
	return entry.defaults[family].duplicate() if entry != null else PackedStringArray()


static func is_default(scene: String, action: String, family: Family) -> bool:
	return tokens(scene, action, family) == defaults(scene, action, family)


## The events an action has now for one device family; controller events carry `joypad`.
static func events(
	scene: String, action: String, family: Family, joypad: int = ALL_PADS
) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	for token: String in tokens(scene, action, family):
		result.append(InputNotation.event(token, joypad))
	return result


## The InputMap actions that carry an action's events of one device family: one for the
## keyboard, one per joypad id for controllers, the same single one in a shared scene.
static func action_names(scene: String, action: String, family: Family) -> Array[StringName]:
	var names: Array[StringName] = []
	if defaults(scene, action, family).is_empty():
		return names
	if _scenes[scene].shared:
		names.append(StringName("%s_%s" % [scene, action]))
	elif family == Family.KEYS:
		names.append(StringName("%s_kb_%s" % [scene, action]))
	else:
		for pad: int in PADS:
			names.append(StringName("%s_pad%d_%s" % [scene, pad, action]))
	return names


## Text key of a scene's name.
static func scene_text(scene: String) -> String:
	return "INPUT_SCENE_%s" % scene.to_upper()


## Text key of an action's or a fixed row's name.
static func action_text(scene: String, action: String) -> String:
	return "INPUT_%s_%s" % [scene.to_upper(), action.to_upper()]


## True when bind() would take these events: the action exists for the family, is not locked
## and every token is an event of that family.
static func accepts(
	scene: String, action: String, family: Family, new_tokens: PackedStringArray
) -> bool:
	var entry := _action(scene, action)
	if entry == null or entry.locked or entry.defaults[family].is_empty():
		return false
	for token: String in new_tokens:
		if not _is_event_of(token, family):
			return false
	return not new_tokens.is_empty()


## Gives an action other events for one device family (the keyboard's, or both controllers'
## alike) and rewrites its InputMap actions; false when the events are not accepted.
static func bind(
	scene: String, action: String, family: Family, new_tokens: PackedStringArray
) -> bool:
	if not accepts(scene, action, family, new_tokens):
		return false
	_action(scene, action).tokens[family] = new_tokens.duplicate()
	_write(scene, action)
	notifier.bindings_changed.emit()
	return true


## Puts the defaults back: for one scene, or for all of them.
static func restore(scene: String = "") -> void:
	var changed := false
	for scene_name: String in _scenes:
		if not scene.is_empty() and scene_name != scene:
			continue
		for action: String in _scenes[scene_name].actions:
			var entry := _scenes[scene_name].actions[action]
			if entry.tokens == entry.defaults:
				continue
			for family: Family in Family.values():
				entry.tokens[family] = entry.defaults[family].duplicate()
			_write(scene_name, action)
			changed = true
	if changed:
		notifier.bindings_changed.emit()


static func _action(scene: String, action: String) -> Action:
	if not _scenes.has(scene):
		return null
	return _scenes[scene].actions.get(action)


static func _is_event_of(token: String, family: Family) -> bool:
	var pad := family == Family.PAD
	return InputNotation.is_pad(token) == pad and InputNotation.event(token) != null


## Writes an action's events into its InputMap actions.
static func _write(scene: String, action: String) -> void:
	var entry := _action(scene, action)
	if _scenes[scene].shared:
		var all := events(scene, action, Family.KEYS)
		all.append_array(events(scene, action, Family.PAD))
		_set_action(StringName("%s_%s" % [scene, action]), entry.deadzones[Family.KEYS], all)
		return
	for name: StringName in action_names(scene, action, Family.KEYS):
		_set_action(name, entry.deadzones[Family.KEYS], events(scene, action, Family.KEYS))
	var pad_names := action_names(scene, action, Family.PAD)
	for pad: int in pad_names.size():
		_set_action(
			pad_names[pad], entry.deadzones[Family.PAD], events(scene, action, Family.PAD, pad)
		)


static func _set_action(name: StringName, deadzone: float, new_events: Array[InputEvent]) -> void:
	if InputMap.has_action(name):
		InputMap.action_erase_events(name)
		# A key held while its action loses it would never release the action again.
		Input.action_release(name)
	else:
		InputMap.add_action(name, deadzone)
	for input: InputEvent in new_events:
		InputMap.action_add_event(name, input)


static func _load(path: String) -> void:
	var data: Variant = DataReader.load_json(path)
	if not data is Dictionary:
		push_error("input: %s is not a settings object" % path)
		return
	var reader := DataReader.new()
	var root: Dictionary = data
	var scene_data := reader.object(root, "scenes")
	for scene_name: String in scene_data:
		reader.context = "scenes"
		var entry := reader.object(scene_data, scene_name)
		var scene := Scene.new()
		reader.context = "scenes.%s" % scene_name
		scene.shared = reader.flag(entry, "shared")
		var action_data := reader.object(entry, "actions")
		for action: String in action_data:
			reader.context = "scenes.%s.actions" % scene_name
			scene.actions[action] = _read_action(reader, action, reader.object(action_data, action))
		reader.context = "scenes.%s.fixed" % scene_name
		var fixed_data := reader.object(entry, "fixed", false)
		for fixed_name: String in fixed_data:
			scene.fixed[fixed_name] = PackedStringArray(reader.strings(fixed_data, fixed_name))
		_scenes[scene_name] = scene
	for problem: String in reader.errors:
		push_error("input: %s" % problem)


static func _read_action(reader: DataReader, action: String, data: Dictionary) -> Action:
	var entry := Action.new()
	reader.context += "." + action
	entry.locked = reader.flag(data, "locked")
	var deadzone := reader.number(data, "deadzone")
	entry.deadzones = [deadzone, reader.number(data, "pad_deadzone", deadzone)]
	for family: Family in Family.values():
		var valid := PackedStringArray()
		for token: String in reader.strings(data, FAMILIES[family], false):
			if _is_event_of(token, family):
				valid.append(token)
			else:
				reader.errors.append("%s.%s: no event: %s" % [reader.context, FAMILIES[family], token])
		entry.defaults[family] = valid
		entry.tokens[family] = valid.duplicate()
	return entry
