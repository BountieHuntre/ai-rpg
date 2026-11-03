extends Node
## Plays named sound effects. Each name picks randomly from its files, with a
## little pitch variation so repeats don't sound identical.

const SOUND_DIR := "res://assets/audio/rpg_sfx/"
const POOL_SIZE := 12
const PITCH_VARIATION := 0.06
const VOLUME_DB := -6.0

const SOUNDS: Dictionary[String, Array] = {
	"swing": ["blade_01", "blade_02", "blade_03"],
	"enemy_hurt": ["creature_hurt_01", "creature_hurt_02"],
	"player_hurt": ["metal_01", "metal_02", "metal_03"],
	"enemy_die": ["creature_die_01"],
	"player_die": ["creature_roar_02"],
	"aggro": ["creature_monster_01", "creature_monster_02", "creature_monster_03"],
	"cast": ["spell_01"],
	"bolt_launch": ["spell_fire_01", "spell_fire_02"],
	"bolt_hit": ["spell_fire_07"],
	"heal": ["spell_02"],
	"stun": ["chain_01", "chain_02"],
	"target": ["acquire_target"],
	"error": ["lock_01"],
	"level_up": ["item_gem_04"],
	"coins": ["item_coins_01", "item_coins_02"],
	"loot": ["item_misc_02"],
	"buff": ["spell_01"],
	"eat": ["item_misc_03"],
	"sell": ["item_coins_03"],
}

## Playback speed for sounds that need it. Raising speed also raises pitch.
const SPEEDS: Dictionary[String, float] = {
	"target": 5.0,
}

var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.volume_db = VOLUME_DB
		add_child(player)
		_players.append(player)


func play(sound_name: String) -> void:
	var files: Array = SOUNDS[sound_name]
	for player in _players:
		if not player.playing:
			player.stream = load("%s%s.ogg" % [SOUND_DIR, files.pick_random()])
			var speed: float = SPEEDS.get(sound_name, 1.0)
			player.pitch_scale = speed * randf_range(1.0 - PITCH_VARIATION, 1.0 + PITCH_VARIATION)
			var effects: float = Settings.get_value("effects_volume")
			player.volume_db = VOLUME_DB + linear_to_db(maxf(effects, 0.0001))
			player.play()
			return
