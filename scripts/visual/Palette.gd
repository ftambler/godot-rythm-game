class_name Palette
extends RefCounted

## Shared "Minimal Neon" design tokens.
## Gameplay visuals read these directly; the UI theme is generated from them
## by scripts/visual/build_theme.gd, so this file is the single source of truth.


# Surfaces
const BACKGROUND := Color("#080B18")
const BACKGROUND_SECONDARY := Color("#0D1222")
const GRID := Color("#151D32")
const GRID_HIGHLIGHT := Color("#1B2740")
const PANEL := Color("#11182A")
const PANEL_ELEVATED := Color("#182239")
const BORDER := Color("#293650")

# Accents (each one has a single role)
const CYAN := Color("#35E7F2")    # player identity, primary values
const PINK := Color("#FF4FA3")    # misses, damage
const GREEN := Color("#78F59A")   # successful interactions
const YELLOW := Color("#FFD166")  # speed changes, special events
const WALL := Color("#4FB4FF")    # cool blue variant of cyan for static obstacles

# Text
const WHITE := Color("#F3F6FF")
const MUTED_TEXT := Color("#8D9AB5")

# Glow: translucent under-strokes, widths in pixels added to the core stroke
const GLOW_NEAR_WIDTH := 5.0
const GLOW_NEAR_ALPHA := 0.16
const GLOW_FAR_WIDTH := 12.0
const GLOW_FAR_ALPHA := 0.05

# Geometry (logical pixels). Visual only; collision shapes live in their scenes.
const OUTLINE_WIDTH := 2.0
const PLAYER_SIZE := 20.0
const SHIELD_RADIUS := 22.0
const SHIELD_WIDTH := 5.0
const SHIELD_ARC := PI * 0.5
const WALL_LENGTH := 80.0  # matches Wall.tscn collision: RectangleShape2D(20) * scale.x 4
const WALL_THICKNESS := 6.0
const ORB_CORE_RADIUS := 5.5
const ORB_RING_RADIUS := 9.0
const ORB_OUTER_RADIUS := 13.0
const GRID_CELL_SIZE := 36.0
const GRID_MAJOR_EVERY := 4

# Timing (seconds)
const FLASH_DURATION := 0.18
const EFFECT_DURATION := 0.3
const PULSE_DURATION := 0.14
const APPEAR_DURATION := 0.12


static func hit_result_color(result: HitResult.Type) -> Color:
	match result:
		HitResult.Type.FULL:
			return GREEN
		HitResult.Type.HALF:
			return YELLOW

	return PINK
