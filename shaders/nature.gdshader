shader_type spatial;
// Trees and rocks built by Nature: a pixel-art texture projected from three
// sides in the mesh's own space (so it stays put on each copy), times the
// vertex color (Nature bakes light tops, dark undersides and moss into it).
// Foliage sways a little in the wind, more toward its top.

render_mode diffuse_lambert, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
// Yards the texture spans.
uniform float texture_size = 3.0;
// The vertex color is a shade from 0 to 1; this brings 0.8 back to the
// texture's own color.
uniform float brightness = 1.25;
// Wind: how far the top moves, in yards, and how fast.
uniform float sway = 0.0;
uniform float sway_speed = 1.3;
// Sway starts above this height (the trunk stays still).
uniform float sway_from = 1.5;

varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
	if (sway > 0.0) {
		vec3 origin = MODEL_MATRIX[3].xyz;
		float phase = origin.x * 0.37 + origin.z * 0.23;
		float lift = max(VERTEX.y - sway_from, 0.0);
		float bend = sway * lift * 0.12;
		VERTEX.x += sin(TIME * sway_speed + phase) * bend;
		VERTEX.z += cos(TIME * sway_speed * 0.8 + phase * 1.3) * bend * 0.6;
	}
}

void fragment() {
	vec3 w = pow(abs(local_normal), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 p = local_pos / texture_size;
	vec3 color = texture(albedo_tex, vec2(p.z, -p.y)).rgb * w.x
		+ texture(albedo_tex, p.xz).rgb * w.y
		+ texture(albedo_tex, vec2(p.x, -p.y)).rgb * w.z;
	ALBEDO = color * COLOR.rgb * brightness;
	ROUGHNESS = 1.0;
}
