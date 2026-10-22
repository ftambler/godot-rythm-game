class_name GridBackground
extends CanvasLayer

## Screen-space background that renders a world-anchored grid.
## Reads the viewport's canvas transform (set by the active Camera2D) every frame,
## so the grid follows the existing camera exactly, including its drag margins and
## smoothing. Without a camera (menus) the transform is identity and the grid is static.

@onready var _rect: ColorRect = $Grid

var _material: ShaderMaterial


func _ready() -> void:
	# Keep tracking the camera while paused, and run after Camera2D (priority 0)
	# has applied this frame's transform so the grid never lags a frame behind.
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100

	_material = _rect.material as ShaderMaterial
	_material.set_shader_parameter("base_color", Palette.BACKGROUND)
	_material.set_shader_parameter("line_color", Palette.GRID)
	_material.set_shader_parameter("major_line_color", Palette.GRID_HIGHLIGHT)
	_material.set_shader_parameter("cell_size", Palette.GRID_CELL_SIZE)
	_material.set_shader_parameter("major_every", Palette.GRID_MAJOR_EVERY)
	_sync()


func _process(_delta: float) -> void:
	_sync()


func _sync() -> void:
	var screen_to_world := get_viewport().get_canvas_transform().affine_inverse()
	_material.set_shader_parameter("rect_size", _rect.size)
	_material.set_shader_parameter("world_origin", screen_to_world.origin)
	_material.set_shader_parameter("world_per_pixel", screen_to_world.get_scale())
