class_name PlayerTrail
extends Node2D

## Diffuse white streak behind the player to sell its movement.
## Keeps the player's world positions from the last TRAIL_DURATION seconds, so a
## faster player covers more ground in that window and leaves a longer trail.
## Sampled on the physics tick so it stays in step with the interpolated player.

# Newest first, each paired with the time it was sampled.
var _points: Array[Vector2] = []
var _times: Array[float] = []
var _clock := 0.0


func _physics_process(delta: float) -> void:
	_clock += delta
	_points.push_front(global_position)
	_times.push_front(_clock)

	while not _times.is_empty() and _clock - _times.back() > Palette.TRAIL_DURATION:
		_points.pop_back()
		_times.pop_back()

	queue_redraw()


func _draw() -> void:
	if _points.size() < 2:
		return

	var points := PackedVector2Array()
	for point in _points:
		points.append(to_local(point))

	# Wide faint strokes under a thin core, all fading out toward the tail.
	draw_polyline_colors(points, _fade(Palette.GLOW_FAR_ALPHA), Palette.TRAIL_WIDTH + Palette.GLOW_FAR_WIDTH, true)
	draw_polyline_colors(points, _fade(Palette.GLOW_NEAR_ALPHA), Palette.TRAIL_WIDTH + Palette.GLOW_NEAR_WIDTH, true)
	draw_polyline_colors(points, _fade(1.0), Palette.TRAIL_WIDTH, true)


func _fade(alpha: float) -> PackedColorArray:
	var colors := PackedColorArray()
	var last := _points.size() - 1
	for i in _points.size():
		var strength := 1.0 - float(i) / last
		colors.append(Color(Palette.WHITE, Palette.TRAIL_ALPHA * alpha * strength * strength))
	return colors
