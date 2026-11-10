class_name FocusTrap
extends Node
## Keeps keyboard and controller focus inside a modal screen: add one as a child of the
## screen's root. Godot looks for the next control in a direction (and for Tab) across the
## whole window, so without it focus wanders to the buttons of the screen behind the modal,
## where the player cannot see it. Focus that leaves the screen while it shows returns to
## the control inside that had it.
##
## The search across the window also prefers a control behind the modal to one inside it
## when it lies nearer, so a modal spells out the ways between its own controls
## (link_column, pin, ring): a spelled-out neighbour is taken without any search.

## Set while one trap takes focus back: two screens that show side by side, neither inside
## the other, would otherwise pull it from each other without end.
static var _returning := false

var _inside: Control = null


func _ready() -> void:
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


## The controls under `node` that can take focus, in tree order.
static func focusables(node: Node) -> Array[Control]:
	var found: Array[Control] = []
	for child: Node in node.get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		if control.focus_mode == Control.FOCUS_ALL:
			found.append(control)
		found.append_array(focusables(control))
	return found


## Up and down lead along the column; its ends stay put, or lead to each other with `wrap`.
## A control in it that cannot take focus right now is passed over.
static func link_column(column: Array[Control], wrap: bool = false) -> void:
	var last := column.size() - 1
	for index: int in column.size():
		var control := column[index]
		var above := column[index - 1] if index > 0 else column[last if wrap else 0]
		var below := column[index + 1] if index < last else column[0 if wrap else last]
		control.focus_neighbor_top = control.get_path_to(above)
		control.focus_neighbor_bottom = control.get_path_to(below)


## Pushing towards these sides leaves focus on the control.
static func pin(control: Control, sides: Array[Side]) -> void:
	for side: Side in sides:
		control.set_focus_neighbor(side, ^".")


## Tab after the screen's last control leads to its first, Shift+Tab back.
static func ring(first: Control, last: Control) -> void:
	last.focus_next = last.get_path_to(first)
	first.focus_previous = first.get_path_to(last)


func _on_focus_changed(control: Control) -> void:
	var screen := get_parent() as Control
	if _returning or screen == null or not screen.is_visible_in_tree():
		return
	if screen.is_ancestor_of(control):
		_inside = control
	elif is_instance_valid(_inside) and _inside.is_visible_in_tree():
		_returning = true
		_inside.grab_focus()
		_returning = false
