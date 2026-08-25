class_name Player
extends CharacterBody2D


@export var speed: float = 300.0

@onready var shield: PlayerShield = $Shield
@onready var score_handler: ScoreHandler = $"../ScoreHandler"

var movement_direction: PlayerDirection.Direction = \
	PlayerDirection.Direction.RIGHT


func _physics_process(delta: float) -> void:
	move_player(delta)


func move_player(delta: float) -> void:
	var direction := PlayerDirection.to_vector(movement_direction)

	velocity = direction * speed

	var collision := move_and_collide(velocity * delta)

	if collision:
		handle_collision(collision)

signal hit_registered(result: HitResult.Type)

func handle_collision(collision: KinematicCollision2D) -> void:
	var wall := collision.get_collider()

	if wall is Wall:
		var hit_result := ShieldEvaluator.evaluate(
			wall.wall_rotation,
			movement_direction,
			shield.direction,
			shield.active
		)

		hit_registered.emit(hit_result)

		movement_direction = PlayerBounce.get_bounce(
			movement_direction,
			wall.wall_rotation
		)
