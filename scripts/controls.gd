class_name Controls

# Touches du jeu : une action Godot par commande, avec une touche clavier et un bouton manette,
# personnalisables (menu Parametres > Touches) et sauvegardes dans user://controls.cfg.
# Touches clavier en codes physiques (position) : KEY_W/KEY_A sont Z/Q sur un AZERTY. Les fleches
# et le stick gauche deplacent toujours, en plus des touches choisies. Dans les menus, A valide et
# B revient (en plus d'Entree et Echap), quelle que soit la manette.

static var path := "user://controls.cfg"  # les tests en utilisent un autre
# action -> [libelle, touche clavier par defaut, bouton manette par defaut]
const ACTIONS := {
	"move_up": ["Haut", KEY_W, JOY_BUTTON_DPAD_UP],
	"move_left": ["Gauche", KEY_A, JOY_BUTTON_DPAD_LEFT],
	"move_down": ["Bas", KEY_S, JOY_BUTTON_DPAD_DOWN],
	"move_right": ["Droite", KEY_D, JOY_BUTTON_DPAD_RIGHT],
	"attack": ["Attaque", KEY_J, JOY_BUTTON_X],
	"dash": ["Dash", KEY_K, JOY_BUTTON_B],
	"special": ["Rafale de plumes", KEY_I, JOY_BUTTON_RIGHT_SHOULDER],
	"active": ["Objet actif", KEY_L, JOY_BUTTON_Y],
	"interact": ["Interagir", KEY_E, JOY_BUTTON_A],
	"inventory": ["Objets passifs", KEY_TAB, JOY_BUTTON_BACK],
	"pause": ["Menu", KEY_ESCAPE, JOY_BUTTON_START],
}
const MOVE_EXTRA := {
	"move_up": [KEY_UP, JOY_AXIS_LEFT_Y, -1.0], "move_down": [KEY_DOWN, JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [KEY_LEFT, JOY_AXIS_LEFT_X, -1.0], "move_right": [KEY_RIGHT, JOY_AXIS_LEFT_X, 1.0],
}
const KEY_NAMES := {KEY_ESCAPE: "Échap", KEY_SPACE: "Espace", KEY_ENTER: "Entrée", KEY_SHIFT: "Maj", KEY_CTRL: "Ctrl"}
const PAD_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Select", JOY_BUTTON_START: "Start", JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_DPAD_UP: "Croix haut", JOY_BUTTON_DPAD_DOWN: "Croix bas",
	JOY_BUTTON_DPAD_LEFT: "Croix gauche", JOY_BUTTON_DPAD_RIGHT: "Croix droite",
}
# Godot numerote les boutons par position (A = celui du bas) : sur une manette PlayStation ou
# Nintendo, on affiche ce qui est ecrit sur le bouton a cette place.
const PAD_STYLE_NAMES := {
	"playstation": {
		JOY_BUTTON_A: "Croix", JOY_BUTTON_B: "Rond", JOY_BUTTON_X: "Carré", JOY_BUTTON_Y: "Triangle",
		JOY_BUTTON_BACK: "Share", JOY_BUTTON_START: "Options", JOY_BUTTON_LEFT_SHOULDER: "L1",
		JOY_BUTTON_RIGHT_SHOULDER: "R1", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	},
	"nintendo": {
		JOY_BUTTON_A: "B", JOY_BUTTON_B: "A", JOY_BUTTON_X: "Y", JOY_BUTTON_Y: "X",
		JOY_BUTTON_BACK: "-", JOY_BUTTON_START: "+", JOY_BUTTON_LEFT_SHOULDER: "L",
		JOY_BUTTON_RIGHT_SHOULDER: "R", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	},
}
const PLAYSTATION_HINTS := ["playstation", "dualshock", "dualsense", "ps3", "ps4", "ps5", "sony"]
const NINTENDO_HINTS := ["nintendo", "switch", "joy-con", "pro controller"]
# Vibrations (Parametres) : suivent les secousses d'ecran, un peu plus longues pour se sentir.
const RUMBLE_MIN := 0.1
const RUMBLE_TIME := 0.09
const RUMBLE_TIME_PER_TRAUMA := 0.35
# Libelles courts des aides a l'ecran.
const HELP := {
	"move": "déplacement", "attack": "attaque", "dash": "dash", "special": "rafale", "active": "objet actif",
	"interact": "interagir", "inventory": "passifs", "pause": "menu",
}

static var keys := {}  # action -> code physique
static var pads := {}  # action -> bouton manette
# Dernier appareil utilise : les aides a l'ecran montrent ses boutons.
static var using_gamepad := false
static var pad_style := "xbox"  # "xbox", "playstation" ou "nintendo" : noms des boutons affiches
static var pad_device := 0

