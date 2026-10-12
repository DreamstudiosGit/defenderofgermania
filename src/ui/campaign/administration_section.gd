class_name AdministrationSection
extends ScrollContainer
## Base of the administration tabs: a scrolling column whose buttons and labels are created
## once per name and updated on every refresh, so keyboard and controller focus survives.
## An action button shows its command's validation error and stays focusable when disabled.

signal command_requested(command: Command)

var column := VBoxContainer.new()
var _commands: Dictionary[Button, Command] = {}


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	follow_focus = true
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	add_child(column)


## Overridden by each tab; province_id is the selected province ("" for none).
func refresh(_state: GameState, _rules: GameRules, _house: String, _province_id: String) -> void:
	pass


## The child of parent called key, created as an action button on first use.
func button(parent: Container, key: String) -> Button:
	var existing := parent.get_node_or_null(NodePath(key))
	if existing is Button:
		return existing
	var created := Button.new()
	created.name = key
	created.alignment = HORIZONTAL_ALIGNMENT_LEFT
	created.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	created.pressed.connect(_on_pressed.bind(created))
	parent.add_child(created)
	return created


## The child of parent called key, created as a wrapping label on first use.
func note(parent: Container, key: String, color: Color = CampaignStyle.MUTED) -> Label:
	var existing := parent.get_node_or_null(NodePath(key))
	if existing is Label:
		return existing
	var created := CampaignStyle.paragraph()
	created.add_theme_color_override("font_color", color)
	created.name = key
	parent.add_child(created)
	return created


## A heading label created on first use.
func heading(parent: Container, key: String) -> Label:
	var existing := parent.get_node_or_null(NodePath(key))
	if existing is Label:
		return existing
	var created := CampaignStyle.heading("", 18)
	created.name = key
	parent.add_child(created)
	return created


## Offers the command on the button: enabled with details as tooltip if it validates now,
## otherwise disabled with the reason above the details.
func offer(
	target: Button, caption: String, command: Command, state: GameState, details: String
) -> void:
	target.text = caption
	_commands[target] = command
	var error := command.validate(state)
	target.disabled = not error.is_empty()
	target.tooltip_text = details if error.is_empty() else "%s\n%s" % [tr(error), details]


## Removes the buttons of parent whose names are not in keep.
func prune(parent: Container, keep: Array[String]) -> void:
	for child: Node in parent.get_children():
		if child is Button and String(child.name) not in keep:
			_commands.erase(child)
			parent.remove_child(child)
			child.queue_free()


func _on_pressed(source: Button) -> void:
	var command: Command = _commands.get(source)
	if command != null:
		command_requested.emit(command)
