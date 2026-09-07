extends Control

# Drag and drop your actual game level scene file here from the FileSystem
@export var game_scene_path : String = "res://Game.tscn"

func _ready() -> void:
	# Automatically highlights the Play button for controller/keyboard support
	$VBoxContainer/PlayButton.grab_focus()

func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file(game_scene_path)

func _on_options_button_pressed() -> void:
	print("Options menu clicked!")

func _on_quit_button_pressed() -> void:
	get_tree().quit()
