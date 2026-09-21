extends Node2D

const WALL_SCENE := preload("res://scenes/game/Wall.tscn")
const ORB_SCENE := preload("res://scenes/game/Orb.tscn")

@onready var score_handler: ScoreHandler = $ScoreHandler
@onready var hud: HUD = $HUD
@onready var level_manager: LevelManager = $LevelManager
@onready var player: Player = $Player

var level: LevelData

func _ready() -> void:
	player.hit_registered.connect(score_handler.handle_hit)
	score_handler.score_updated.connect(update_hud)
	update_hud(score_handler.get_score(), score_handler.get_accuracy())
	player.object_hit.connect(level_manager.object_hit)
	
	_load_level()


func _load_level() -> void:
	level = LevelLoader.load_level("res://levels/test.json")

	if level == null:
		return
		
	player.position = level.player_position
	player.movement_direction = PlayerDirection.from_vector(level.player_direction)
	player.speed_type = level.player_speed
	level_manager.start_level(level)
	MusicController.play_music(level.music, level.song_start)
	
	print("Loaded level!")
	print("Music: ", level.music)
	print("Song duration: ", level.song_duration)
	print("Player position: ", level.player_position)
	print("Player direction: ", level.player_direction)
	print("Player speed: ", level.player_speed)
	print("Objects: ", level.objects.size())

func update_hud(score: int, accuracy: float) -> void:
	hud.update_score(score)
	hud.update_accuracy(accuracy)
