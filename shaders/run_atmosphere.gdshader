shader_type canvas_item;
render_mode unshaded;

uniform float drift_time = 0.0;
uniform float speed : hint_range(0.0, 0.2) = 0.025;
uniform float scale : hint_range(1.0, 12.0) = 4.0;
uniform vec4 deep_color : source_color = vec4(0.003, 0.006, 0.014, 1.0);
uniform vec4 cloud_color : source_color = vec4(0.025, 0.07, 0.12, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), u.x), u.y);
}

float clouds(vec2 p) {
	float value = 0.0;
	float weight = 0.55;
	for (int i = 0; i < 4; i++) {
		value += noise(p) * weight;
		p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p + vec2(2.7, 7.1);
		weight *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 p = UV * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0) * scale;
	float time = drift_time * speed;
	vec2 warp = vec2(noise(p * 0.7 + time * 0.3), noise(p * 0.7 - time * 0.2 + 11.0));
	float mist = clouds(p + warp * 1.7 + vec2(time, -time * 0.35));
	float veil = smoothstep(0.28, 0.85, mist);
	float vignette = 1.0 - smoothstep(0.3, 0.85, distance(UV, vec2(0.5))) * 0.5;
	COLOR = vec4(mix(deep_color.rgb, cloud_color.rgb, veil * vignette * 0.65), 1.0);
}
