class_name LevelCatalog

## Lists the playable levels from INDEX_PATH and remembers which one the level
## select screen picked. Static vars survive scene changes, so Game.gd reads
## `selected_id` after the menu swaps scenes.
## The index is the single list of levels: a level file not listed there is not
## shown, and the list order is the index order.

const LEVELS_DIR := "res://levels"
const INDEX_PATH := "res://levels/index.json"
const DEFAULT_LEVEL_ID := "test"

static var selected_id: String = DEFAULT_LEVEL_ID


static func list_levels() -> Array[LevelSummary]:
	var summaries: Array[LevelSummary] = []
	var file := FileAccess.open(INDEX_PATH, FileAccess.READ)

	if file == null:
		push_error("Could not open level index: " + INDEX_PATH)
		return summaries

	var data = JSON.parse_string(file.get_as_text())

	if not data is Dictionary or not data.get("levels") is Array:
		push_error("Invalid level index: " + INDEX_PATH)
		return summaries

	for entry in data["levels"]:
		if entry is Dictionary and entry.has("id"):
			summaries.append(LevelSummary.from_dict(entry))
		else:
			push_error("Level index entry without an id: " + str(entry))

	return summaries


static func path_for(id: String) -> String:
	return LEVELS_DIR.path_join(id + ".json")
