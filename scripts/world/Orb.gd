class_name Orb
extends Area2D

var player_inside := false
# Set once the orb has been scored (hit or missed), so it is never counted twice.
var resolved := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_inside = true

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_inside = false
