class_name LevelData

var music: String
var song_name: String = "Unknown Song"
var artist: String = "Unknown Artist"
var difficulty: int = 1
var song_start: float
var song_duration: float

var player_position: Vector2
var player_direction: Vector2
var player_speed: PlayerSpeed.Type

var objects: Array[LevelObjectData] = []
