shader_type spatial;
render_mode unshaded;

// MIT License. Made by Leo Peltola
// Inspired by https://threejs.org/examples/webgl_postprocessing_pixel.html

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_nearest;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform sampler2D NORMAL_TEXTURE : hint_normal_roughness_texture, filter_nearest;

uniform int pixel_size : hint_range(1, 16) = 1;
uniform bool shadows_enabled = true;
uniform bool highlights_enabled = true;
uniform float shadow_strength : hint_range(0.0, 1.0, 0.01) = 0.4;
uniform float highlight_strength : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform vec3 highlight_color : source_color = vec3(1.);
uniform vec3 shadow_color : source_color = vec3(0.0);

varying mat4 model_view_matrix;


float getDepth(vec2 screen_uv, sampler2D depth_texture, mat4 inv_projection_matrix){
//	Credit: https://godotshaders.com/shader/depth-modulated-pixel-outline-in-screen-space/
	float raw_depth = texture(depth_texture, screen_uv)[0];
	vec3 normalized_device_coordinates = vec3(screen_uv * 2.0 - 1.0, raw_depth);
    vec4 view_space = inv_projection_matrix * vec4(normalized_device_coordinates, 1.0);	
	view_space.xyz /= view_space.w;	
	return -view_space.z;
}

vec3 getPos(float depth, mat4 mvm, mat4 ipm, vec2 suv, mat4 wm, mat4 icm){
  vec4 pos = inverse(mvm) * ipm * vec4((suv * 2.0 - 1.0), depth * 2.0 - 1.0, 1.0);
  pos.xyz /= (pos.w+0.0001*(1.-abs(sign(pos.w))));
  return (pos*icm).xyz+wm[3].xyz;
}

// Changed for this game: a highlight only counts neighbours at about the same
// depth, so it marks creases within a surface. Before, the background along a
// silhouette's edge (ground behind a tree's canopy) picked up a light line.
float normalIndicator(vec3 normalEdgeBias, vec3 baseNormal, vec3 newNormal, float depth, float new_depth){
	// Credit: https://threejs.org/examples/webgl_postprocessing_pixel.html
	float normalDiff = dot(baseNormal - newNormal, normalEdgeBias);
	float normalIndicator = clamp(smoothstep(-.01, .01, normalDiff), 0.0, 1.0);
	float sameSurface = 1.0 - step(depth * 0.02 + 0.05, abs(new_depth - depth));
	return (1.0 - dot(baseNormal, newNormal)) * sameSurface * normalIndicator;
}

void vertex(){
    model_view_matrix = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 block = float(pixel_size) / VIEWPORT_SIZE.xy;
	vec2 uv = floor(SCREEN_UV / block) * block + 0.5 / VIEWPORT_SIZE.xy;
	vec2 e = block;
	
//	Shadows
	float depth_diff = 0.0;
	float neg_depth_diff = .5;
	float depth = getDepth(uv, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
	float du = getDepth(uv+vec2(0., -1.)*e, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
	float dr = getDepth(uv+vec2(1., 0.)*e, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
	float dd = getDepth(uv+vec2(0., 1.)*e, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
	float dl = getDepth(uv+vec2(-1., 0.)*e, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
	if (shadows_enabled) {
		// Changed for this game: each side's step is measured against the
		// opposite side's, so a smooth slope (distant ground, where every pixel
		// is a little farther than the one below) isn't outlined. Only real
		// silhouettes are. Before, distant ground was darkened all over except
		// the row just behind a nearer object, which read as a light outline.
		// Steps are relative to the distance, so the small bends where terrain
		// triangles meet far away don't count either.
		float scale = 1.0 / max(depth, 0.001);
		depth_diff += clamp(((du - depth) - max(depth - dd, 0.)) * scale, 0., 1.);
		depth_diff += clamp(((dd - depth) - max(depth - du, 0.)) * scale, 0., 1.);
		depth_diff += clamp(((dr - depth) - max(depth - dl, 0.)) * scale, 0., 1.);
		depth_diff += clamp(((dl - depth) - max(depth - dr, 0.)) * scale, 0., 1.);
		neg_depth_diff += depth - du;
		neg_depth_diff += depth - dd;
		neg_depth_diff += depth - dr;
		neg_depth_diff += depth - dl;
		neg_depth_diff = clamp(neg_depth_diff, 0., 1.);
		neg_depth_diff = clamp(smoothstep(0.5, 0.5, neg_depth_diff)*10., 0., 1.);
		depth_diff = smoothstep(0.02, 0.04, depth_diff);
//		ALBEDO = vec3(neg_depth_diff);
	}
	
//	Highlights
	float normal_diff = 0.;
	if (highlights_enabled) {
		vec3 normal = texture(NORMAL_TEXTURE, uv).rgb * 2.0 - 1.0;
		vec3 nu = texture(NORMAL_TEXTURE, uv+vec2(0., -1.)*e).rgb * 2.0 - 1.0;
		vec3 nr = texture(NORMAL_TEXTURE, uv+vec2(1., 0.)*e).rgb * 2.0 - 1.0;
		vec3 nd = texture(NORMAL_TEXTURE, uv+vec2(0., 1.)*e).rgb * 2.0 - 1.0;
		vec3 nl = texture(NORMAL_TEXTURE, uv+vec2(-1., 0.)*e).rgb * 2.0 - 1.0;
		vec3 normal_edge_bias = (vec3(1., 1., 1.));
		normal_diff += normalIndicator(normal_edge_bias, normal, nu, depth, du);
		normal_diff += normalIndicator(normal_edge_bias, normal, nr, depth, dr);
		normal_diff += normalIndicator(normal_edge_bias, normal, nd, depth, dd);
		normal_diff += normalIndicator(normal_edge_bias, normal, nl, depth, dl);
		normal_diff = smoothstep(0.2, 0.8, normal_diff);
		normal_diff = clamp(normal_diff-neg_depth_diff, 0., 1.);
//		ALBEDO = vec3(normal_diff);
	}
	

	vec3 original_color = texture(SCREEN_TEXTURE, uv).rgb;
	vec3 final_highlight_color = mix(original_color, highlight_color, highlight_strength);
	vec3 final_shadow_color = mix(original_color, shadow_color, shadow_strength);
	vec3 final = original_color;
	if (highlights_enabled) {
		final = mix(final, final_highlight_color, normal_diff);
	}
	if (shadows_enabled) {
		final = mix(final, final_shadow_color, depth_diff);
	}
	ALBEDO = final;

	float alpha_mask = depth_diff * float(shadows_enabled) + normal_diff * float(highlights_enabled);
	// Above 1, every pixel must be drawn so the scene itself gets pixelated.
	ALPHA = pixel_size > 1 ? 1.0 : clamp((alpha_mask) * 5., 0., 1.);
}
