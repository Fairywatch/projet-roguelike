class_name Sound
extends RefCounted

# Effets sonores (enregistrements CC0 importes par tools/import_sfx.py, voir SfxManifest) et
# musique (tools/gen_audio.py). Classe statique : les lecteurs sont ajoutes a la racine de
# l'arbre, donc la musique survit aux changements de scene.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const MUSIC_DB := -8.0
# Bus audio dont Settings regle le volume (curseurs Musique / Effets sonores).
const BUSES := {"Music": "music_volume", "SFX": "sfx_volume"}
const FADE := 0.8
# Un meme son joue plusieurs fois dans la meme frame (4 mobs qui telegraphient) : on n'en garde qu'un.
const MIN_INTERVAL := 0.05

static var _music_player: AudioStreamPlayer
static var _music_name := ""
static var _last_played := {}

static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

# Joue une variante au hasard de l'effet (hauteur et volume de base dans SfxManifest).
static func play(sfx_name: String, volume_db: float = 0.0, pitch_jitter: float = 0.06) -> void:
	var tree := _tree()
	if tree == null or Settings.volume("sfx_volume") <= 0.0:
		return
	var entry: Dictionary = SfxManifest.SFX.get(sfx_name, {})
	if entry.is_empty():
		push_warning("Effet sonore inconnu : %s" % sfx_name)
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_played.get(sfx_name, -1.0) < MIN_INTERVAL:
		return
	_last_played[sfx_name] = now
	var player := AudioStreamPlayer.new()
	player.bus = "SFX"
	player.stream = load("%s%s_%d.ogg" % [SFX_DIR, sfx_name, randi() % entry["variants"]])
	player.volume_db = entry["db"] + volume_db
	player.pitch_scale = entry["pitch"] * (1.0 + randf_range(-pitch_jitter, pitch_jitter))
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.autoplay = true
	player.finished.connect(player.queue_free)
	# Differe : la racine peut etre occupee (son joue pendant le _ready d'une scene).
	tree.root.add_child.call_deferred(player)

# Change de musique en fondu ; ne fait rien si elle joue deja.
static func music(music_name: String) -> void:
	var tree := _tree()
	if tree == null:
		return
	_music_name = music_name
	if Settings.volume("music_volume") <= 0.0:
		stop_music()
		return
	if _music_player and is_instance_valid(_music_player) and _music_player.get_meta("track", "") == music_name:
		return
	stop_music()
	var stream: AudioStreamWAV = load(MUSIC_DIR + music_name + ".wav")
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.stream = stream
	_music_player.set_meta("track", music_name)
	_music_player.volume_db = -40.0
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player.autoplay = true
	tree.root.add_child.call_deferred(_music_player)
	tree.create_tween().tween_property(_music_player, "volume_db", MUSIC_DB, FADE)

static func stop_music() -> void:
	if _music_player and is_instance_valid(_music_player):
		var old := _music_player
		var tween := _tree().create_tween()
		tween.tween_property(old, "volume_db", -40.0, FADE)
		tween.tween_callback(old.queue_free)
	_music_player = null

# Cree les bus Music / SFX au besoin et y applique les volumes choisis dans les parametres.
static func apply_volumes() -> void:
	for bus in BUSES:
		var index := AudioServer.get_bus_index(bus)
		if index == -1:
			AudioServer.add_bus()
			index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
		var level := Settings.volume(BUSES[bus])
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.0001)))
		AudioServer.set_bus_mute(index, level <= 0.0)

# Appele quand un reglage audio change.
static func refresh_music() -> void:
	if _music_name != "":
		music(_music_name)
