extends Node
## Autoload "Audio": plays the sounds and the music of data/audio.json. Scenes name what
## happens (`Audio.play(&"battle_charge")`, `Audio.music(&"map")`); files, loudness and pitch
## are data. An unknown id is silent, so presentation code never waits for audio to exist.
## Volumes follow the player's options through the buses Sfx, Ui and Music.

const VOICES := 14
const VOICES_3D := 12

var bank: AudioBank
var music_player := MusicPlayer.new()

var _voices: Array[AudioStreamPlayer] = []
var _voices_3d: Array[AudioStreamPlayer3D] = []
var _next_voice := 0
var _next_voice_3d := 0
## Sound id -> engine time (ms) of its last start.
var _started: Dictionary[StringName, int] = {}
var _rng := RandomNumberGenerator.new()
var _ui_sounds := UiSounds.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bank = AudioBank.load_file()
	add_child(music_player)
	for i: int in VOICES:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)
	for i: int in VOICES_3D:
		var voice := AudioStreamPlayer3D.new()
		# Scenes look down from far above; loudness is mixed per sound, only the direction counts.
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		voice.panning_strength = 0.7
		add_child(voice)
		_voices_3d.append(voice)
	add_child(_ui_sounds)


## Plays a sound; volume_db and pitch add to the bank's values.
func play(id: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var sound := _due(id)
	if sound == null:
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	voice.stream = sound.streams[_rng.randi_range(0, sound.streams.size() - 1)]
	voice.bus = sound.bus
	voice.volume_db = sound.volume_db + volume_db
	voice.pitch_scale = pitch * _rng.randf_range(sound.pitch_min, sound.pitch_max)
	voice.play()


## Plays a sound at a place in the 3D scene, so it comes from the left or the right.
func play_at(id: StringName, place: Vector3, volume_db: float = 0.0) -> void:
	var sound := _due(id)
	if sound == null:
		return
	var voice := _voices_3d[_next_voice_3d]
	_next_voice_3d = (_next_voice_3d + 1) % VOICES_3D
	voice.stream = sound.streams[_rng.randi_range(0, sound.streams.size() - 1)]
	voice.bus = sound.bus
	voice.volume_db = sound.volume_db + volume_db
	voice.pitch_scale = _rng.randf_range(sound.pitch_min, sound.pitch_max)
	voice.global_position = place
	voice.play()


## Crossfades to a music track of the bank; an unknown or empty id fades to silence.
func music(id: StringName, intensity: float = 0.0) -> void:
	music_player.intensity = intensity
	music_player.play(bank.music.get(id))


## How driving the current track sounds: 0 calm … 1 all layers.
func set_intensity(value: float) -> void:
	music_player.intensity = value


## The sound when it exists and its cooldown has passed, else null.
func _due(id: StringName) -> AudioBank.Sound:
	var sound: AudioBank.Sound = bank.sounds.get(id)
	if sound == null:
		return null
	var now := Time.get_ticks_msec()
	if now - int(_started.get(id, -100000)) < roundi(sound.cooldown * 1000.0):
		return null
	_started[id] = now
	return sound
