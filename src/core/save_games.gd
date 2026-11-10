class_name SaveGames
extends RefCounted
## Saved campaigns (GDD "Komfort"): an autosave at the start of every round a human plays and
## three manual slots, as files in `folder` (SaveFile: a small header for the load screen and
## the GameState's bytes). A write never destroys the save before it: the new file is written
## beside the slot and swapped in once it is complete, and the save it replaces stays as the
## slot's backup, which read() falls back to when the slot's own file is damaged.

enum Status {
	EMPTY,
	INTACT,
	## The slot's own file is damaged or missing; its backup, the save before, is loaded.
	RECOVERED,
	## Damaged, and no backup to fall back to.
	BROKEN,
	## Written by another save version (GameState.SAVE_VERSION); it cannot be loaded.
	OTHER_VERSION,
}

const AUTOSAVE := "autosave"
const SLOTS: Array[String] = ["slot_1", "slot_2", "slot_3"]
const EXTENSION := ".sav"
const BACKUP_EXTENSION := ".bak"
const TEMPORARY_EXTENSION := ".tmp"

## Where saves live; tests point it elsewhere.
static var folder := "user://saves"


static func path(slot: String) -> String:
	return "%s/%s%s" % [folder, slot, EXTENSION]


## The save the slot held before its last write.
static func backup_path(slot: String) -> String:
	return "%s/%s%s" % [folder, slot, BACKUP_EXTENSION]


## Where a write builds the slot's new file; one left behind is the rest of a write that was
## interrupted and is never read.
static func temporary_path(slot: String) -> String:
	return "%s/%s%s" % [folder, slot, TEMPORARY_EXTENSION]


static func exists(slot: String) -> bool:
	return FileAccess.file_exists(path(slot))


## Writes the state into the slot; OK or the error, and then the slot is as it was before.
static func write(state: GameState, slot: String) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(folder)
	if error != OK:
		return error
	var bytes := state.to_bytes()
	var temporary := temporary_path(slot)
	error = SaveFile.store(temporary, SaveFile.encode(SaveFile.header_for(state, bytes), bytes))
	if error == OK:
		error = _swap_in(temporary, slot)
	if error != OK and FileAccess.file_exists(temporary):
		DirAccess.remove_absolute(temporary)
	return error


## What the slot holds, without loading it and without logging anything.
static func status(slot: String) -> Status:
	var own := SaveFile.load_file(path(slot))
	if own.kind == SaveFile.Kind.VALID:
		return Status.INTACT
	if own.kind == SaveFile.Kind.OTHER_VERSION:
		return Status.OTHER_VERSION
	if SaveFile.load_file(backup_path(slot)).kind == SaveFile.Kind.VALID:
		return Status.RECOVERED
	return Status.EMPTY if own.kind == SaveFile.Kind.MISSING else Status.BROKEN


## True if read() returns the slot's campaign (or the one in its backup).
static func is_loadable(slot: String) -> bool:
	return status(slot) in [Status.INTACT, Status.RECOVERED]


## The header of the slot's save — of its backup while the status is RECOVERED — or {} when
## there is no readable save. Its fields always have their types (SaveFile.header).
static func header(slot: String) -> Dictionary:
	return _source(slot).header


## The saved state, or null when the slot is empty, broken or of another save version.
static func read(slot: String) -> GameState:
	var source := _source(slot)
	match source.kind:
		SaveFile.Kind.MISSING:
			return null
		SaveFile.Kind.VALID:
			return GameState.from_bytes(source.state_bytes)
		SaveFile.Kind.OTHER_VERSION:
			var version: int = source.header["version"]
			push_error(
				"save %s: save version %d is not supported (expected %d)"
				% [slot, version, GameState.SAVE_VERSION]
			)
			return null
	push_error("save %s: not a save file" % slot)
	return null


## The newest save that can be loaded, of the autosave and the slots ("Weiterspielen"), or "".
static func latest() -> String:
	var best := ""
	var newest := -INF
	for slot: String in [AUTOSAVE] + SLOTS:
		if not is_loadable(slot):
			continue
		var when: float = header(slot)["saved_unix"]
		if when > newest:
			best = slot
			newest = when
	return best


## Removes the slot's save with its backup and what an interrupted write left behind.
static func remove(slot: String) -> Error:
	var result := OK
	for file: String in [path(slot), backup_path(slot), temporary_path(slot)]:
		if FileAccess.file_exists(file):
			var error := DirAccess.remove_absolute(file)
			if error != OK:
				result = error
	return result


## The file the slot's save is taken from: its own, or its backup while that stands in.
static func _source(slot: String) -> SaveFile:
	var from_backup := status(slot) == Status.RECOVERED
	return SaveFile.load_file(backup_path(slot) if from_backup else path(slot))


## Puts the finished temporary file in the slot's place. The save it replaces becomes the
## backup — unless that save is damaged: then the backup at hand is the better one and stays.
static func _swap_in(temporary: String, slot: String) -> Error:
	var target := path(slot)
	var backup := backup_path(slot)
	var replaced := SaveFile.load_file(target).kind
	var keeps_old := replaced in [SaveFile.Kind.VALID, SaveFile.Kind.OTHER_VERSION]
	var error := DirAccess.rename_absolute(target, backup) if keeps_old else OK
	if error != OK:
		return error
	error = DirAccess.rename_absolute(temporary, target)
	if error != OK and keeps_old:
		DirAccess.rename_absolute(backup, target)
	return error
