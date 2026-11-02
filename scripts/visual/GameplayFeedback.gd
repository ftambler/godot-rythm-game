class_name GameplayFeedback
extends Node2D

## Spawns world-space hit effects from the player's existing signals.
## Walls and orbs are despawned by LevelManager as soon as they are hit, so their
## transforms are captured here and the effect is drawn by a detached HitEffect.
##
## Player emits `object_hit` and `hit_registered` in different orders for walls
## and orbs, so both are collected during the frame and resolved together.

@export var player: Player

var _pending_result: HitResult.Type = HitResult.Type.MISS
var _has_pending_result := false
var _pending_walls: Array[Transform2D] = []
var _pending_orbs: Array[Vector2] = []
var _flush_queued := false


func _ready() -> void:
	z_index = 2
	if player == null:
		return
	player.hit_registered.connect(_on_hit_registered)
	player.object_hit.connect(_on_object_hit)


func _on_hit_registered(result: HitResult.Type) -> void:
	_pending_result = result
	_has_pending_result = true
	_queue_flush()


func _on_object_hit(object: Node) -> void:
	if object is Wall:
		_pending_walls.append(object.global_transform)
	elif object is Orb:
		_pending_orbs.append(object.global_position)
	_queue_flush()


func _queue_flush() -> void:
	if _flush_queued:
		return
	_flush_queued = true
	_flush.call_deferred()


func _flush() -> void:
	_flush_queued = false
	if not _has_pending_result:
		_pending_walls.clear()
		_pending_orbs.clear()
		return

	var color := Palette.hit_result_color(_pending_result)
	for wall_transform in _pending_walls:
		HitEffect.spawn_wall(self, wall_transform, player.global_position, color)
	for orb_position in _pending_orbs:
		HitEffect.spawn_ring(self, orb_position, color)

	_pending_walls.clear()
	_pending_orbs.clear()
	_has_pending_result = false
