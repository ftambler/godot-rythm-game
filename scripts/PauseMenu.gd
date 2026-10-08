class_name PauseMenu
extends CanvasLayer

signal restart_requested

@onready var panel: Control = $Overlay/Panel
@onready var music_slider: HSlider = $Overlay/Panel/MarginContainer/Content/MusicSlider
@onready var sfx_slider: HSlider = $Overlay/Panel/MarginContainer/Content/SfxSlider
var pause_enabled := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	music_slider.value = MusicController.get_volume()
	sfx_slider.value = MusicController.get_sfx_volume()

func _unhandled_input(event: InputEvent) -> void:
	if pause_enabled and event.is_action_pressed("pause_game"):
		toggle_pause()
		get_viewport().set_input_as_handled()

func set_pause_enabled(enabled: bool) -> void:
	pause_enabled = enabled

func toggle_pause() -> void:
	if get_tree().paused:
		resume()
	else:
		pause()

func pause() -> void:
	get_tree().paused = true
	visible = true
	$Overlay/Panel/MarginContainer/Content/ResumeButton.grab_focus()

func resume() -> void:
	get_tree().paused = false
	visible = false

func _on_resume_button_pressed() -> void:
	resume()

func _on_restart_button_pressed() -> void:
	restart_requested.emit()

func _on_main_menu_button_pressed() -> void:
	get_tree().paused = false
	MusicController.stop_music()
	get_tree().change_scene_to_file("res://scenes/ui/Menu.tscn")

func _on_music_slider_value_changed(value: float) -> void:
	MusicController.set_volume(value)

func _on_sfx_slider_value_changed(value: float) -> void:
	MusicController.set_sfx_volume(value)