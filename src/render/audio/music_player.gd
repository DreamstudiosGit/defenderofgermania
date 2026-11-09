class_name MusicPlayer
extends Node
## Plays one music track at a time and crossfades to the next. A track's stems run in sync
## (GDD "Audio": built in layers, so the map sounds calm and the battle driving): the first
## always plays, the others fade in as `intensity` rises from 0 to 1.

const FADE_SECONDS := 1.6
const LAYER_FADE_SECONDS := 1.2
const SILENT_DB := -60.0

## 0 calm … 1 driving.
var intensity := 0.0:
	set(value):
		intensity = clampf(value, 0.0, 1.0)

var _decks: Array[AudioStreamPlayer] = []
var _tracks: Array[AudioBank.Track] = [null, null]
## Current layer volumes of each deck, linear 0…1.
var _levels: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array()]
var _active := 0
var _fade: Tween = null


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in 2:
		var deck := AudioStreamPlayer.new()
		deck.bus = AudioBank.BUS_MUSIC
		deck.volume_db = SILENT_DB
		add_child(deck)
		_decks.append(deck)


## Crossfades to the track; null fades to silence. The same track keeps playing.
func play(track: AudioBank.Track) -> void:
	if track == _tracks[_active]:
		return
	var old := _active
	_active = 1 - _active
	_tracks[_active] = track
	var deck := _decks[_active]
	deck.stop()
	if track != null:
		deck.stream = _synchronized(track)
		_levels[_active] = _targets(track.layers.size())
		_apply_levels(_active)
		deck.play()
	if _fade != null:
		_fade.kill()
	_fade = create_tween().set_parallel()
	if track != null:
		_fade.tween_property(deck, "volume_db", track.volume_db, FADE_SECONDS)
	var leaving := _decks[old]
	_fade.tween_property(leaving, "volume_db", SILENT_DB, FADE_SECONDS)
	_fade.chain().tween_callback(leaving.stop)
	_fade.tween_callback(func() -> void: _tracks[old] = null)


func _process(delta: float) -> void:
	var track := _tracks[_active]
	if track == null or track.layers.size() < 2:
		return
	var targets := _targets(track.layers.size())
	var levels := _levels[_active]
	var step := delta / LAYER_FADE_SECONDS
	for i: int in levels.size():
		levels[i] = move_toward(levels[i], targets[i], step)
	_levels[_active] = levels
	_apply_levels(_active)


## Layer k of n joins between intensity (k − 1)/(n − 1) and k/(n − 1).
func _targets(count: int) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(count)
	for i: int in count:
		result[i] = 1.0 if i == 0 else clampf(intensity * (count - 1) - (i - 1), 0.0, 1.0)
	return result


func _apply_levels(deck_index: int) -> void:
	var stream := _decks[deck_index].stream as AudioStreamSynchronized
	if stream == null:
		return
	var levels := _levels[deck_index]
	for i: int in levels.size():
		stream.set_sync_stream_volume(i, maxf(linear_to_db(levels[i]), SILENT_DB))


static func _synchronized(track: AudioBank.Track) -> AudioStreamSynchronized:
	var result := AudioStreamSynchronized.new()
	result.stream_count = track.layers.size()
	for i: int in track.layers.size():
		_loop(track.layers[i])
		result.set_sync_stream(i, track.layers[i])
	return result


static func _loop(stream: AudioStream) -> void:
	var ogg := stream as AudioStreamOggVorbis
	if ogg != null:
		ogg.loop = true
	var wav := stream as AudioStreamWAV
	if wav != null and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = roundi(wav.get_length() * wav.mix_rate)
