extends SceneTree

## Generates res://themes/minimal_neon_theme.tres from the Palette tokens.
## The project uses that file as its default GUI theme (gui/theme/custom).
## Re-run after changing Palette or the styles below:
##   godot --headless --path . --script res://scripts/visual/build_theme.gd

const OUTPUT_PATH := "res://themes/minimal_neon_theme.tres"
const CORNER_RADIUS := 4
const PANEL_CORNER_RADIUS := 6

# Typography scale
const FONT_SIZE_BODY := 16
const FONT_SIZE_TITLE := 40
const FONT_SIZE_HEADING := 28
const FONT_SIZE_SUBHEADING := 20
const FONT_SIZE_HERO_VALUE := 48
const FONT_SIZE_VALUE := 30
const FONT_SIZE_ACCENT_VALUE := 22
const FONT_SIZE_KICKER := 13
const FONT_SIZE_CAPTION := 12


func _init() -> void:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE_BODY

	var caps_font := FontVariation.new()
	caps_font.spacing_glyph = 2

	var numeric_font := FontVariation.new()
	var tnum := TextServerManager.get_primary_interface().name_to_tag("tnum")
	numeric_font.opentype_features = {tnum: 1}

	_add_label_styles(theme, caps_font, numeric_font)
	_add_button_styles(theme)
	_add_panel_styles(theme)
	_add_slider_styles(theme)
	_add_progress_styles(theme)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var error := ResourceSaver.save(theme, OUTPUT_PATH)
	if error != OK:
		push_error("Could not save theme: %s" % error_string(error))
	else:
		print("Saved ", OUTPUT_PATH)
	quit()


func _add_label_styles(theme: Theme, caps_font: Font, numeric_font: Font) -> void:
	theme.set_color("font_color", "Label", Palette.WHITE)

	_label_variation(theme, "TitleLabel", Palette.WHITE, FONT_SIZE_TITLE)
	_label_variation(theme, "HeadingLabel", Palette.WHITE, FONT_SIZE_HEADING)
	_label_variation(theme, "SubheadingLabel", Palette.WHITE, FONT_SIZE_SUBHEADING)
	_label_variation(theme, "SpecialLabel", Palette.YELLOW, FONT_SIZE_SUBHEADING)
	_label_variation(theme, "MutedLabel", Palette.MUTED_TEXT, FONT_SIZE_BODY)
	_label_variation(theme, "KickerLabel", Palette.CYAN, FONT_SIZE_KICKER, caps_font)
	_label_variation(theme, "CaptionLabel", Palette.MUTED_TEXT, FONT_SIZE_CAPTION, caps_font)
	_label_variation(theme, "ValueLabel", Palette.WHITE, FONT_SIZE_VALUE, numeric_font)
	_label_variation(theme, "HeroValueLabel", Palette.WHITE, FONT_SIZE_HERO_VALUE, numeric_font)
	_label_variation(theme, "AccentValueLabel", Palette.CYAN, FONT_SIZE_ACCENT_VALUE, numeric_font)


func _label_variation(theme: Theme, name: StringName, color: Color, font_size: int, font: Font = null) -> void:
	theme.set_type_variation(name, "Label")
	theme.set_color("font_color", name, color)
	theme.set_font_size("font_size", name, font_size)
	if font:
		theme.set_font("font", name, font)


func _add_button_styles(theme: Theme) -> void:
	var normal := _box(Palette.PANEL_ELEVATED, Palette.BORDER, CORNER_RADIUS)
	var hover := _box(Palette.PANEL_ELEVATED.lerp(Palette.CYAN, 0.06), Color(Palette.CYAN, 0.55), CORNER_RADIUS)
	var pressed := _box(Palette.PANEL_ELEVATED.lerp(Palette.CYAN, 0.18), Palette.CYAN, CORNER_RADIUS)
	var disabled := _box(Palette.BACKGROUND_SECONDARY, Color(Palette.BORDER, 0.5), CORNER_RADIUS)
	for box: StyleBoxFlat in [normal, hover, pressed, disabled]:
		_set_content_margins(box, 16, 6)

	# Drawn on top of the current state, so keyboard/controller focus stays visible.
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_border_width_all(2)
	focus.border_color = Palette.CYAN
	focus.set_corner_radius_all(CORNER_RADIUS)
	focus.set_expand_margin_all(1)

	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", focus)

	theme.set_color("font_color", "Button", Palette.WHITE)
	theme.set_color("font_hover_color", "Button", Palette.WHITE)
	theme.set_color("font_focus_color", "Button", Palette.WHITE)
	theme.set_color("font_pressed_color", "Button", Palette.CYAN)
	theme.set_color("font_disabled_color", "Button", Color(Palette.MUTED_TEXT, 0.6))


func _add_panel_styles(theme: Theme) -> void:
	var panel := _box(Color(Palette.PANEL, 0.97), Palette.BORDER, PANEL_CORNER_RADIUS)
	panel.shadow_color = Color(0, 0, 0, 0.3)
	panel.shadow_size = 16
	theme.set_stylebox("panel", "PanelContainer", panel)

	# Short cyan accent bar under menu titles.
	var rule := StyleBoxFlat.new()
	rule.bg_color = Palette.CYAN
	theme.set_type_variation("AccentRule", "Panel")
	theme.set_stylebox("panel", "AccentRule", rule)

	# Full-screen dimming behind overlays: light for pause (gameplay stays legible),
	# stronger for screens that replace the gameplay view.
	for entry: Array in [["Scrim", 0.62], ["ScrimStrong", 0.9]]:
		var scrim := StyleBoxFlat.new()
		scrim.bg_color = Color(Palette.BACKGROUND, entry[1])
		theme.set_type_variation(entry[0], "Panel")
		theme.set_stylebox("panel", entry[0], scrim)


func _add_slider_styles(theme: Theme) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Palette.BORDER
	track.set_corner_radius_all(2)
	_set_content_margins(track, 0, 2)

	var filled := track.duplicate() as StyleBoxFlat
	filled.bg_color = Palette.CYAN
	var filled_highlight := track.duplicate() as StyleBoxFlat
	filled_highlight.bg_color = Palette.CYAN.lightened(0.25)

	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled_highlight)
	theme.set_icon("grabber", "HSlider", _dot_texture(Palette.WHITE))
	theme.set_icon("grabber_highlight", "HSlider", _dot_texture(Palette.CYAN))

	# Focus ring on sliders so keyboard navigation through menus stays visible.
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_border_width_all(1)
	focus.border_color = Color(Palette.CYAN, 0.6)
	focus.set_corner_radius_all(CORNER_RADIUS)
	focus.set_expand_margin_all(4)
	theme.set_stylebox("focus", "HSlider", focus)


func _add_progress_styles(theme: Theme) -> void:
	var background := _box(Palette.BACKGROUND_SECONDARY, Palette.BORDER, 2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.CYAN
	fill.set_corner_radius_all(2)
	theme.set_stylebox("background", "ProgressBar", background)
	theme.set_stylebox("fill", "ProgressBar", fill)


func _box(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	return box


func _set_content_margins(box: StyleBox, horizontal: float, vertical: float) -> void:
	box.content_margin_left = horizontal
	box.content_margin_right = horizontal
	box.content_margin_top = vertical
	box.content_margin_bottom = vertical


## Antialiased filled circle used as the slider grabber.
func _dot_texture(color: Color) -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.8, 0.95])
	gradient.colors = PackedColorArray([color, color, Color(color, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 16
	texture.height = 16
	return texture
