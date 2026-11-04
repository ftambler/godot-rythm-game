class_name PlayerCamera
extends Camera2D

## Leads the player in its movement direction so more of the upcoming level is on screen.
## Runs on the physics tick so physics interpolation keeps it smooth at any refresh rate.

## How far ahead of the player the camera sits, in pixels.
@export var lead_distance := 100.0
## How quickly the camera swings to the new lead after a bounce. Higher is snappier.
@export var lead_sharpness := 3.0

@onready var player: Player = owner


func _physics_process(delta: float) -> void:
	position = position.lerp(_target(), 1.0 - exp(-lead_sharpness * delta))


## Jumps straight to the lead position, for when the player is placed at a level start.
func snap() -> void:
	position = _target()


func _target() -> Vector2:
	return PlayerDirection.to_vector(player.movement_direction) * lead_distance
