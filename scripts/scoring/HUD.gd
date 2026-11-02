class_name HUD
extends CanvasLayer


const SCORE_PULSE_SCALE := 1.06
const COMBO_PULSE_SCALE := 1.18
const IDLE_COMBO_ALPHA := 0.35

@onready var score_label: Label = %ScoreLabel
@onready var accuracy_label: Label = %AccuracyLabel
@onready var combo_block: Control = %ComboBlock
@onready var combo_label: Label = %ComboLabel
@onready var health_label: Label = %HealthLabel
@onready var health_bar: ProgressBar = %HealthBar

var _last_score := 0
var _last_combo := 0
var _health_fill: StyleBoxFlat
var _health_tween: Tween


func _ready() -> void:
	# Own copy of the themed fill so the damage flash doesn't recolor the shared theme.
	_health_fill = health_bar.get_theme_stylebox("fill").duplicate()
	health_bar.add_theme_stylebox_override("fill", _health_fill)


func update_score(score: int) -> void:
	score_label.text = str(score)
	if score > _last_score:
		_pulse(score_label, SCORE_PULSE_SCALE, Vector2(0.0, 0.5))
	_last_score = score


func update_accuracy(accuracy: float) -> void:
	accuracy_label.text = "%.1f%%" % (accuracy * 100.0)


func update_combo(combo: int) -> void:
	combo_label.text = str(combo)
	combo_block.modulate.a = 1.0 if combo > 0 else IDLE_COMBO_ALPHA
	if combo > _last_combo:
		_pulse(combo_label, COMBO_PULSE_SCALE, Vector2(0.5, 0.5))
	_last_combo = combo


func update_health(health: int) -> void:
	health_label.text = str(health) + "%"
	health_bar.value = health


func flash_hit(result: HitResult.Type) -> void:
	if _health_tween:
		_health_tween.kill()
	_health_fill.bg_color = Palette.hit_result_color(result)
	_health_tween = create_tween()
	_health_tween.tween_property(_health_fill, "bg_color", Palette.CYAN, Palette.EFFECT_DURATION * 2.0)


func _pulse(control: Control, peak: float, pivot: Vector2) -> void:
	control.pivot_offset = control.size * pivot
	control.scale = Vector2.ONE * peak
	create_tween().tween_property(control, "scale", Vector2.ONE, Palette.PULSE_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
