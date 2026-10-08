class_name LevelManager
extends Node


const WALL_SCENE := preload("res://scenes/game/Wall.tscn")
const ORB_SCENE := preload("res://scenes/game/Orb.tscn")
const SPEED_TRIGGER_SCENE := preload("res://scenes/game/SpeedTrigger.tscn")

@onready var walls: Node2D = $Walls
@onready var orbs: Node2D = $Orbs
@onready var speed_triggers: Node2D = $SpeedTriggers

var level: LevelData
var level_time: float = 0.0
var _has_finished := false

signal level_finished

var spawn_queue: Array[LevelObjectData] = []
var despawn_queue: Array[LevelObjectData] = []

var active_objects: Dictionary = {}

func start_level(level_data: LevelData) -> void:
	level = level_data
	level_time = level.song_start
	_has_finished = false

	spawn_queue = level.objects.duplicate()
	spawn_queue.sort_custom(_sort_by_start)

	despawn_queue = level.objects.duplicate()
	despawn_queue.sort_custom(_sort_by_end)

	active_objects.clear()


func _process(delta: float) -> void:
	if level == null or _has_finished:
		return

	level_time += delta

	_process_spawns()
	_process_despawns()

	if level_time >= level.song_duration:
		_has_finished = true
		level_finished.emit()


func _process_spawns() -> void:
	while not spawn_queue.is_empty():
		var data := spawn_queue[0]

		if data.start > level_time:
			break

		spawn_queue.pop_front()
		_spawn_object(data)


func _process_despawns() -> void:
	while not despawn_queue.is_empty():
		var data := despawn_queue[0]

		if data.end > level_time:
			break

		despawn_queue.pop_front()

		if active_objects.has(data):
			_despawn_object(data)


func _spawn_object(data: LevelObjectData) -> void:
	var object: Node2D

	match data.type:
		"walls":
			object = WALL_SCENE.instantiate()
			var wall: Wall = object
			wall.wall_rotation = data.wall_type
			walls.add_child(object)

		"orb":
			object = ORB_SCENE.instantiate()
			orbs.add_child(object)

		"speed_trigger":
			object = SPEED_TRIGGER_SCENE.instantiate()
			var speed_trigger: SpeedTrigger = object
			speed_trigger.speed_type = data.speed_type
			speed_triggers.add_child(object)

		_:
			push_error("Unknown level object type: " + data.type)
			return

	object.position = data.position
	active_objects[data] = object


func _despawn_object(data: LevelObjectData) -> void:
	var object: Node = active_objects[data]

	if is_instance_valid(object):
		object.queue_free()

	active_objects.erase(data)


func object_hit(object: Node) -> void:
	if object is Orb or object is Wall:
		for data in active_objects:
			if active_objects[data] == object:
				_despawn_object(data)
				return


func _sort_by_start(a: LevelObjectData, b: LevelObjectData) -> bool:
	return a.start < b.start


func _sort_by_end(a: LevelObjectData, b: LevelObjectData) -> bool:
	return a.end < b.end
