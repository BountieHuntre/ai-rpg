shader_type spatial;
// Colours a character model (tools/models/human/build_human.py) by slot: each
// face's U picks one of 32 colour slots (skin, hair, chest, blade...) and V*2
// shades it, so skin, hair and gear are recoloured without textures.
// HumanoidModel sets the colours (linear) and the flash and corpse tints.
// Opaque, as the outline shader draws over transparent materials.

uniform vec4 slot_colors[32];
// A colour mixed over everything (a corpse's grey), alpha how much.
uniform vec4 tint = vec4(0.0);
// A hit flash: glows white.
uniform float flash = 0.0;

void fragment() {
	int slot = clamp(int(UV.x * 32.0), 0, 31);
	vec3 color = slot_colors[slot].rgb * UV.y * 2.0;
	color = mix(color, tint.rgb, tint.a);
	ALBEDO = mix(color, vec3(1.0), flash);
	EMISSION = vec3(flash * 0.8);
	ROUGHNESS = 0.9;
}
