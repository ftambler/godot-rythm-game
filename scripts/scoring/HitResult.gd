class_name HitResult
extends RefCounted


enum Type {
	MISS,
	HALF,
	FULL
}


static func get_score(type: Type) -> int:
	match type:
		Type.MISS:
			return 0
		Type.HALF:
			return 50
		Type.FULL:
			return 100

	return 0


static func get_accuracy(type: Type) -> float:
	match type:
		Type.MISS:
			return 0.0
		Type.HALF:
			return 0.5
		Type.FULL:
			return 1.0

	return 0.0
