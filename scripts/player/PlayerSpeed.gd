class_name PlayerSpeed
extends Node

enum Type {
	SPEED_1,
	SPEED_2,
	SPEED_3
}

const VALUES := {
	Type.SPEED_1: 150.0,
	Type.SPEED_2: 300.0,
	Type.SPEED_3: 450.0
}

static func get_value(speed_type: Type) -> float:
	return VALUES[speed_type]
