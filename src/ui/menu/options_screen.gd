class_name OptionsScreen
extends Control
## The player's options (App.settings) as a modal over the main menu or the pause menu:
## video, audio, game and controls. Changes apply at once and are saved when it closes.

signal closed
## The language changed; the caller rebuilds its screen (texts are set when a screen is built).
signal language_changed

## The language can only change where the caller can rebuild everything: in the main menu.
var allow_language := true


func _init() -> void:
	visible = false


func open() -> void:
	visible = true


func close() -> void:
	visible = false
	closed.emit()
