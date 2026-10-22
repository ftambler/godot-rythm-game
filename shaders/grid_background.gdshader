// Quiet world-space grid drawn on a full-screen rect.
// The rect lives in a screen-space CanvasLayer; GridBackground.gd feeds it the
// inverse camera transform so the lines stay fixed in world space and move
// only because the camera moves (no separate scroll speed).
shader_type canvas_item;

uniform vec4 base_color : source_color;
uniform vec4 line_color : source_color;
uniform vec4 major_line_color : source_color;
uniform float cell_size = 36.0;      // world units between lines
uniform int major_every = 4;         // every Nth line uses major_line_color; 0 disables
uniform float line_width = 1.0;      // logical pixels, independent of camera zoom
uniform vec2 rect_size = vec2(1152.0, 648.0); // logical size of the rect
uniform vec2 world_origin;           // world position under the rect's top-left corner
uniform vec2 world_per_pixel = vec2(1.0); // world units per logical pixel (inverse zoom)

// Coverage of the nearest line along one axis, antialiased over one physical pixel.
float line_coverage(float world_coord, float px_per_world, float aa) {
	float distance_px = abs(fract(world_coord / cell_size + 0.5) - 0.5) * cell_size * px_per_world;
	return clamp((0.5 * line_width - distance_px) / aa + 0.5, 0.0, 1.0);
}

vec4 line_tint(float world_coord) {
	if (major_every > 0 && mod(round(world_coord / cell_size), float(major_every)) == 0.0) {
		return major_line_color;
	}
	return line_color;
}

void fragment() {
	vec2 screen_pos = UV * rect_size;
	vec2 world = world_origin + screen_pos * world_per_pixel;
	// Logical pixels per physical pixel; > 1 only when the window is smaller than the base size.
	vec2 aa = max(fwidth(screen_pos), vec2(0.001));

	float cover_x = line_coverage(world.x, 1.0 / world_per_pixel.x, aa.x);
	float cover_y = line_coverage(world.y, 1.0 / world_per_pixel.y, aa.y);

	vec3 color = base_color.rgb;
	color = mix(color, line_tint(world.x).rgb, cover_x);
	color = mix(color, line_tint(world.y).rgb, cover_y);
	COLOR = vec4(color, 1.0);
}
