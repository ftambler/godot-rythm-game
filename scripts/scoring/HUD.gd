class_name HUD
extends CanvasLayer


@onready var score_label: Label = $ScoreLabel
@onready var accuracy_label: Label = $AccuracyLabel


func update_score(score: int) -> void:
	score_label.text = "Score: " + str(score)


func update_accuracy(accuracy: float) -> void:
	accuracy_label.text = "Accuracy: " + str(snapped(accuracy * 100.0, 0.1)) + "%"
