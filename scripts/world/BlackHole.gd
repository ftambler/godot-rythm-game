class_name BlackHole
extends Area2D

## Level exit: the level is complete once the player enters it.

signal player_entered


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_entered.emit()
