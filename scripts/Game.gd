extends Node2D

@onready var player: Player = $Player
@onready var score_handler: ScoreHandler = $ScoreHandler
@onready var hud: HUD = $HUD

func _ready() -> void:
	player.hit_registered.connect(score_handler.handle_hit)
	score_handler.score_updated.connect(update_hud)

	update_hud(
		score_handler.get_score(),
		score_handler.get_accuracy()
	)


func update_hud(score: int, accuracy: float) -> void:
	hud.update_score(score)
	hud.update_accuracy(accuracy)
