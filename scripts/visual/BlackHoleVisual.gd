class_name BlackHoleVisual
extends Node2D

## Dark core that fades softly into the background, a thin dim rim, and a few
## small particles being pulled in. Each particle curves slightly as it falls,
## speeds up and shrinks, disappears behind the core and respawns at the edge
## from a new angle.

const CORE_RADIUS := 24.0      # matches BlackHole.tscn collision
const HALO_RADIUS := 64.0
const HALO_STEPS := 10         # stacked translucent circles, darker toward the core
const HALO_STEP_ALPHA := 0.1
const RIM_WIDTH := 1.0
const RIM_PULSE_SPEED := 2.5
const SPAWN_RADIUS := 112.0
const PARTICLE_COUNT := 9
const FALL_DURATION_MIN := 0.8 # seconds from the edge to the core
const FALL_DURATION_MAX := 1.4
const PARTICLE_SIZE_MIN := 1.0
const PARTICLE_SIZE_MAX := 2.2
const SWIRL_TURNS := 0.12      # slight curve while falling, well short of an orbit
const TAIL_LENGTH := 0.1       # fraction of the fall drawn as a fading tail

var _time := 0.0
var _phase := PackedFloat32Array()
var _duration := PackedFloat32Array()
var _size := PackedFloat32Array()
var _angle := PackedFloat32Array()
var _cycle := PackedInt32Array()


func _ready() -> void:
	_phase.resize(PARTICLE_COUNT)
	_duration.resize(PARTICLE_COUNT)
	_size.resize(PARTICLE_COUNT)
	_angle.resize(PARTICLE_COUNT)
	_cycle.resize(PARTICLE_COUNT)
	for i in PARTICLE_COUNT:
		_phase[i] = randf()
		_duration[i] = randf_range(FALL_DURATION_MIN, FALL_DURATION_MAX)
		_size[i] = randf_range(PARTICLE_SIZE_MIN, PARTICLE_SIZE_MAX)
		_angle[i] = randf() * TAU
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, Palette.APPEAR_DURATION)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	for step in HALO_STEPS:
		var radius := lerpf(HALO_RADIUS, CORE_RADIUS, float(step) / HALO_STEPS)
		draw_circle(Vector2.ZERO, radius, Color(Palette.BLACK_HOLE, HALO_STEP_ALPHA))

	for i in PARTICLE_COUNT:
		var progress := _time / _duration[i] + _phase[i]
		var cycle := int(progress)
		if cycle != _cycle[i]:
			_cycle[i] = cycle
			_angle[i] = randf() * TAU
		_draw_particle(i, progress - cycle)

	var pulse := 0.5 + 0.5 * sin(_time * RIM_PULSE_SPEED)
	draw_circle(Vector2.ZERO, CORE_RADIUS, Palette.BLACK_HOLE)
	draw_arc(Vector2.ZERO, CORE_RADIUS, 0.0, TAU, 48, Color(Palette.WHITE, 0.25 + 0.15 * pulse), RIM_WIDTH, true)


func _draw_particle(i: int, t: float) -> void:
	var alpha := minf(t * 3.0, 1.0) * 0.85
	var head := _particle_position(i, t)
	var tail := _particle_position(i, maxf(t - TAIL_LENGTH, 0.0))
	var size := _size[i] * (1.0 - 0.6 * t)
	draw_line(tail, head, Color(Palette.WHITE, alpha * 0.35), size, true)
	draw_circle(head, size * 0.5, Color(Palette.WHITE, alpha))


## Position `t` of the way through particle `i`'s fall; eased so it accelerates inward.
func _particle_position(i: int, t: float) -> Vector2:
	var eased := t * t * t
	var radius := lerpf(SPAWN_RADIUS, CORE_RADIUS * 0.5, eased)
	return Vector2.from_angle(_angle[i] + SWIRL_TURNS * TAU * eased) * radius
