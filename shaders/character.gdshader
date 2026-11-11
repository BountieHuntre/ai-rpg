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
// Hands glowing while casting: the spell's colour, alpha how strongly.
uniform vec4 hand_glow = vec4(0.0);
// The hands' colour slot (HumanoidModel's HANDS).
const int HANDS_SLOT = 6;

void fragment() {
	int slot = clamp(int(UV.x * 32.0), 0, 31);
	vec3 color = slot_colors[slot].rgb * UV.y * 2.0;
	color = mix(color, tint.rgb, tint.a);
	vec3 glow = slot == HANDS_SLOT ? hand_glow.rgb * hand_glow.a : vec3(0.0);
	ALBEDO = mix(mix(color, hand_glow.rgb, slot == HANDS_SLOT ? hand_glow.a * 0.7 : 0.0), vec3(1.0), flash);
	EMISSION = vec3(flash * 0.8) + glow * 1.5;
	ROUGHNESS = 0.9;
}