static func setup() -> void:
	var config := ConfigFile.new()
	config.load(path)
	for action in ACTIONS:
		keys[action] = config.get_value("keys", action, ACTIONS[action][1])
		pads[action] = config.get_value("pad", action, ACTIONS[action][2])
	using_gamepad = not Input.get_connected_joypads().is_empty()
	if using_gamepad:
		_use_pad(Input.get_connected_joypads()[0])
	_apply()

static func _apply() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.3)
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, _key_event(keys[action]))
		var button := InputEventJoypadButton.new()
		button.button_index = pads[action]
		InputMap.action_add_event(action, button)
		if MOVE_EXTRA.has(action):
			InputMap.action_add_event(action, _key_event(MOVE_EXTRA[action][0]))
			var axis := InputEventJoypadMotion.new()
			axis.axis = MOVE_EXTRA[action][1]
			axis.axis_value = MOVE_EXTRA[action][2]
			InputMap.action_add_event(action, axis)
	# Menus : A valide, B revient (Godot ne les associe pas par defaut).
	for menu_action in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var button := InputEventJoypadButton.new()
		button.button_index = menu_action[1]
		button.device = -1
		if not InputMap.action_has_event(menu_action[0], button):
			InputMap.action_add_event(menu_action[0], button)

static func _key_event(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event

static func rebind(action: String, event: InputEvent) -> void:
	if event is InputEventKey:
		keys[action] = event.physical_keycode
	elif event is InputEventJoypadButton:
		pads[action] = event.button_index
	_apply()
	_save()

static func reset() -> void:
	for action in ACTIONS:
		keys[action] = ACTIONS[action][1]
		pads[action] = ACTIONS[action][2]
	_apply()
	_save()

static func _save() -> void:
	var config := ConfigFile.new()
	for action in ACTIONS:
		config.set_value("keys", action, keys[action])
		config.set_value("pad", action, pads[action])
	config.save(path)

# Retient l'appareil utilise ; vrai si les aides a l'ecran doivent changer.
static func note_device(event: InputEvent) -> bool:
	var before := device_key()
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		using_gamepad = true
		_use_pad(event.device)
	elif event is InputEventKey:
		using_gamepad = false
	return device_key() != before

static func device_key() -> String:
	return pad_style if using_gamepad else "keyboard"

static func _use_pad(device: int) -> void:
	pad_device = device
	pad_style = style_of(Input.get_joy_name(device))

static func style_of(joy_name: String) -> String:
	var lower := joy_name.to_lower()
	for hint in PLAYSTATION_HINTS:
		if hint in lower:
			return "playstation"
	for hint in NINTENDO_HINTS:
		if hint in lower:
			return "nintendo"
	return "xbox"

# Vibration de la manette, proportionnelle a la secousse (0 a 1) ; seulement si on joue a la manette.
static func rumble(amount: float) -> void:
	if not using_gamepad or amount < RUMBLE_MIN or not Settings.enabled("vibration"):
		return
	amount = clampf(amount, 0.0, 1.0)
	Input.start_joy_vibration(pad_device, amount, amount * amount, RUMBLE_TIME + amount * RUMBLE_TIME_PER_TRAUMA)

static func move_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

static func key_name(action: String) -> String:
	var code: Key = keys[action]
	if KEY_NAMES.has(code):
		return KEY_NAMES[code]
	if DisplayServer.get_name() == "headless":  # pas de disposition clavier (tests)
		return OS.get_keycode_string(code)
	# Lettre ecrite sur la touche avec la disposition du joueur (Z en AZERTY pour KEY_W).
	return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code))

static func pad_name(action: String) -> String:
	return button_name(pads[action])

static func button_name(button: int) -> String:
	var styled: Dictionary = PAD_STYLE_NAMES.get(pad_style, {})
	return styled.get(button, PAD_NAMES.get(button, "Bouton %d" % button))

# Nom de la touche (ou du bouton, si on joue a la manette) ; "move" = les quatre directions.
static func name_of(action: String) -> String:
	if action == "move":
		if using_gamepad:
			return "Stick"
		return "".join(["move_up", "move_left", "move_down", "move_right"].map(key_name))
	return pad_name(action) if using_gamepad else key_name(action)

# Ligne d'aide : "ZQSD : deplacement  |  J : attaque ..."
static func help(actions: Array) -> String:
	return "  |  ".join(actions.map(func(a): return "%s : %s" % [name_of(a), HELP[a]]))
