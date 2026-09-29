class_name Towers
extends RefCounted

# Les 7 nuits de la semaine du reveur (GDD section 5-6). Chaque jour, la semaine se degrade
# un peu plus sur le plan des emotions : la nuit est plus longue, plus dure et plus cauchemardesque.
# Une nuit se debloque en terminant celle de la veille. Ajouter ou modifier une nuit = cette table.
#   floors : nombre d'etages ; difficulty : ajoute a GameState.difficulty() ;
#   nightmare_chance : part d'etages "cauchemar" ; reward : pieces en fin de nuit.
# Le sprite de chaque tour (assets/sprites/hub/tower_<id>.png) vient de tools/gen_pixel_art.py.
const LIST := [
	{"id": "lundi", "name": "Lundi", "emotion": "Fatigue",
		"desc": "La semaine recommence. Le reveur traine des pieds.",
		"floors": 6, "difficulty": 0.0, "nightmare_chance": 0.1, "reward": 15},
	{"id": "mardi", "name": "Mardi", "emotion": "Stress",
		"desc": "Les choses a faire s'empilent plus vite qu'elles ne se font.",
		"floors": 7, "difficulty": 0.15, "nightmare_chance": 0.2, "reward": 25},
	{"id": "mercredi", "name": "Mercredi", "emotion": "Doute",
		"desc": "Et si rien de tout ca n'avait de sens ?",
		"floors": 8, "difficulty": 0.3, "nightmare_chance": 0.35, "reward": 35},
	{"id": "jeudi", "name": "Jeudi", "emotion": "Frustration",
		"desc": "Rien ne se passe comme prevu, la colere monte.",
		"floors": 9, "difficulty": 0.45, "nightmare_chance": 0.5, "reward": 50},
	{"id": "vendredi", "name": "Vendredi", "emotion": "Epuisement",
		"desc": "Plus d'energie, plus de patience, juste tenir.",
		"floors": 10, "difficulty": 0.6, "nightmare_chance": 0.65, "reward": 65},
	{"id": "samedi", "name": "Samedi", "emotion": "Solitude",
		"desc": "Le temps libre est la, mais personne pour le partager.",
		"floors": 11, "difficulty": 0.75, "nightmare_chance": 0.8, "reward": 80},
	{"id": "dimanche", "name": "Dimanche", "emotion": "Angoisse",
		"desc": "La semaine suivante approche, et avec elle toutes les peurs.",
		"floors": 12, "difficulty": 0.9, "nightmare_chance": 0.95, "reward": 120},
]

static func get_tower(index: int) -> Dictionary:
	return LIST[clampi(index, 0, LIST.size() - 1)]

static func title(index: int) -> String:
	var tower := get_tower(index)
	return "%s - %s" % [tower["name"], tower["emotion"]]
