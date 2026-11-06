class_name HitMarker
extends Label

## Floating judgement text ("PERFECT" / "GOOD" / "MISS") shown just above the player.
## It stays anchored to the player while drifting upwards and fading out, then frees itself.

const FONT := preload("res://fonts/Orbitron.ttf")
const FONT_SIZE := 18
const OUTLINE_SIZE := 4
const BASE_OFFSET := 34.0
const RISE_DISTANCE := 28.0
const DURATION := 0.6
## true: follows the player in world space (spawned by GameplayFeedback).
## false: static above the screen center (spawned inside the HUD's HitMarkerAnchor).
const FOLLOW_PLAYER := false
const SCREEN_OFFSET := 60.0

var _target: Node2D
var _rise := 0.0


static func spawn(parent: Node, target: Node2D, result: HitResult.Type) -> void:
	var marker := HitMarker.new()
	marker._target = target
	marker.text = _text_for(result)
	marker.add_theme_color_override("font_color", Palette.hit_result_color(result))
	parent.add_child(marker)


static func _text_for(result: HitResult.Type) -> String:
	match result:
		HitResult.Type.FULL:
			return "PERFECT"
		HitResult.Type.HALF:
			return "GOOD"

	return "MISS"


func _init() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var variation := FontVariation.new()
	variation.base_font = FONT
	variation.spacing_glyph = 2
	variation.variation_opentype = {"wght": 800}
	add_theme_font_override("font", variation)
	add_theme_font_size_override("font_size", FONT_SIZE)
	add_theme_constant_override("outline_size", OUTLINE_SIZE)
	add_theme_color_override("font_outline_color", Color(Palette.BACKGROUND, 0.85))


func _ready() -> void:
	_update_position()
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "_rise", RISE_DISTANCE, DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


func _process(_delta: float) -> void:
	_update_position()


func _update_position() -> void:
	var half := get_minimum_size() * 0.5
	if FOLLOW_PLAYER:
		if is_instance_valid(_target):
			global_position = _target.global_position - half - Vector2(0.0, BASE_OFFSET + _rise)
	else:
		position = -half - Vector2(0.0, SCREEN_OFFSET + _rise)
