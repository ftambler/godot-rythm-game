extends Node2D

const WALL_SCENE := preload("res://scenes/game/Wall.tscn")
const ORB_SCENE := preload("res://scenes/game/Orb.tscn")

@onready var score_handler: ScoreHandler = $ScoreHandler
@onready var hud: HUD = $HUD
@onready var level_manager: LevelManager = $LevelManager
@onready var player: Player = $Player
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var level_intro: LevelIntro = $LevelIntro
@onready var results_screen: ResultsScreen = $ResultsScreen

var level: LevelData
var _run_finished: bool = false

func _ready() -> void:
	player.hit_registered.connect(score_handler.handle_hit)
	score_handler.score_updated.connect(update_hud)
	score_handler.gameplay_stats_updated.connect(update_gameplay_hud)
	score_handler.health_depleted.connect(_on_health_depleted)
	level_manager.level_finished.connect(_on_level_finished)
	level_intro.start_requested.connect(_start_level)
	results_screen.replay_requested.connect(_replay_level)
	results_screen.menu_requested.connect(_return_to_menu)
	update_hud(score_handler.get_score(), score_handler.get_accuracy())
	update_gameplay_hud(score_handler.combo, score_handler.health)
	player.object_hit.connect(level_manager.object_hit)
	_load_level()


func _load_level() -> void:
	level = LevelLoader.load_level("res://levels/test.json")

	if level == null:
		return
		
	player.position = level.player_position
	player.movement_direction = PlayerDirection.from_vector(level.player_direction)
	player.speed_type = level.player_speed
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
	MusicController.play_music(level.music, level.song_start)

func _on_level_finished() -> void:
	_finish_level(true)

func _on_health_depleted() -> void:
	_finish_level(false)

func _finish_level(did_win: bool) -> void:
	if _run_finished:
		return

	_run_finished = true
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
