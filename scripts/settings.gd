class_name Settings
extends RefCounted

# Parametres du joueur, sauvegardes dans user://settings.cfg (charges au demarrage par GameState).
# Classe statique plutot qu'autoload : utilisable depuis Fx / DreamTheme sans dependance d'ordre.

const PATH := "user://settings.cfg"
const SECTION := "options"
# Options on/off : nom -> libelle dans le menu.
const LABELS := {
	"screen_shake": "Secousses d'ecran",
	"hitstop": "Arret sur image a l'impact",
	"flashes": "Flashs lumineux",
	"ambient_particles": "Particules d'ambiance",
	"fullscreen": "Plein ecran",
}
# Volumes de 0 (coupe) a 1 : nom -> libelle du curseur dans le menu.
const SLIDERS := {
	"music_volume": "Musique",
	"sfx_volume": "Effets sonores",
}

static var values := {
	"screen_shake": true,
	"hitstop": true,
	"flashes": true,
	"ambient_particles": true,
	"fullscreen": false,
	"music_volume": 0.7,
	"sfx_volume": 0.6,
}

static func enabled(option: String) -> bool:
	return values.get(option, true)

static func volume(option: String) -> float:
	return clampf(values.get(option, 1.0), 0.0, 1.0)

static func set_option(option: String, value: Variant) -> void:
	values[option] = value
	apply()
	var config := ConfigFile.new()
	for key in values:
		config.set_value(SECTION, key, values[key])
	config.save(PATH)

static func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		for key in values:
			values[key] = config.get_value(SECTION, key, values[key])
	apply()

static func apply() -> void:
	Sound.apply_volumes()
	Sound.refresh_music()
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if values["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
