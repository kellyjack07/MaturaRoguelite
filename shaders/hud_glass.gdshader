shader_type canvas_item;
render_mode unshaded;

uniform sampler2D world_screen : hint_screen_texture, repeat_disable, filter_linear;
uniform float blur_radius : hint_range(0.0, 6.0) = 2.0;
uniform float darkening : hint_range(0.0, 0.8) = 0.28;

void fragment() {
	vec2 step_size = SCREEN_PIXEL_SIZE * blur_radius;
	vec3 blurred = texture(world_screen, SCREEN_UV).rgb * 0.25;
	blurred += texture(world_screen, SCREEN_UV + vec2(step_size.x, 0.0)).rgb * 0.125;
	blurred += texture(world_screen, SCREEN_UV - vec2(step_size.x, 0.0)).rgb * 0.125;
	blurred += texture(world_screen, SCREEN_UV + vec2(0.0, step_size.y)).rgb * 0.125;
	blurred += texture(world_screen, SCREEN_UV - vec2(0.0, step_size.y)).rgb * 0.125;
	blurred += texture(world_screen, SCREEN_UV + step_size).rgb * 0.0625;
	blurred += texture(world_screen, SCREEN_UV - step_size).rgb * 0.0625;
	blurred += texture(world_screen, SCREEN_UV + vec2(step_size.x, -step_size.y)).rgb * 0.0625;
	blurred += texture(world_screen, SCREEN_UV + vec2(-step_size.x, step_size.y)).rgb * 0.0625;
	// Fade the effect at the edges instead of drawing a hard panel border.
	vec2 edge = smoothstep(vec2(0.0), vec2(0.07), UV) * smoothstep(vec2(0.0), vec2(0.07), vec2(1.0) - UV);
	COLOR = vec4(blurred * (1.0 - darkening), edge.x * edge.y);
}
