class_name LevelIntro
extends CanvasLayer

signal start_requested

const DISPLAY_SECONDS := 2.0
const FADE_DURATION := 0.35

@onready var overlay: ColorRect = $Overlay
@onready var song_name_label: Label = $Overlay/Panel/Margin/Content/SongRow/SongName
@onready var difficulty_label: Label = $Overlay/Panel/Margin/Content/SongRow/Difficulty
@onready var artist_label: Label = $Overlay/Panel/Margin/Content/ArtistRow/Artist
@onready var duration_label: Label = $Overlay/Panel/Margin/Content/ArtistRow/Duration

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func open(level: LevelData) -> void:
	song_name_label.text = level.song_name
	difficulty_label.text = str(level.difficulty)
	artist_label.text = level.artist
	var duration_seconds := maxi(roundi(level.song_duration), 0)
	var duration_minutes := floori(float(duration_seconds) / 60.0)
	duration_label.text = "%d:%02d" % [duration_minutes, duration_seconds % 60]
	overlay.modulate.a = 1.0
	visible = true
	_show_intro()

func close() -> void:
	visible = false
	overlay.modulate.a = 1.0


func _show_intro() -> void:
	await get_tree().create_timer(DISPLAY_SECONDS, true).timeout
	if not visible:
		return
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, FADE_DURATION)
	await tween.finished
	if not visible:
		return
	start_requested.emit()
