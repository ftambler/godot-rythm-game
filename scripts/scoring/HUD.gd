class_name HUD
extends CanvasLayer


@onready var score_label: Label = $ScoreLabel
@onready var accuracy_label: Label = $AccuracyLabel
@onready var combo_label: Label = $ComboLabel
@onready var health_label: Label = $HealthLabel
@onready var health_bar: ProgressBar = $HealthBar


func update_score(score: int) -> void:
	score_label.text = "Score: " + str(score)


func update_accuracy(accuracy: float) -> void:
	accuracy_label.text = "Accuracy: " + str(snapped(accuracy * 100.0, 0.1)) + "%"


func update_combo(combo: int) -> void:
	combo_label.text = str(combo)


func update_health(health: int) -> void:
	health_label.text = str(health) + "%"
	health_bar.value = health
