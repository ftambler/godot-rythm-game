class_name ResultsScreen
extends CanvasLayer

signal replay_requested
signal menu_requested

@onready var eyebrow_label: Label = $Overlay/Panel/Margin/Content/Eyebrow
@onready var title_label: Label = $Overlay/Panel/Margin/Content/Title
@onready var score_label: Label = $Overlay/Panel/Margin/Content/Score
@onready var accuracy_label: Label = $Overlay/Panel/Margin/Content/Accuracy
@onready var missed_label: Label = $Overlay/Panel/Margin/Content/Stats/Missed/Value
@onready var half_label: Label = $Overlay/Panel/Margin/Content/Stats/Half/Value
@onready var full_label: Label = $Overlay/Panel/Margin/Content/Stats/Full/Value
@onready var replay_button: Button = $Overlay/Panel/Margin/Content/Buttons/ReplayButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func open(score_handler: ScoreHandler, did_win: bool) -> void:
	eyebrow_label.text = "RUN COMPLETE" if did_win else "RUN OVER"
	title_label.text = "Results" if did_win else "Defeat"
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