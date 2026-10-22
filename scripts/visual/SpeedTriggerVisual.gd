class_name SpeedTriggerVisual
extends Node2D

## Three yellow chevrons; the number lit equals the trigger's speed level
## (read from the parent SpeedTrigger). A highlight sweeps across the lit
## chevrons, slightly faster at higher levels, and the glyph flashes when
## the player passes through.

const CHEVRON_COUNT := 3
const CHEVRON_SIZE := Vector2(7.0, 14.0)
const CHEVRON_SPACING := 8.0
const CHEVRON_WIDTH := 2.5
const BASE_SWEEP_SPEED := 4.0
const SWEEP_SPEED_PER_LEVEL := 1.5

var _level := 1
var _time := 0.0
var _brightness := PackedFloat32Array()
var _flash_strength := 0.0


func _ready() -> void:
	var trigger := get_parent() as SpeedTrigger
	if trigger:
		_level = int(trigger.speed_type) + 1
		trigger.body_entered.connect(_on_body_entered)
	_brightness.resize(CHEVRON_COUNT)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, Palette.APPEAR_DURATION)


func _process(delta: float) -> void:
	_time += delta
	var sweep_speed := BASE_SWEEP_SPEED + SWEEP_SPEED_PER_LEVEL * _level
	for i in CHEVRON_COUNT:
		var wave := 0.5 + 0.5 * sin(_time * sweep_speed - i * 1.1)
		_brightness[i] = minf(1.0, 0.7 + 0.3 * wave + _flash_strength)
	queue_redraw()


func _draw() -> void:
	if _flash_strength > 0.0:
		draw_rect(Rect2(-14, -11, 28, 22), Color(Palette.YELLOW, 0.12 * _flash_strength))
	NeonDraw.chevron_row(
		self, Vector2.ZERO, CHEVRON_COUNT, _level,
		CHEVRON_SIZE, CHEVRON_SPACING, Palette.YELLOW, CHEVRON_WIDTH, _brightness
	)


func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	_flash_strength = 1.0
	create_tween().tween_property(self, "_flash_strength", 0.0, Palette.EFFECT_DURATION)
