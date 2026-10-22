class_name SpeedTrigger
extends Area2D

@export var speed_type: PlayerSpeed.Type = PlayerSpeed.Type.SPEED_2


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.speed_type = speed_type
