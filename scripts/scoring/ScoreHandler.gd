class_name ScoreHandler
extends Node

const MAX_HEALTH: int = 100

@export_range(1, MAX_HEALTH, 1) var health_lost_per_miss: int = 10
@export_range(0, MAX_HEALTH, 1) var health_gained_per_full_hit: int = 5

var total_hits: int = 0
var score: int = 0
var accuracy: float = 0.0
var missed_hits: int = 0
var half_hits: int = 0
var full_hits: int = 0
var combo: int = 0
var health: int = MAX_HEALTH
var _health_depleted: bool = false

signal score_updated(score: int, accuracy: float)
signal gameplay_stats_updated(combo: int, health: int)
signal health_depleted

func handle_hit(result: HitResult.Type) -> void:
	total_hits += 1
	score += HitResult.get_score(result)
	accuracy += HitResult.get_accuracy(result)
	match result:
		HitResult.Type.MISS:
			missed_hits += 1
			combo = 0
			health = maxi(0, health - health_lost_per_miss)
		HitResult.Type.HALF:
			half_hits += 1
			combo += 1
		HitResult.Type.FULL:
			full_hits += 1
			combo += 1
			health = mini(MAX_HEALTH, health + health_gained_per_full_hit)

	score_updated.emit(
		get_score(),
		get_accuracy()
	)
	gameplay_stats_updated.emit(combo, health)

	if health == 0 and not _health_depleted:
		_health_depleted = true
		health_depleted.emit()


func get_score() -> int:
	return score


func get_accuracy() -> float:
	if total_hits == 0:
		return 1.0

	return accuracy / float(total_hits)


func print_stats() -> void:
	print(
		"SCORE: ", get_score(),
		" | TOTAL: ", total_hits,
		" | ACCURACY: ", get_accuracy() * 100.0, "%"
	)
