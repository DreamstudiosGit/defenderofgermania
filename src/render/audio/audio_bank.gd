class_name AudioBank
extends RefCounted
## The sounds and music of data/audio.json (presentation-only): which files an id plays, on
## which bus, how loud, how much the pitch varies and how soon it may sound again.

const PATH := "res://data/audio.json"
const BUS_SFX := &"Sfx"
const BUS_UI := &"Ui"
const BUS_MUSIC := &"Music"
const BUSES: Array[StringName] = [BUS_SFX, BUS_UI, BUS_MUSIC]
const DEFAULT_COOLDOWN := 0.05

var sounds: Dictionary[StringName, Sound] = {}
var music: Dictionary[StringName, Track] = {}


class Sound:
	var streams: Array[AudioStream] = []
	var bus: StringName = BUS_SFX
	var volume_db := 0.0
	var pitch_min := 1.0
	var pitch_max := 1.0
	## Seconds before the same id may start again, so twenty hits in one tick sound as one.
	var cooldown := DEFAULT_COOLDOWN


class Track:
	## Stems of equal length; the first always plays, the others join as the intensity rises.
	var layers: Array[AudioStream] = []
	var volume_db := 0.0


## Loads the bank; ids whose files are missing are left out with a warning, so the game runs
## (silent there) while audio is still being made.
static func load_file(path: String = PATH) -> AudioBank:
	var bank := AudioBank.new()
	var data: Variant = DataReader.load_json(path)
	if not data is Dictionary:
		push_error("audio: %s is not a settings object" % path)
		return bank
	var reader := DataReader.new()
	var root: Dictionary = data
	var sound_data := reader.object(root, "sounds")
	for id: String in sound_data:
		reader.context = "sounds.%s" % id
		var sound := _sound(reader, reader.object(sound_data, id))
		if not sound.streams.is_empty():
			bank.sounds[StringName(id)] = sound
	var music_data := reader.object(root, "music")
	for id: String in music_data:
		reader.context = "music.%s" % id
		var track := _track(reader, reader.object(music_data, id))
		if not track.layers.is_empty():
			bank.music[StringName(id)] = track
	for problem: String in reader.errors:
		push_error("audio: %s" % problem)
	return bank


static func _sound(reader: DataReader, data: Dictionary) -> Sound:
	var sound := Sound.new()
	sound.streams = _streams(reader, data, "files")
	sound.volume_db = reader.number(data, "volume_db", 0.0)
	sound.cooldown = reader.number(data, "cooldown", DEFAULT_COOLDOWN)
	var bus := StringName(reader.text(data, "bus", BUS_SFX))
	if bus in BUSES:
		sound.bus = bus
	else:
		reader.errors.append("%s.bus: unknown bus %s" % [reader.context, bus])
	if data.has("pitch"):
		var pitch := reader.numbers(data, "pitch")
		if pitch.size() == 2 and pitch[0] > 0.0 and pitch[1] >= pitch[0]:
			sound.pitch_min = pitch[0]
			sound.pitch_max = pitch[1]
		else:
			reader.errors.append("%s.pitch: expected [min, max]" % reader.context)
	return sound


static func _track(reader: DataReader, data: Dictionary) -> Track:
	var track := Track.new()
	track.layers = _streams(reader, data, "layers")
	track.volume_db = reader.number(data, "volume_db", 0.0)
	return track


static func _streams(reader: DataReader, data: Dictionary, key: String) -> Array[AudioStream]:
	var result: Array[AudioStream] = []
	for path: String in reader.strings(data, key):
		if not ResourceLoader.exists(path, "AudioStream"):
			push_warning("audio: %s: no file %s" % [reader.context, path])
			continue
		result.append(load(path) as AudioStream)
	return result
