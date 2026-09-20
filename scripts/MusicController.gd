extends Node

const MUSIC_DIRECTORY := "res://audio/"
const MIN_VOLUME_DB := -80.0

var _player: AudioStreamPlayer
var _volume := 1.0
var _fade_tween: Tween

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "MusicPlayer"
	add_child(_player)

func play_music(file_name: String, start_position := 0.0, fade_duration := 1.0) -> void:
	var music_path := file_name
	if not music_path.begins_with("res://"):
		music_path = MUSIC_DIRECTORY + file_name

	if not ResourceLoader.exists(music_path):
		push_warning("Music file not found: " + music_path)
		return

	var stream := load(music_path) as AudioStream
	if stream == null:
		push_warning("Unable to load music file: " + music_path)
		return

	if _player.playing and _player.stream == stream:
		return

	if _player.playing:
		await fade_out(fade_duration)

	_player.stream = stream
	_player.volume_db = MIN_VOLUME_DB
	_player.play(start_position)
	await fade_in(fade_duration)

func stop_music(fade_duration := 1.0) -> void:
	if not _player.playing:
		return

	await fade_out(fade_duration)
	_player.stop()
	_player.stream = null

func set_volume(value: float) -> void:
	_volume = clampf(value, 0.0, 1.0)
	if _player and _player.playing:
		_player.volume_db = _volume_to_db(_volume)

func get_volume() -> float:
	return _volume

func fade_in(duration: float) -> void:
	_kill_fade()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", _volume_to_db(_volume), maxf(duration, 0.0))
	await _fade_tween.finished

func fade_out(duration: float) -> void:
	_kill_fade()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", MIN_VOLUME_DB, maxf(duration, 0.0))
	await _fade_tween.finished

func _volume_to_db(value: float) -> float:
	return linear_to_db(maxf(value, 0.0001))

func _kill_fade() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
