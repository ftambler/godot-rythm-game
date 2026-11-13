class_name Player
extends CharacterBody2D

@onready var shield: PlayerShield = $Shield
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var orb_detector: Area2D = $OrbDetector
@onready var camera: PlayerCamera = $Camera2D
@onready var aura: PlayerAura = $Aura

@export var speed_type: PlayerSpeed.Type = PlayerSpeed.Type.SPEED_2

var speed: float:
	get:
		return PlayerSpeed.get_value(speed_type)
		
signal object_hit(object: Node)

var movement_direction: PlayerDirection.Direction = PlayerDirection.Direction.DOWN_RIGHT

# Orbs whose hitboxes overlapped the detector last physics frame.
var _orbs_in_reach: Array = []

func _physics_process(delta: float) -> void:
	move_player(delta)
	check_missed_orbs()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("hit_orb"):
		hit_orb()

func move_player(delta: float) -> void:
	var direction := PlayerDirection.to_vector(movement_direction)

	velocity = direction * speed

	var collision := move_and_collide(velocity * delta)

	if collision:
		handle_collision(collision)

		# Spend the rest of this frame's movement in the new direction, so
		# every bounce doesn't drop a bit of distance and fall behind the music.
		if collision.get_collider() is Wall:
			var remainder := collision.get_remainder().length()
			var bounced := move_and_collide(PlayerDirection.to_vector(movement_direction) * remainder)
			if bounced:
				handle_collision(bounced)

signal hit_registered(result: HitResult.Type)

func hit_orb() -> void:
	var areas := orb_detector.get_overlapping_areas()
	var matched_orb: Orb
	var result := HitResult.Type.HALF

	# The orb's own area is the full-hit box; its HalfHitArea child is the outer ring.
	for area in areas:
		if area is Orb and not area.resolved:
			matched_orb = area
			result = HitResult.Type.FULL
			break

		if matched_orb == null and area.get_parent() is Orb and not area.get_parent().resolved:
			matched_orb = area.get_parent()

	# Pressing with no orb in reach is not counted.
	if matched_orb == null:
		return

	for area in areas:
		if area is Orb and not area.resolved and area.global_position.is_equal_approx(matched_orb.global_position):
			area.resolved = true
			object_hit.emit(area)

	hit_registered.emit(result)

func check_missed_orbs() -> void:
	var in_reach: Array = []

	for area in orb_detector.get_overlapping_areas():
		var orb: Node = area if area is Orb else area.get_parent()
		if orb is Orb and not in_reach.has(orb):
			in_reach.append(orb)

	# An orb that left reach without being hit counts as a miss.
	for orb in _orbs_in_reach:
		if is_instance_valid(orb) and not orb.resolved and not orb.is_queued_for_deletion() and not in_reach.has(orb):
			orb.resolved = true
			object_hit.emit(orb)
			hit_registered.emit(HitResult.Type.MISS)

	_orbs_in_reach = in_reach

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
