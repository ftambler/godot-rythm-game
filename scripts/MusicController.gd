extends Node

const MUSIC_DIRECTORY := "res://levels/music/"
const MIN_VOLUME_DB := -80.0
const SETTINGS_PATH := "user://settings.cfg"
const MENU_MUSIC := "res://audio/ui/menuLoop.mp3"
const UI_BUTTON_SOUND := preload("res://audio/ui/menuButton.mp3")
const UI_SOUND_POLYPHONY := 4
# Keyboard actions that move focus between controls; focus changes caused by
# anything else (e.g. a menu calling grab_focus() on open) stay silent.
const UI_NAVIGATION_ACTIONS: Array[StringName] = [
	&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev",
]

var _player: AudioStreamPlayer
var _ui_player: AudioStreamPlayer
var _last_ui_sound_frame := -1
var _volume := 1.0
var _sfx_volume := 1.0
var _fade_tween: Tween
# Read once: AudioServer.get_output_latency() is too costly to call every frame.
var _output_latency := 0.0

func _ready() -> void:
	# Fades and UI sounds keep running while the game is paused (pause menu,
	# level intro); the music itself still pauses with the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_set_bus_volume("Music", _volume)
	_set_bus_volume("SFX", _sfx_volume)
	_output_latency = AudioServer.get_output_latency()
	_player = AudioStreamPlayer.new()
	_player.name = "MusicPlayer"
	_player.bus = "Music"
	_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_player)
	_ui_player = AudioStreamPlayer.new()
	_ui_player.name = "UiSoundPlayer"
	_ui_player.bus = "SFX"
	_ui_player.stream = UI_BUTTON_SOUND
	_ui_player.max_polyphony = UI_SOUND_POLYPHONY
	add_child(_ui_player)
	get_tree().node_added.connect(_on_node_added)
	# The main scene's nodes are added before this autoload is ready, so
	# node_added misses them; hook those up once startup has finished.
	_hook_existing_buttons.call_deferred(get_tree().root)

func play_menu_music() -> void:
	# Optional until the track is added to the project.
	if ResourceLoader.exists(MENU_MUSIC):
		play_music(MENU_MUSIC, 0.0, 1.0, true)
	else:
		# Don't carry a level preview from the level select into the menu.
		stop_music()

## Plays the UI click/hover sound on the SFX bus. Repeated calls within one
## frame (e.g. a button's hover and the screen reacting to the same input)
## play it once.
func play_ui_sound() -> void:
	var frame := Engine.get_process_frames()
	if frame == _last_ui_sound_frame:
		return
	_last_ui_sound_frame = frame
	_ui_player.play()

## Loads a song by file name (relative to MUSIC_DIRECTORY) or res:// path.
## Holding on to the result keeps it cached, so a later play_music of the
## same song starts without a loading hitch.
func load_music(file_name: String) -> AudioStream:
	var music_path := file_name
	if not music_path.begins_with("res://"):
		music_path = MUSIC_DIRECTORY + file_name

	if not ResourceLoader.exists(music_path):
		push_warning("Music file not found: " + music_path)
		return null

	var stream := load(music_path) as AudioStream
	if stream == null:
		push_warning("Unable to load music file: " + music_path)
	return stream

func play_music(file_name: String, start_position := 0.0, fade_duration := 1.0, loop := false) -> void:
	var stream := load_music(file_name)
	if stream == null:
		return

	if _player.playing and _player.stream == stream:
		# Undoes a fade-out still in progress (e.g. browsing away from a song
		# and straight back); killing that tween also cancels its pending switch.
		fade_in(fade_duration)
		return

	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = loop

	if _player.playing:
		await fade_out(fade_duration)

	_player.stream = stream
	_player.volume_db = MIN_VOLUME_DB
	_player.play(start_position)
	await fade_in(fade_duration)

func stop_music(fade_duration := 1.0) -> void:
	if not _player.playing:
		return

	if fade_duration > 0.0:
		await fade_out(fade_duration)
	else:
		_kill_fade()
	_player.stop()
	_player.stream = null

func is_music_playing() -> bool:
	return _player.playing

## Song position (s) of what is coming out of the speakers right now. More
## precise than get_playback_position(), which only moves once per audio mix.
func get_song_position() -> float:
	return _player.get_playback_position() + AudioServer.get_time_since_last_mix() - _output_latency

func set_volume(value: float) -> void:
	_volume = clampf(value, 0.0, 1.0)
	_save_setting("audio", "music_volume", _volume)
	_set_bus_volume("Music", _volume)

func get_volume() -> float:
	return _volume

func set_sfx_volume(value: float) -> void:
	_sfx_volume = clampf(value, 0.0, 1.0)
	_save_setting("audio", "sfx_volume", _sfx_volume)
	_set_bus_volume("SFX", _sfx_volume)

func get_sfx_volume() -> float:
	return _sfx_volume

## Fades the player to full volume; the music volume setting lives on the Music bus.
func fade_in(duration: float) -> void:
	_kill_fade()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", 0.0, maxf(duration, 0.0))
	await _fade_tween.finished

func fade_out(duration: float) -> void:
	_kill_fade()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", MIN_VOLUME_DB, maxf(duration, 0.0))
	await _fade_tween.finished

func _on_node_added(node: Node) -> void:
	# Re-parented buttons are added again; they already have the sounds hooked up.
	if node is BaseButton and not node.pressed.is_connected(play_ui_sound):
		node.mouse_entered.connect(_on_button_hovered.bind(node))
		node.focus_entered.connect(_on_button_focused)
		node.pressed.connect(play_ui_sound)

func _hook_existing_buttons(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_hook_existing_buttons(child)

func _on_button_hovered(button: BaseButton) -> void:
	if not button.disabled:
		play_ui_sound()

func _on_button_focused() -> void:
	for action in UI_NAVIGATION_ACTIONS:
		if Input.is_action_just_pressed(action):
			play_ui_sound()
			return

func _volume_to_db(value: float) -> float:
	return linear_to_db(maxf(value, 0.0001))

func _kill_fade() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)

func _set_bus_volume(bus_name: String, value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, _volume_to_db(value))

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	_volume = clampf(config.get_value("audio", "music_volume", _volume), 0.0, 1.0)
	_sfx_volume = clampf(config.get_value("audio", "sfx_volume", _sfx_volume), 0.0, 1.0)

func _save_setting(section: String, key: String, value: Variant) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(section, key, value)
	config.save(SETTINGS_PATH)
