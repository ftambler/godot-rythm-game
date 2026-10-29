extends Control

## Scrollable level list laid out on a shallow drum: the selected card sits
## flat in the middle, neighbours rotate away from the viewer, shrinking,
## flattening and fading with distance. `_scroll` eases toward `_target`
## every frame, so every transition (keys, wheel, clicks) animates.
##
## Browsing past either end wraps around. With enough cards the drum is a
## seamless loop (`_target` is unbounded and offsets wrap); with few cards a
## loop would show the same card above and below, so the drum spins back
## across the list instead.

enum SortMode { DEFAULT, DIFFICULTY, LENGTH, NAME }

const LEVEL_CARD_SCENE := preload("res://scenes/ui/LevelCard.tscn")
const MENU_SCENE := "res://scenes/ui/Menu.tscn"
const GAME_SCENE := "res://scenes/game/Game.tscn"

# Drum geometry
const ANGLE_STEP := deg_to_rad(24.0)  # rotation between neighbouring cards
const DRUM_RADIUS := 330.0            # vertical distance comes from radius * sin(angle)
const MAX_ANGLE := deg_to_rad(84.0)   # cards past this are hidden
const DEPTH_FALLOFF := 0.6            # how quickly cards shrink as they rotate away
const TILT := 0.5                     # 0 = no vertical squash, 1 = full cos(angle) squash
const RECEDE_X := 50.0               # sideways drift of far cards, sells the depth
const MIN_BRIGHTNESS := 0.55

const SCROLL_SHARPNESS := 12.0

const SORT_LABELS := {
	SortMode.DEFAULT: "Default",
	SortMode.DIFFICULTY: "Difficulty",
	SortMode.LENGTH: "Length",
	SortMode.NAME: "Name",
}
# Caption for each mode as [ascending, descending].
const SORT_CAPTIONS := {
	SortMode.DEFAULT: ["INDEX ORDER", "INDEX ORDER"],
	SortMode.DIFFICULTY: ["EASIEST FIRST", "HARDEST FIRST"],
	SortMode.LENGTH: ["SHORTEST FIRST", "LONGEST FIRST"],
	SortMode.NAME: ["A TO Z", "Z TO A"],
}

# Kept across visits so returning from a level keeps the chosen order.
static var sort_mode := SortMode.DEFAULT
static var sort_descending := false

@onready var track: Control = %Track
@onready var counter_label: Label = %Counter
@onready var empty_label: Label = %EmptyLabel
@onready var sort_caption: Label = %SortCaption
@onready var sort_buttons: Array[Node] = %SortButtons.get_children()  # same order as SortMode
@onready var hints: HBoxContainer = %Hints

var _cards: Array[LevelCard] = []
var _index_order: Dictionary = {}  # LevelSummary -> position in index.json
var _target := 0                   # scroll target; unbounded when the drum loops
var _selected := 0                 # index into _cards
var _scroll := 0.0


func _ready() -> void:
	var levels := LevelCatalog.list_levels()
	empty_label.visible = levels.is_empty()

	for i in levels.size():
		var card: LevelCard = LEVEL_CARD_SCENE.instantiate()
		track.add_child(card)
		card.setup(levels[i])
		card.pressed.connect(_on_card_pressed.bind(card))
		_cards.append(card)
		_index_order[levels[i]] = i

	for mode in sort_buttons.size():
		sort_buttons[mode].pressed.connect(_on_sort_button_pressed.bind(mode))
	for label in hints.get_children():
		if label is Label and label.theme_type_variation == &"CaptionLabel":
			label.add_theme_color_override("font_color", Palette.WHITE)

	_apply_sort()
	for i in _cards.size():
		if _cards[i].level.id == LevelCatalog.selected_id:
			_jump_to(i)


