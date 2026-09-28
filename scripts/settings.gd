class_name Settings
extends RefCounted

# Parametres du joueur, sauvegardes dans user://settings.cfg (charges au demarrage par GameState).
# Classe statique plutot qu'autoload : utilisable depuis Fx / DreamTheme sans dependance d'ordre.

const PATH := "user://settings.cfg"
const SECTION := "options"
# Nom de l'option -> libelle dans le menu.
const LABELS := {
	"screen_shake": "Secousses d'ecran",
	"hitstop": "Arret sur image a l'impact",
	"flashes": "Flashs lumineux",
	"ambient_particles": "Particules d'ambiance",
	"fullscreen": "Plein ecran",
}

static var values := {
	"screen_shake": true,
	"hitstop": true,
	"flashes": true,
	"ambient_particles": true,
	"fullscreen": false,
}

static func enabled(option: String) -> bool:
	return values.get(option, true)

static func set_option(option: String, on: bool) -> void:
	values[option] = on
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
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if values["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
