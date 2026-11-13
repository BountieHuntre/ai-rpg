shader_type spatial;
// Grass and flower clumps: crossed cards with a painted, cut-out texture.
// Lit as the ground under them is (their normals point up), darker at the
// root, swaying at the top, tinted by the same large patches as the ground,
// and shrinking away with distance so they never pop out of sight.

render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_disable;
uniform sampler2D patch_noise : filter_linear_mipmap, repeat_enable;
uniform float patch_strength = 0.12;
uniform float alpha_cut = 0.5;
uniform float sway = 0.08;
uniform float sway_speed = 1.6;
// Yards from the camera where clumps start to shrink, and are gone.
uniform float fade_start = 45.0;
uniform float fade_end = 60.0;
// How dark the root is.
uniform float root_shade = 0.8;

varying vec3 world_pos;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float distance_to_camera = distance(origin, CAMERA_POSITION_WORLD);
	float grow = 1.0 - smoothstep(fade_start, fade_end, distance_to_camera);
	VERTEX *= grow;
	float top = 1.0 - UV.y;
	float phase = origin.x * 0.5 + origin.z * 0.31;
	VERTEX.x += sin(TIME * sway_speed + phase) * sway * top;
	VERTEX.z += cos(TIME * sway_speed * 0.7 + phase) * sway * top * 0.6;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 texel = texture(albedo_tex, UV);
	if (texel.a < alpha_cut) {
		discard;
	}
	float patches = texture(patch_noise, world_pos.xz * 0.012).r;
	vec3 color = texel.rgb * (1.0 + (patches - 0.5) * 2.0 * patch_strength);
	color *= mix(root_shade, 1.0, smoothstep(1.0, 0.45, UV.y));
	ALBEDO = color;
	// Both sides lit as the ground is: straight up, whichever side shows
	// (back faces would otherwise get the normal turned down).
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ROUGHNESS = 1.0;
}
