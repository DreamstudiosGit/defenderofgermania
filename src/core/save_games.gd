class_name SaveGames
extends RefCounted
## Saved campaigns (GDD "Komfort"): an autosave at the start of every round a human plays and
## three manual slots, as files in `folder`. A save holds a small header for the load screen
## (round, when, who played) and the GameState's bytes (GameState.to_bytes).

const AUTOSAVE := "autosave"
const SLOTS: Array[String] = ["slot_1", "slot_2", "slot_3"]
const EXTENSION := ".sav"

## Where saves live; tests point it elsewhere.
static var folder := "user://saves"


static func path(slot: String) -> String:
	return "%s/%s%s" % [folder, slot, EXTENSION]


static func exists(slot: String) -> bool:
	return FileAccess.file_exists(path(slot))


## Writes the state into the slot; OK or the file error.
static func write(state: GameState, slot: String) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(folder)
	if error != OK:
		return error
	var file := FileAccess.open(path(slot), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var humans: Array[String] = []
	for house: HouseState in state.houses.values():
		if not house.is_computer() and not house.is_eliminated:
			humans.append(house.id)
	var header := {
		"version": GameState.SAVE_VERSION,
		"turn": state.turn,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"saved_unix": Time.get_unix_time_from_system(),
		"humans": humans,
	}
	file.store_var(header)
	file.store_var(state.to_bytes())
	return OK


## The slot's header, or {} when there is no readable save.
static func header(slot: String) -> Dictionary:
	if not exists(slot):
		return {}
	var file := FileAccess.open(path(slot), FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = file.get_var()
	return data if data is Dictionary else {}


## The saved state, or null when the slot is empty, broken or of another save version.
static func read(slot: String) -> GameState:
	if not exists(slot):
		return null
	var file := FileAccess.open(path(slot), FileAccess.READ)
	if file == null:
		return null
	var head: Variant = file.get_var() if file.get_length() > 0 else null
	if not head is Dictionary or file.get_position() >= file.get_length():
		push_error("save %s: not a save file" % slot)
		return null
	var bytes: Variant = file.get_var()
	if not bytes is PackedByteArray:
		push_error("save %s: not a save file" % slot)
		return null
	return GameState.from_bytes(bytes)


## The newest save of the autosave and the slots ("Weiterspielen"), or "".
static func latest() -> String:
	var best := ""
	var newest := -1.0
	for slot: String in [AUTOSAVE] + SLOTS:
		var head := header(slot)
		var when: float = head.get("saved_unix", -1.0)
		if not head.is_empty() and when > newest:
			best = slot
			newest = when
	return best


static func remove(slot: String) -> Error:
	if not exists(slot):
		return OK
	return DirAccess.remove_absolute(path(slot))
