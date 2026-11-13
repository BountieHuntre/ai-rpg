shader_type spatial;
// Pixel-art water: clear and pale where it's shallow, darker and more
// opaque where deep, with slow pixel ripples drifting two ways and a ragged
// line of foam along the shore. Depth is how far below the surface (straight
// down) whatever shows through lies, so someone wading isn't foamed over.

render_mode blend_mix, cull_back, diffuse_lambert, specular_schlick_ggx, depth_draw_opaque;

uniform vec3 shallow_color : source_color = vec3(0.4, 0.58, 0.58);
uniform vec3 deep_color : source_color = vec3(0.2, 0.34, 0.42);
uniform vec3 foam_color : source_color = vec3(0.86, 0.93, 0.95);
uniform sampler2D ripple_noise : filter_nearest, repeat_enable;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
// Yards of water to go from shallow to deep.
uniform float depth_fade = 1.4;
uniform float foam_width = 0.25;
// Ripple pixels per yard.
uniform float pixels = 8.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float raw = texture(depth_texture, SCREEN_UV).r;
	vec4 under = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	under.xyz /= under.w;
	vec3 under_world = (INV_VIEW_MATRIX * vec4(under.xyz, 1.0)).xyz;
	float depth = max(world_pos.y - under_world.y, 0.0);
	float deep = clamp(depth / depth_fade, 0.0, 1.0);
	vec2 p = floor(world_pos.xz * pixels) / pixels;
	float r1 = texture(ripple_noise, p * 0.17 + TIME * vec2(0.01, 0.005)).r;
	float r2 = texture(ripple_noise, p * 0.23 - TIME * vec2(0.006, 0.011)).r;
	float ripple = r1 + r2;
	vec3 color = mix(shallow_color, deep_color, deep);
	// Thin glints where the two ripple layers crest together.
	color += step(1.34, ripple) * 0.08 + step(1.42, ripple) * 0.08;
	color -= step(ripple, 0.66) * 0.04;
	float foam = step(depth, foam_width + (r1 - 0.5) * 0.4);
	color = mix(color, foam_color, foam * 0.85);
	ALBEDO = color;
	ALPHA = max(mix(0.6, 0.92, deep), foam * 0.9);
	ROUGHNESS = 0.2;
	SPECULAR = 0.35;
}
