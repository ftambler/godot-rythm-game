extends Control

const SETTINGS_PATH := "user://settings.cfg"
const BINDINGS := {
	"shield_up": "Shield up",
	"shield_down": "Shield down",
	"shield_left": "Shield left",
	"shield_right": "Shield right",
	"hit_orb": "Hit orb",
	"pause_game": "Pause"
}

var _waiting_for_action := ""
var _binding_buttons: Dictionary = {}

@onready var music_slider: HSlider = $Panel/Margin/Content/MusicSlider
@onready var sfx_slider: HSlider = $Panel/Margin/Content/SfxSlider
@onready var hint: Label = $Panel/Margin/Content/Hint

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action_name in BINDINGS:
		_binding_buttons[action_name] = [
			get_node(_button_path_for(action_name, 0)),
			get_node(_button_path_for(action_name, 1))
		]
	_load_keybinds()
	_refresh_binding_labels()
	music_slider.value = MusicController.get_volume()
	sfx_slider.value = MusicController.get_sfx_volume()

func open() -> void:
	visible = true
	_waiting_for_action = ""
	_refresh_binding_labels()
	$Panel/Margin/Content/Header/BackButton.grab_focus()

func close() -> void:
	_waiting_for_action = ""
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _waiting_for_action.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_set_keybind(_waiting_for_action, event)
		get_viewport().set_input_as_handled()

func _on_back_button_pressed() -> void:
	close()

func _on_music_slider_value_changed(value: float) -> void:
	MusicController.set_volume(value)

func _on_sfx_slider_value_changed(value: float) -> void:
	MusicController.set_sfx_volume(value)

func _on_binding_button_pressed(action_name: String, event_index: int) -> void:
	_waiting_for_action = "%s:%d" % [action_name, event_index]
	hint.text = "Press a key for %s..." % BINDINGS[action_name]
	_binding_buttons[action_name][event_index].text = "Press a key..."

func _set_keybind(binding_id: String, event: InputEventKey) -> void:
	var binding_parts := binding_id.split(":")
	var action_name: String = binding_parts[0]
	var event_index: int = int(binding_parts[1])
	var binding := InputEventKey.new()
	binding.physical_keycode = event.physical_keycode
	binding.keycode = event.keycode
	binding.shift_pressed = event.shift_pressed
	binding.ctrl_pressed = event.ctrl_pressed
	binding.alt_pressed = event.alt_pressed
	var events := InputMap.action_get_events(action_name)
	if event_index >= events.size():
		event_index = events.size()
		events.append(binding)
	else:
		events[event_index] = binding
	InputMap.action_erase_events(action_name)
	for action_event in events:
		InputMap.action_add_event(action_name, action_event)
	_save_keybind(action_name, event_index, binding)
	_waiting_for_action = ""
	hint.text = "Select a binding, then press any key."
	_refresh_binding_labels()

func _refresh_binding_labels() -> void:
	for action_name in BINDINGS:
		var events := InputMap.action_get_events(action_name)
		var buttons: Array = _binding_buttons[action_name]
		for event_index in 2:
			buttons[event_index].text = _event_to_text(events[event_index]) if event_index < events.size() else "Unassigned"

func _event_to_text(event: InputEvent) -> String:
	if event is InputEventKey:
		var key_code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		var text := OS.get_keycode_string(key_code)
		if event.shift_pressed:
			text = "Shift + " + text
		if event.ctrl_pressed:
			text = "Ctrl + " + text
		if event.alt_pressed:
			text = "Alt + " + text
		return text
	return event.as_text()

func _button_path_for(action_name: String, event_index: int) -> NodePath:
	var row_name: String = {
		"shield_up": "ShieldUpRow",
		"shield_down": "ShieldDownRow",
		"shield_left": "ShieldLeftRow",
		"shield_right": "ShieldRightRow",
		"hit_orb": "OrbRow",
		"pause_game": "PauseRow"
	}[action_name]
	var button_name := "PrimaryButton" if event_index == 0 else "SecondaryButton"
	return NodePath("Panel/Margin/Content/Bindings/%s/%s" % [row_name, button_name])

func _load_keybinds() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for action_name in BINDINGS:
		for event_index in 2:
			var key := "%s_%d" % [action_name, event_index]
			if not config.has_section_key("keybinds", key):
				continue
			var saved_code: int = config.get_value("keybinds", key, 0)
			var saved_physical: bool = config.get_value("keybinds_physical", key, true)
			var event := InputEventKey.new()
			if saved_physical:
				event.physical_keycode = saved_code
			else:
				event.keycode = saved_code
			var events := InputMap.action_get_events(action_name)
			if event_index < events.size():
				events[event_index] = event
			else:
				events.append(event)
			InputMap.action_erase_events(action_name)
			for action_event in events:
				InputMap.action_add_event(action_name, action_event)

func _save_keybind(action_name: String, event_index: int, event: InputEventKey) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	var uses_physical := event.physical_keycode != 0
	var key_code: int = event.physical_keycode if uses_physical else event.keycode
	var key := "%s_%d" % [action_name, event_index]
	config.set_value("keybinds", key, key_code)
	config.set_value("keybinds_physical", key, uses_physical)
	config.save(SETTINGS_PATH)
