class_name Player
extends CharacterBody2D

@onready var shield: PlayerShield = $Shield
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var orb_detector: Area2D = $OrbDetector

@export var speed_type: PlayerSpeed.Type = PlayerSpeed.Type.SPEED_2

var speed: float:
	get:
		return PlayerSpeed.get_value(speed_type)
		
signal object_hit(object: Node)

var movement_direction: PlayerDirection.Direction = PlayerDirection.Direction.DOWN_RIGHT

func _physics_process(delta: float) -> void:
	move_player(delta)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("hit_orb"):
		hit_orb()

func move_player(delta: float) -> void:
	var direction := PlayerDirection.to_vector(movement_direction)

	velocity = direction * speed

	var collision := move_and_collide(velocity * delta)

	if collision:
		handle_collision(collision)

signal hit_registered(result: HitResult.Type)

func hit_orb() -> void:
	var areas := orb_detector.get_overlapping_areas()
	var matched_orb: Orb

	for area in areas:
		if area is Orb:
			matched_orb = area
			break

	if matched_orb != null:
		for area in areas:
			if area is Orb and area.global_position.is_equal_approx(matched_orb.global_position):
				object_hit.emit(area)

		hit_registered.emit(HitResult.Type.FULL)
		return

	hit_registered.emit(HitResult.Type.MISS)

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
		object_hit.emit(wall)

		movement_direction = PlayerBounce.get_bounce(
			movement_direction,
			wall.wall_rotation
		)
