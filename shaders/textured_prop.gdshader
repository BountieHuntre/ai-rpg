shader_type spatial;
// Building blocks (Props boxes, roofs and posts) with a pixel-art texture
// projected from three sides in world space, so stone courses and planks
// line up across neighbouring blocks, tinted toward the block's own color.

render_mode diffuse_lambert, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
// Yards the texture spans.
uniform float texture_size = 4.0;
// Multiplies the texture: the block's color over the texture's average.
uniform vec3 tint = vec3(1.0);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 w = pow(abs(world_normal), vec3(6.0));
	w /= (w.x + w.y + w.z);
	vec3 p = world_pos / texture_size;
	vec3 color = texture(albedo_tex, vec2(p.z, -p.y)).rgb * w.x
		+ texture(albedo_tex, p.xz).rgb * w.y
		+ texture(albedo_tex, vec2(p.x, -p.y)).rgb * w.z;
	ALBEDO = color * tint;
	ROUGHNESS = 1.0;
}
