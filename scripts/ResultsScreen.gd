class_name ResultsScreen
extends CanvasLayer

signal replay_requested
signal menu_requested

# Replay stays disabled (with a countdown) so presses meant for the orbs can't activate it.
const INPUT_COOLDOWN := 3.0
const FADE_IN_DURATION := 0.6

@onready var overlay: Panel = $Overlay
@onready var title_label: Label = $Overlay/Panel/Margin/Content/Title
@onready var score_label: Label = $Overlay/Panel/Margin/Content/Summary/Score/Value
@onready var accuracy_label: Label = $Overlay/Panel/Margin/Content/Summary/Accuracy/Value
@onready var missed_label: Label = $Overlay/Panel/Margin/Content/Stats/Missed/Value
@onready var half_label: Label = $Overlay/Panel/Margin/Content/Stats/Half/Value
@onready var full_label: Label = $Overlay/Panel/Margin/Content/Stats/Full/Value
@onready var replay_button: Button = $Overlay/Panel/Margin/Content/Buttons/ReplayButton

var _cooldown_left: float = 0.0
var _replay_text: String

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	_replay_text = replay_button.text
	visible = false
	missed_label.add_theme_color_override("font_color", Palette.PINK)
	half_label.add_theme_color_override("font_color", Palette.YELLOW)
	full_label.add_theme_color_override("font_color", Palette.GREEN)
	accuracy_label.add_theme_color_override("font_color", Palette.CYAN)

func open(score_handler: ScoreHandler, did_win: bool) -> void:
	title_label.text = "Level complete" if did_win else "Level failed"
	title_label.add_theme_color_override("font_color", Palette.WHITE if did_win else Palette.PINK)
	score_label.text = str(score_handler.get_score())
	accuracy_label.text = "%s%%" % snapped(score_handler.get_accuracy() * 100.0, 0.1)
	missed_label.text = str(score_handler.missed_hits)
	half_label.text = str(score_handler.half_hits)
	full_label.text = str(score_handler.full_hits)
	visible = true
	overlay.modulate.a = 0.0
	create_tween().tween_property(overlay, "modulate:a", 1.0, FADE_IN_DURATION)
	_cooldown_left = INPUT_COOLDOWN
	_update_cooldown_buttons()
	set_process(true)

func _process(delta: float) -> void:
	_cooldown_left -= delta
	_update_cooldown_buttons()
	if _cooldown_left <= 0.0:
		set_process(false)
		replay_button.grab_focus()

func _update_cooldown_buttons() -> void:
	var waiting := _cooldown_left > 0.0
	replay_button.disabled = waiting
	replay_button.text = "%s (%d)" % [_replay_text, ceili(_cooldown_left)] if waiting else _replay_text

func _on_replay_button_pressed() -> void:
	replay_requested.emit()

func _on_menu_button_pressed() -> void:
	menu_requested.emit()
