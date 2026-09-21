extends Control

@export var game_scene_path: String = "res://scenes/game/Game.tscn"

@onready var play_button: Button = $MainPanel/Content/Margin/Stack/PlayButton
@onready var options_menu: Control = $OptionsMenu

func _ready() -> void:
	play_button.grab_focus()

func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file(game_scene_path)

func _on_options_button_pressed() -> void:
	options_menu.open()

func _on_quit_button_pressed() -> void:
	get_tree().quit()
