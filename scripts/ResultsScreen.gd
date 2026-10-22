class_name ResultsScreen
extends CanvasLayer

signal replay_requested
signal menu_requested

@onready var title_label: Label = $Overlay/Panel/Margin/Content/Title
@onready var score_label: Label = $Overlay/Panel/Margin/Content/Summary/Score/Value
@onready var accuracy_label: Label = $Overlay/Panel/Margin/Content/Summary/Accuracy/Value
@onready var missed_label: Label = $Overlay/Panel/Margin/Content/Stats/Missed/Value
@onready var half_label: Label = $Overlay/Panel/Margin/Content/Stats/Half/Value
@onready var full_label: Label = $Overlay/Panel/Margin/Content/Stats/Full/Value
@onready var replay_button: Button = $Overlay/Panel/Margin/Content/Buttons/ReplayButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	replay_button.grab_focus()

func _on_replay_button_pressed() -> void:
	replay_requested.emit()

func _on_menu_button_pressed() -> void:
	menu_requested.emit()