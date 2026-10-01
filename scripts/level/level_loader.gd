class_name LevelLoader


static func load_level(path: String) -> LevelData:
	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		push_error("Could not open level: " + path)
		return null

	var json_text := file.get_as_text()
	var json_data = JSON.parse_string(json_text)

	if json_data == null:
		push_error("Invalid JSON in level: " + path)
		return null

	return _parse_level(json_data)


static func _parse_level(data: Dictionary) -> LevelData:
	var level := LevelData.new()

	level.music = data["music"]
	level.song_name = str(data.get("songName", "Unknown Song"))
	level.artist = str(data.get("artist", "Unknown Artist"))
	level.difficulty = clampi(int(data.get("difficulty", 1)), 1, 5)
	level.song_start = data["songStart"]
	level.song_duration = data["songDuration"]

	var player_data: Dictionary = data["player"]

	level.player_position = Vector2(
		player_data["position"][0],
		player_data["position"][1]
	)

	level.player_direction = Vector2(
		player_data["direction"][0],
		player_data["direction"][1]
	)

	level.player_speed = PlayerSpeed.Type.values()[int(player_data["speed"]) - 1]

	for object_data in data["objects"]:
		level.objects.append(_parse_object(object_data))

	return level


static func _parse_object(data: Dictionary) -> LevelObjectData:
	var object := LevelObjectData.new()

	object.type = data["type"]

	object.position = Vector2(
		data["position"][0],
		data["position"][1]
	)

	object.start = data["start"]
	object.end = data["end"]
	object.group_id = data["groupId"]

	if data.has("wallType"):
		object.wall_type = _parse_wall_type(data["wallType"])
		
	if data.has("speed"):
		object.speed_type = PlayerSpeed.Type.values()[int(data["speed"]) - 1]

	return object

static func _parse_wall_type(value: String) -> Wall.WallRotation:
	match value:
		"HORIZONTAL":
			return Wall.WallRotation.HORIZONTAL

		"VERTICAL":
			return Wall.WallRotation.VERTICAL

		"DIAGONAL_DOWN":
			return Wall.WallRotation.DIAGONAL_DOWN

		"DIAGONAL_UP":
			return Wall.WallRotation.DIAGONAL_UP

		_:
			push_error("Unknown wall type: " + value)
			return Wall.WallRotation.HORIZONTAL
