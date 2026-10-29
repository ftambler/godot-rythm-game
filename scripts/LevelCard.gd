class_name LevelCard
extends PanelContainer

## One entry in the level select list: song info plus a breakdown of the
## level's contents. The list (LevelSelect.gd) owns its transform; the card
## only handles content, selection styling and clicks.

signal pressed

const SELECTED_BORDER_WIDTH := 2

@onready var level_name_label: Label = %LevelName
@onready var stars_lit: Label = %StarsLit
@onready var stars_dim: Label = %StarsDim
@onready var song_label: Label = %Song
@onready var duration_label: Label = %Duration
@onready var divider: ColorRect = %Divider
@onready var walls_label: Label = %WallsValue
@onready var orbs_label: Label = %OrbsValue
@onready var shifts_label: Label = %ShiftsValue
@onready var play_hint: Label = %PlayHint

var level: LevelSummary
var _normal_style: StyleBoxFlat
var _selected_style: StyleBoxFlat


func _ready() -> void:
	_normal_style = get_theme_stylebox("panel").duplicate()
	_selected_style = _normal_style.duplicate()
	_selected_style.border_color = Palette.CYAN
	_selected_style.set_border_width_all(SELECTED_BORDER_WIDTH)
	_selected_style.bg_color = Palette.PANEL.lerp(Palette.CYAN, 0.05)
	_selected_style.shadow_color = Color(Palette.CYAN, 0.12)
	_selected_style.shadow_size = 18

	divider.color = Palette.BORDER
	stars_lit.add_theme_color_override("font_color", Palette.YELLOW)
	stars_dim.add_theme_color_override("font_color", Color(Palette.YELLOW, 0.2))
	walls_label.add_theme_color_override("font_color", Palette.WALL)
	orbs_label.add_theme_color_override("font_color", Palette.CYAN)
	shifts_label.add_theme_color_override("font_color", Palette.YELLOW)
	set_selected(false)


func setup(summary: LevelSummary) -> void:
	level = summary
	level_name_label.text = level.display_name()
	stars_lit.text = "★".repeat(level.difficulty)
	stars_dim.text = "★".repeat(LevelData.MAX_DIFFICULTY - level.difficulty)
	song_label.text = "%s · %s" % [level.song_name, level.artist]
	var duration_seconds := maxi(roundi(level.song_duration), 0)
	var duration_minutes := floori(float(duration_seconds) / 60.0)
	duration_label.text = "%d:%02d" % [duration_minutes, duration_seconds % 60]

	walls_label.text = str(level.wall_count)
	orbs_label.text = str(level.orb_count)
	shifts_label.text = str(level.speed_trigger_count)


func set_selected(selected: bool) -> void:
	add_theme_stylebox_override("panel", _selected_style if selected else _normal_style)
	# Alpha instead of visibility so the card keeps its height.
	play_hint.modulate.a = 1.0 if selected else 0.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit()
		accept_event()
