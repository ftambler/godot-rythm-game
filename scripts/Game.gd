extends Node2D

const WALL_SCENE := preload("res://scenes/game/Wall.tscn")
const ORB_SCENE := preload("res://scenes/game/Orb.tscn")
# Music sync: gameplay speeds up or slows down by at most MAX_SYNC_ADJUST
# (5%) to catch up with the song, closing SYNC_GAIN of the gap per second.
# Gaps under SYNC_DEADZONE (s) are left alone so jitter doesn't wobble it.
const MAX_SYNC_ADJUST := 0.05
const SYNC_GAIN := 0.5
const SYNC_DEADZONE := 0.005

@onready var score_handler: ScoreHandler = $ScoreHandler
@onready var hud: HUD = $HUD
@onready var level_manager: LevelManager = $LevelManager
@onready var player: Player = $Player
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var level_intro: LevelIntro = $LevelIntro
@onready var results_screen: ResultsScreen = $ResultsScreen

var level: LevelData
var _run_finished: bool = false
# Kept so the song stays cached and starting it doesn't stall the first frame.
var _song: AudioStream
# Song time the gameplay has reached, counted on the physics clock.
var _gameplay_time := 0.0
var _syncing := false

func _ready() -> void:
	player.hit_registered.connect(score_handler.handle_hit)
	player.hit_registered.connect(hud.flash_hit)
	score_handler.score_updated.connect(update_hud)
	score_handler.gameplay_stats_updated.connect(update_gameplay_hud)
	score_handler.health_depleted.connect(_on_health_depleted)
	level_manager.level_finished.connect(_on_level_finished)
	level_intro.start_requested.connect(_start_level)
	pause_menu.restart_requested.connect(_replay_level)
	results_screen.replay_requested.connect(_replay_level)
	results_screen.menu_requested.connect(_return_to_menu)
	update_hud(score_handler.get_score(), score_handler.get_accuracy())
	update_gameplay_hud(score_handler.combo, score_handler.health)
	player.object_hit.connect(level_manager.object_hit)
	_load_level()


func _load_level() -> void:
	level = LevelLoader.load_level(LevelCatalog.path_for(LevelCatalog.selected_id))

	if level == null:
		return

	_song = MusicController.load_music(level.music)

	player.position = level.player_position
	player.movement_direction = PlayerDirection.from_vector(level.player_direction)
	player.speed_type = level.player_speed
	# Start the camera already leading, and stop interpolation from sliding in from the old position.
	player.camera.snap()
	player.reset_physics_interpolation()
	# Cut the menu loop so the level song starts on time once the intro ends.
	MusicController.stop_music(0.0)
	get_tree().paused = true
	level_intro.open(level)
	
	print("Loaded level!")
	print("Music: ", level.music)
	print("Song duration: ", level.song_duration)
	print("Player position: ", level.player_position)
	print("Player direction: ", level.player_direction)
	print("Player speed: ", level.player_speed)
	print("Objects: ", level.objects.size())

func _start_level() -> void:
	level_intro.close()
	pause_menu.set_pause_enabled(true)
	level_manager.start_level(level)
	get_tree().paused = false
	# No fade-in: the first beats can come within a fraction of a second.
	MusicController.play_music(level.music, level.song_start, 0.0)
	_gameplay_time = level.song_start
	_syncing = true

func _physics_process(delta: float) -> void:
	if not _syncing:
		return

	_gameplay_time += delta
	_sync_to_music()

## The player moves on the physics clock and the song on the audio clock, so
## nudge the game speed until the level matches what is being heard.
func _sync_to_music() -> void:
	if not MusicController.is_music_playing():
		Engine.time_scale = 1.0
		return

	var drift := MusicController.get_song_position() - _gameplay_time
	if absf(drift) < SYNC_DEADZONE:
		Engine.time_scale = 1.0
	else:
		Engine.time_scale = 1.0 + clampf(drift * SYNC_GAIN, -MAX_SYNC_ADJUST, MAX_SYNC_ADJUST)

func _stop_sync() -> void:
	_syncing = false
	Engine.time_scale = 1.0

func _exit_tree() -> void:
	# time_scale is global; don't leave menus running fast or slow.
	Engine.time_scale = 1.0

func _on_level_finished() -> void:
	_finish_level(true)

func _on_health_depleted() -> void:
	_finish_level(false)

func _finish_level(did_win: bool) -> void:
	if _run_finished:
		return

	_run_finished = true
	_stop_sync()
	get_tree().paused = true
	pause_menu.set_pause_enabled(false)
	results_screen.open(score_handler, did_win)

func _replay_level() -> void:
	get_tree().paused = false
	await MusicController.stop_music(0.0)
	get_tree().reload_current_scene()

func _return_to_menu() -> void:
	get_tree().paused = false
	await MusicController.stop_music(0.0)
	get_tree().change_scene_to_file("res://scenes/ui/Menu.tscn")

func update_hud(score: int, accuracy: float) -> void:
	hud.update_score(score)
	hud.update_accuracy(accuracy)

func update_gameplay_hud(combo: int, health: int) -> void:
	hud.update_combo(combo)
	hud.update_health(health)
