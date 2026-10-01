class_name ScoreHandler
extends Node


var total_hits: int = 0
var score: int = 0
var accuracy: float = 0.0
var missed_hits: int = 0
var half_hits: int = 0
var full_hits: int = 0

signal score_updated(score: int, accuracy: float)

func handle_hit(result: HitResult.Type) -> void:
	total_hits += 1
	score += HitResult.get_score(result)
	accuracy += HitResult.get_accuracy(result)
	match result:
		HitResult.Type.MISS:
			missed_hits += 1
		HitResult.Type.HALF:
			half_hits += 1
		HitResult.Type.FULL:
			full_hits += 1

	score_updated.emit(
		get_score(),
		get_accuracy()
	)


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
