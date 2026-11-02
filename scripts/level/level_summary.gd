class_name LevelSummary

## Card-sized description of a level, read from levels/index.json.
## Lets the level select list levels without parsing their full files.

var id: String  # level file name without extension
var level_name: String = ""
var song_name: String = "Unknown Song"
var artist: String = "Unknown Artist"
var difficulty: int = 1
var song_duration: float = 0.0
var wall_count: int = 0
var orb_count: int = 0
var speed_trigger_count: int = 0


static func from_dict(data: Dictionary) -> LevelSummary:
	var summary := LevelSummary.new()
	summary.id = str(data["id"])
	summary.level_name = str(data.get("levelName", ""))
	summary.song_name = str(data.get("songName", "Unknown Song"))
	summary.artist = str(data.get("artist", "Unknown Artist"))
	summary.difficulty = clampi(int(data.get("difficulty", 1)), 1, LevelData.MAX_DIFFICULTY)
	summary.song_duration = float(data.get("songDuration", 0.0))
	summary.wall_count = int(data.get("wallCount", 0))
	summary.orb_count = int(data.get("orbCount", 0))
	summary.speed_trigger_count = int(data.get("speedTriggerCount", 0))
	return summary


## Level name for display, falling back to the id for entries without a levelName.
func display_name() -> String:
	if not level_name.is_empty():
		return level_name
	return id.capitalize()
