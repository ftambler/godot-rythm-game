class_name WallVisual
extends Node2D

## Solid bar along the wall's local X axis. The Wall root applies the orientation
## rotation, so every orientation shares the same thickness and construction.
## Static: drawn once, with a short fade-in when the wall spawns.


func _ready() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, Palette.APPEAR_DURATION)


func _draw() -> void:
	var half := Palette.WALL_LENGTH * 0.5
	var from := Vector2(-half, 0.0)
	var to := Vector2(half, 0.0)
	NeonDraw.glow_line(self, from, to, Palette.WALL, Palette.WALL_THICKNESS)
	draw_line(from, to, Palette.WALL.lightened(0.6), 1.5, true)