func _process(delta: float) -> void:
	_scroll = lerpf(_scroll, _target, 1.0 - exp(-SCROLL_SHARPNESS * delta))
	_layout_cards()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up", true) or event.is_action_pressed("shield_up", true):
		_select(_target - 1)
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("shield_down", true):
		_select(_target + 1)
	elif event.is_action_pressed("ui_accept"):
		_play_selected()
	elif event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()
	else:
		return
	get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	# Wheel is read here rather than in _unhandled_input because the cards
	# under the cursor would otherwise swallow it.
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select(_target - 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select(_target + 1)


## True when the list is long enough that the loop's seam (half the list away
## from the selected card) is never on screen.
func _is_looping() -> bool:
	return _cards.size() * 0.5 > MAX_ANGLE / ANGLE_STEP + 0.5


func _select(position: int) -> void:
	var count := _cards.size()
	if count == 0:
		return

	if _is_looping():
		_target = position
		# Keep the numbers small; offsets wrap in _layout_cards so shifting by
		# whole turns changes nothing on screen.
		var turns := _target - posmod(_target, count)
		_target -= turns
		_scroll -= turns
	else:
		_target = posmod(position, count)

	_selected = posmod(_target, count)
	for i in count:
		_cards[i].set_selected(i == _selected)
	counter_label.text = "%02d / %02d" % [_selected + 1, count]


## Selects a card without animating the drum there.
func _jump_to(index: int) -> void:
	_select(index)
	_scroll = _target


func _layout_cards() -> void:
	var count := _cards.size()
	var looping := _is_looping()
	var center := track.size * 0.5
	for i in count:
		var card := _cards[i]
		var offset := i - _scroll
		if looping:
			offset = wrapf(offset, -count * 0.5, count * 0.5)
		var angle := offset * ANGLE_STEP
		var facing := cos(angle)

		card.visible = absf(angle) < MAX_ANGLE
		if not card.visible:
			continue

		var depth_scale := 1.0 / (1.0 + (1.0 - facing) * DEPTH_FALLOFF)
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2(depth_scale, depth_scale * lerpf(1.0, facing, TILT))
		card.position = center - card.pivot_offset + Vector2(
			(1.0 - facing) * RECEDE_X,
			sin(angle) * DRUM_RADIUS
		)

		# Cubed so even the immediate neighbours dim noticeably.
		var brightness := lerpf(MIN_BRIGHTNESS, 1.0, pow(facing, 3.0))
		var alpha := smoothstep(cos(MAX_ANGLE), 0.9, facing)
		card.modulate = Color(brightness, brightness, brightness, alpha)
		# Nearest card draws on top when neighbours overlap mid-scroll.
		card.z_index = 100 - roundi(absf(offset) * 10.0)


## Clicking a new mode sorts ascending; clicking the active one flips the direction.
func _on_sort_button_pressed(mode: SortMode) -> void:
	if mode == sort_mode:
		sort_descending = not sort_descending and mode != SortMode.DEFAULT
	else:
		sort_mode = mode
		sort_descending = false
	_apply_sort()


func _apply_sort() -> void:
	_refresh_sort_buttons()
	if _cards.is_empty():
		return

	# Re-sorting keeps the same level selected and centered; the rest reorder around it.
	var selected_card := _cards[_selected]
	_cards.sort_custom(func(a: LevelCard, b: LevelCard) -> bool: return _sorts_before(a.level, b.level))
	_jump_to(_cards.find(selected_card))


func _refresh_sort_buttons() -> void:
	for mode in sort_buttons.size():
		var button: Button = sort_buttons[mode]
		var active: bool = mode == sort_mode
		button.set_pressed_no_signal(active)
		button.text = SORT_LABELS[mode]
		if active and mode != SortMode.DEFAULT:
			button.text += " ↓" if sort_descending else " ↑"
	sort_caption.text = "SORT BY · %s" % SORT_CAPTIONS[sort_mode][int(sort_descending)]


func _sorts_before(a: LevelSummary, b: LevelSummary) -> bool:
	var comparison := 0
	match sort_mode:
		SortMode.DIFFICULTY:
			comparison = signi(a.difficulty - b.difficulty)
		SortMode.LENGTH:
			comparison = int(signf(a.song_duration - b.song_duration))
		SortMode.NAME:
			comparison = a.display_name().naturalnocasecmp_to(b.display_name())
	if comparison != 0:
		return comparison > 0 if sort_descending else comparison < 0
	# Ties (and the default mode) keep the order in index.json, whichever the direction.
	return _index_order[a] < _index_order[b]


func _play_selected() -> void:
	if _cards.is_empty():
		return
	LevelCatalog.selected_id = _cards[_selected].level.id
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_card_pressed(card: LevelCard) -> void:
	var index := _cards.find(card)
	if index == _selected:
		_play_selected()
		return

	var step := index - _selected
	if _is_looping():
		# Spin the short way round the loop.
		var count := _cards.size()
		var half := floori(count / 2.0)
		step = posmod(step + half, count) - half
	_select(_target + step)


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
