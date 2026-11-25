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
// An enchanted weapon's blade glowing in its enchant's colour, alpha how
// strongly (HumanoidModel, Enchanting.weapon_look).
uniform vec4 blade_glow = vec4(0.0);
const int BLADE_SLOT = 12;
// What each slot is made of (HumanoidModel.Pattern: weave, leather, mail,
// plate, wood...): a grey tile from gear_patterns laid under its colour, by
// the model's second UV map (yards along and around each piece); 0 is none.
uniform int slot_pattern[32];
uniform sampler2DArray gear_patterns : filter_nearest_mipmap, repeat_enable;
// Yards each pattern's tile spans, by Pattern (index 0 unused).
const float PATTERN_YARDS[16] = float[](1.0, 0.4, 0.6, 0.6, 0.6, 0.45, 0.7, 0.28, 0.4, 0.7, 0.6, 0.45, 0.6,
	0.15, 0.4, 0.5);

void fragment() {
	int slot = clamp(int(UV.x * 32.0), 0, 31);
	vec3 color = slot_colors[slot].rgb * UV.y * 2.0;
	int pattern = slot_pattern[slot];
	if (pattern > 0) {
		float grey = texture(gear_patterns, vec3(UV2 / PATTERN_YARDS[pattern], float(pattern - 1))).r;
		// Lighter in its dark spots than doubling the grey would be, so worn
		// gear isn't muddy, with its highlights kept.
		color *= 0.45 + grey * 1.15;
	}
	color = mix(color, tint.rgb, tint.a);
	vec3 glow = slot == HANDS_SLOT ? hand_glow.rgb * hand_glow.a : vec3(0.0);
	if (slot == BLADE_SLOT) {
		glow += blade_glow.rgb * blade_glow.a;
		color = mix(color, blade_glow.rgb, min(blade_glow.a * 1.2, 0.9));
	}
	ALBEDO = mix(mix(color, hand_glow.rgb, slot == HANDS_SLOT ? hand_glow.a * 0.7 : 0.0), vec3(1.0), flash);
	EMISSION = vec3(flash * 0.8) + glow * 1.5;
	ROUGHNESS = 0.9;
}
