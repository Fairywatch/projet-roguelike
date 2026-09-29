class_name Towers
extends RefCounted

# Les tours du jeu : chaque tour est une nuit du reveur (GDD section 5-6). La tour N+1 se
# debloque en terminant la tour N. Ajouter une nuit = ajouter une ligne.
#   floors : nombre d'etages ; difficulty : ajoute a GameState.difficulty() ;
#   nightmare_chance : part d'etages "cauchemar" (palette sombre) ; reward : pieces en fin de nuit.
# ponytail: tours provisoires, a remplacer par le vrai contenu (histoire, mobs, biomes propres).
const LIST := [
	{"id": "nuit_calme", "name": "Nuit calme", "desc": "Un sommeil paisible... ou presque.",
		"floors": 8, "difficulty": 0.0, "nightmare_chance": 0.2, "reward": 20},
	{"id": "nuit_agitee", "name": "Nuit agitee", "desc": "Le reveur se retourne sans cesse.",
		"floors": 10, "difficulty": 0.3, "nightmare_chance": 0.5, "reward": 40},
	{"id": "nuit_de_terreur", "name": "Nuit de terreur", "desc": "Les peurs les plus profondes remontent.",
		"floors": 12, "difficulty": 0.6, "nightmare_chance": 0.85, "reward": 80},
]

static func get_tower(index: int) -> Dictionary:
	return LIST[clampi(index, 0, LIST.size() - 1)]
