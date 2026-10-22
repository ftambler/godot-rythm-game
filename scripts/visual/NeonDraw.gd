class_name NeonDraw
extends RefCounted

## Drawing helpers shared by gameplay visuals and HUD icons.
## Glow is two translucent strokes under the solid shape, so it stays cheap
## and never extends far enough to suggest a larger hitbox.


static func glow_line(canvas: CanvasItem, from: Vector2, to: Vector2, color: Color, width: float) -> void:
	canvas.draw_line(from, to, _alpha(color, Palette.GLOW_FAR_ALPHA), width + Palette.GLOW_FAR_WIDTH, true)
	canvas.draw_line(from, to, _alpha(color, Palette.GLOW_NEAR_ALPHA), width + Palette.GLOW_NEAR_WIDTH, true)
	canvas.draw_line(from, to, color, width, true)


static func glow_arc(canvas: CanvasItem, radius: float, start_angle: float, end_angle: float, color: Color, width: float) -> void:
	var points := 24
	canvas.draw_arc(Vector2.ZERO, radius, start_angle, end_angle, points, _alpha(color, Palette.GLOW_FAR_ALPHA), width + Palette.GLOW_FAR_WIDTH, true)
	canvas.draw_arc(Vector2.ZERO, radius, start_angle, end_angle, points, _alpha(color, Palette.GLOW_NEAR_ALPHA), width + Palette.GLOW_NEAR_WIDTH, true)
	canvas.draw_arc(Vector2.ZERO, radius, start_angle, end_angle, points, color, width, true)


static func glow_rect(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	canvas.draw_rect(rect.grow(Palette.GLOW_FAR_WIDTH * 0.5), _alpha(color, Palette.GLOW_FAR_ALPHA))
	canvas.draw_rect(rect.grow(Palette.GLOW_NEAR_WIDTH * 0.5), _alpha(color, Palette.GLOW_NEAR_ALPHA))


## Right-pointing chevron (">") centered on `center`.
static func chevron(canvas: CanvasItem, center: Vector2, size: Vector2, color: Color, width: float) -> void:
	var half := size * 0.5
	var points := PackedVector2Array([
		center + Vector2(-half.x, -half.y),
		center + Vector2(half.x, 0.0),
		center + Vector2(-half.x, half.y),
	])
	canvas.draw_polyline(points, color, width, true)


## Row of `count` chevrons, the first `lit` of them drawn in `color`, the rest dimmed.
## `brightness` optionally scales each lit chevron's alpha (used for the trigger's pulse).
static func chevron_row(
	canvas: CanvasItem,
	center: Vector2,
	count: int,
	lit: int,
	chevron_size: Vector2,
	spacing: float,
	color: Color,
	width: float,
	brightness: PackedFloat32Array = PackedFloat32Array()
) -> void:
	var start_x := center.x - spacing * (count - 1) * 0.5
	for i in count:
		var position := Vector2(start_x + spacing * i, center.y)
		if i < lit:
			var alpha := brightness[i] if i < brightness.size() else 1.0
			chevron(canvas, position, chevron_size, _alpha(color, Palette.GLOW_NEAR_ALPHA * alpha), width + Palette.GLOW_NEAR_WIDTH)
			chevron(canvas, position, chevron_size, _alpha(color, alpha), width)
		else:
			chevron(canvas, position, chevron_size, _alpha(color, 0.2), width)


static func _alpha(color: Color, alpha: float) -> Color:
	return Color(color, color.a * alpha)
