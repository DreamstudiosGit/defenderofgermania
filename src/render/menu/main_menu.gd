extends Node3D
## Main menu, the game's main scene: the war table as a drifting backdrop (MenuBackdrop) behind
## the menu's screen (MainMenuScreen), whose requests it turns into scene changes. A headless
## run with the menu as the tree's scene (the smoke test) has nobody to press a button and
## passes on to a computer-vs-computer battle.

## Frames a headless run stays in the menu before the battle.
const SMOKE_FRAMES := 5

## Come back with the options open (the language changed there); set before entering the tree.
var open_options := false
## Changes the scene: func(scene_path: String, configure: Callable = Callable()) -> void.
## Tests replace it and quit_game.
var change_scene: Callable = App.go_to
var quit_game: Callable = App.quit
var backdrop := MenuBackdrop.new()
var screen := MainMenuScreen.new()

var _frames := 0


func _ready() -> void:
	backdrop.name = "Backdrop"
	add_child(backdrop)
	backdrop.build()
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(screen)
	screen.continue_requested.connect(_resume)
	screen.load_requested.connect(_resume)
	screen.new_campaign_requested.connect(func() -> void: change_scene.call(App.CAMPAIGN))
	screen.quick_battle_requested.connect(func() -> void: change_scene.call(App.BATTLE))
	screen.practice_requested.connect(_practise)
	screen.language_changed.connect(_rebuild)
	screen.quit_requested.connect(func() -> void: quit_game.call())
	Audio.music(&"menu")
	if open_options:
		screen.open_options()
	set_process(DisplayServer.get_name() == "headless")


func _process(_delta: float) -> void:
	_frames += 1
	if _frames < SMOKE_FRAMES:
		return
	set_process(false)
	# A test that merely instantiates the menu is not the tree's scene and stays here.
	if get_tree().current_scene == self:
		change_scene.call(App.BATTLE)


## Continues the campaign saved in the slot.
func _resume(slot: String) -> void:
	change_scene.call(App.CAMPAIGN, func(scene: Node) -> void: scene.set("launch_slot", slot))


func _practise(mode: StringName) -> void:
	match mode:
		PracticeMenu.JOUST:
			change_scene.call(App.JOUST)
		PracticeMenu.SIEGE:
			change_scene.call(App.SIEGE)
		PracticeMenu.RAID:
			change_scene.call(App.RAID)
		PracticeMenu.MERCHANT:
			change_scene.call(App.MERCHANT)


## Texts are set when a screen is built, so a new language needs a new menu; it opens with
## the options again, where the player was.
func _rebuild() -> void:
	change_scene.call(
		App.MAIN_MENU, func(scene: Node) -> void: scene.set("open_options", true)
	)
