class_name LevelIntro
extends CanvasLayer

## Translucent band across the middle of the screen announcing the song while
## the level waits paused behind it. Fades in, holds, fades out, then asks
## Game.gd to start.

signal start_requested

const DISPLAY_SECONDS := 2.0
const FADE_IN_DURATION := 0.3
const FADE_DURATION := 0.35

@onready var overlay: ColorRect = $Overlay
@onready var song_name_label: Label = $Overlay/Band/Content/SongName
@onready var artist_label: Label = $Overlay/Band/Content/Artist
@onready var stars_lit: Label = $Overlay/Band/Content/Details/Stars/StarsLit
@onready var stars_dim: Label = $Overlay/Band/Content/Details/Stars/StarsDim
@onready var duration_label: Label = $Overlay/Band/Content/Details/Duration

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	stars_dim.add_theme_color_override("font_color", Color(Palette.YELLOW, 0.2))

func open(level: LevelData) -> void:
	song_name_label.text = level.song_name
	artist_label.text = level.artist
	stars_lit.text = "★".repeat(level.difficulty)
	stars_dim.text = "★".repeat(LevelData.MAX_DIFFICULTY - level.difficulty)
	var duration_seconds := maxi(roundi(level.song_duration), 0)
	var duration_minutes := floori(float(duration_seconds) / 60.0)
	duration_label.text = "%d:%02d" % [duration_minutes, duration_seconds % 60]
	visible = true
	_show_intro()

func close() -> void:
	visible = false
	overlay.modulate.a = 1.0


func _show_intro() -> void:
	overlay.modulate.a = 0.0
	var fade_in := create_tween()
	fade_in.tween_property(overlay, "modulate:a", 1.0, FADE_IN_DURATION)
	await fade_in.finished

	await get_tree().create_timer(DISPLAY_SECONDS, true).timeout
	if not visible:
		return
	var fade_out := create_tween()
	fade_out.tween_property(overlay, "modulate:a", 0.0, FADE_DURATION)
	await fade_out.finished
	if not visible:
		return
	start_requested.emit()
