shader_type spatial;
// Textured ground: grass with forest floor, dirt, cobbles and rock laid over
// it by weights the zone works out per vertex (Terrain: UV.x dirt, UV.y
// cobbles, UV2.x rock, UV2.y forest floor). Borders between them are made
// ragged by noise, so they read as patches rather than smooth fades. Rock
// is projected from three sides (triplanar), so cliffs aren't smeared. The
// vertex color tints it (darker mud by the stream). Textures are pixel art,
// sampled nearest with mipmaps.

render_mode diffuse_lambert, specular_disabled;

uniform sampler2D grass_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D forest_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D cobble_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_nearest_mipmap, repeat_enable;
// Seamless noise for the ragged borders and the large patches.
uniform sampler2D blend_noise : filter_linear_mipmap, repeat_enable;
// Yards a texture spans.
uniform float grass_size = 6.0;
uniform float dirt_size = 6.0;
uniform float cobble_size = 5.0;
uniform float rock_size = 6.0;
// How hard the borders are (smaller is crisper).
uniform float border_softness = 0.06;
// Large-scale light and dark patches over the grass.
uniform float patch_strength = 0.12;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 triplanar(sampler2D tex, vec3 p, vec3 n, float size) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 side_x = texture(tex, vec2(p.z, -p.y) / size).rgb;
	vec3 top = texture(tex, p.xz / size).rgb;
	vec3 side_z = texture(tex, vec2(p.x, -p.y) / size).rgb;
	return side_x * w.x + top * w.y + side_z * w.z;
}

// A weight made ragged: it takes over where it beats the noise.
float ragged(float weight, float noise) {
	if (weight <= 0.001) {
		return 0.0;
	}
	if (weight >= 0.999) {
		return 1.0;
	}
	float threshold = mix(0.2, 0.8, noise);
	return smoothstep(threshold - border_softness, threshold + border_softness, weight);
}

void fragment() {
	vec2 p = world_pos.xz;
	float n1 = texture(blend_noise, p * 0.11).r;
	float n2 = texture(blend_noise, p * 0.27 + vec2(0.37, 0.71)).r;
	float n = n1 * 0.65 + n2 * 0.35;
	vec3 color = texture(grass_tex, p / grass_size).rgb;
	float patches = texture(blend_noise, p * 0.012).r;
	color *= 1.0 + (patches - 0.5) * 2.0 * patch_strength;
	color = mix(color, texture(forest_tex, p / grass_size).rgb, ragged(UV2.y, n));
	color = mix(color, texture(dirt_tex, p / dirt_size).rgb, ragged(UV.x, 1.0 - n));
	color = mix(color, texture(cobble_tex, p / cobble_size).rgb, ragged(UV.y, n2));
	color = mix(color, triplanar(rock_tex, world_pos, world_normal, rock_size), ragged(UV2.x, n1));
	ALBEDO = color * COLOR.rgb;
	ROUGHNESS = 1.0;
}
