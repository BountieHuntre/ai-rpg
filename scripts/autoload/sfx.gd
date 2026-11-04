extends Node
## Plays named sound effects. Each name picks randomly from its files, with a
## little pitch variation so repeats don't sound identical.

const SOUND_DIR := "res://assets/audio/rpg_sfx/"
const POOL_SIZE := 12
const PITCH_VARIATION := 0.06
## Every sound's base level: three quarters of the old -6 dB.
const VOLUME_DB := -6.0 + 20.0 * log(0.75) / log(10.0)
## World sounds fade with distance from you: full within NEAR, nothing
## beyond HEARING_RANGE, and a smooth falloff between.
const NEAR := 4.0
const HEARING_RANGE := 40.0

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


## Plays a sound made somewhere in the world, quieter the further it is from
## you (the player, or the camera without one), and not at all out of earshot.
func play_at(sound_name: String, at: Vector3) -> void:
	var listener := get_tree().get_first_node_in_group("player") as Node3D
	var ear := listener.global_position if listener else Vector3.INF
	if listener == null:
		var camera := get_viewport().get_camera_3d()
		if camera == null:
			play(sound_name)
			return
		ear = camera.global_position
	var loudness := falloff(ear.distance_to(at))
	if loudness > 0.0:
		play(sound_name, loudness)


## How loud a sound is at a distance, 1 to 0: full up close, then fading as
## the square of how far into the hearing range it is.
static func falloff(distance: float) -> float:
	if distance <= NEAR:
		return 1.0
	if distance >= HEARING_RANGE:
		return 0.0
	var t := (distance - NEAR) / (HEARING_RANGE - NEAR)
	return (1.0 - t) * (1.0 - t)


## Plays a sound at a share of its full volume (1 for interface sounds).
func play(sound_name: String, loudness := 1.0) -> void:
	var files: Array = SOUNDS[sound_name]
	for player in _players:
		if not player.playing:
			player.stream = load("%s%s.ogg" % [SOUND_DIR, files.pick_random()])
			var speed: float = SPEEDS.get(sound_name, 1.0)
			player.pitch_scale = speed * randf_range(1.0 - PITCH_VARIATION, 1.0 + PITCH_VARIATION)
			var effects: float = Settings.get_value("effects_volume")
			player.volume_db = VOLUME_DB + linear_to_db(maxf(effects * loudness, 0.0001))
			player.play()
			return
