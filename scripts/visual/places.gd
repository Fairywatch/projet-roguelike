class_name Places
extends RefCounted

# Lieux des nuits (docs/nuits.md) : chaque nuit a un lieu par famille d'etage, avec ses tuiles
# (assets/sprites/tiles/<nuit>/), ses decors (assets/sprites/decor/<nuit>/<famille>/), sa lumiere
# et ses particules, plus une regle d'etage (scripts/exploration/rules/<nuit>.gd).
# Les decors interactifs gardent leur effet, donc leur nom technique (etoile soigne, lune guide,
# horloge met les rencontres en pause, bulle eclate ; bougie s'allume, champignon lance un combat,
# cristal peut contenir un objet), mais changent d'apparence et de nom affiche.
# Une nuit absente de la table garde les visuels d'origine.

const INTERACTIVE := {
	"paradoxal": ["etoile", "lune", "horloge", "bulle"],
	"profond": ["bougie", "champignon", "cristal"],
}
# Noms affiches d'origine (nuits sans lieu propre).
const DEFAULT_LABELS := {
	"etoile": "Étoile filante", "lune": "La lune", "horloge": "L'horloge",
	"champignon": "Des spores t'endorment plus profondément...", "cristal": "Le cristal se brise",
}
# labels : nom du soin, du guide et de la pause ; phrase du decor qui lance un combat ; debut de
# phrase du decor a objet ("... et libere <objet> !").

# decor : nom -> options ("float" : flotte, "push" : se pousse).
const LIST := {
	"lundi": {
		"paradoxal": {
			"name": "la Mer de coton",
			"ambient": Color(0.86, 0.83, 0.97),
			"particles": [Color(1, 1, 1), Color(0.88, 0.84, 1)],
			"decor": {"plume": ["float"], "rideau": [], "lampe": ["push"]},
			"labels": {"etoile": "Veilleuse étoile", "lune": "La lanterne de rêve", "horloge": "Le réveil endormi"},
		},
		"profond": {
			"name": "la Brume de sommeil",
			"ambient": Color(0.44, 0.48, 0.58),
			"particles": [Color(0.7, 0.74, 0.82, 0.5)],
			"decor": {"draps": ["float"], "fauteuil": []},
			"labels": {"champignon": "Le tas de draps se met à respirer... et à bouger !", "cristal": "Le coffre à jouets s'ouvre"},
		},
	},
	"mardi": {
		"paradoxal": {
			"name": "les Engrenages",
			"ambient": Color(1.0, 0.93, 0.8),
			"particles": [Color(1, 0.85, 0.45), Color(1, 0.95, 0.75)],
			"decor": {"aiguille": [], "feuilles": ["float"], "rouage": ["push"]},
			"labels": {"etoile": "Étoile dorée", "lune": "La boussole", "horloge": "Le sablier retourné"},
		},
		"profond": {
			"name": "la Salle des pendules",
			"ambient": Color(0.5, 0.38, 0.38),
			"particles": [Color(0.8, 0.5, 0.45, 0.5)],
			"decor": {"balancier": ["float"], "papiers": [], "comtoise": []},
			"labels": {"champignon": "Le réveil se met à sonner !", "cristal": "Le tiroir se déverrouille"},
		},
	},
	"mercredi": {
		"paradoxal": {
			"name": "le Palais des reflets",
			"ambient": Color(0.9, 0.92, 1.0),
			"particles": [Color(1, 0.8, 0.95), Color(0.8, 0.95, 1), Color(1, 1, 0.85)],
			"decor": {"cadre": [], "statue": [], "escalier": []},
			"labels": {"etoile": "Reflet d'étoile", "lune": "Le fil d'Ariane", "horloge": "La pièce figée"},
		},
		"profond": {
			"name": "le Carrefour brumeux",
			"ambient": Color(0.44, 0.52, 0.5),
			"particles": [Color(0.7, 0.8, 0.76, 0.5)],
			"decor": {"panneau": [], "banc": []},
			"labels": {"champignon": "Le masque se relève... il n'est pas vide !", "cristal": "La valise s'ouvre"},
		},
	},
	"jeudi": {
		"paradoxal": {
			"name": "l'Usine à attendre",
			"ambient": Color(0.9, 0.92, 0.95),
			"particles": [Color(1, 0.6, 0.25), Color(0.85, 0.85, 0.9)],
			"decor": {"barriere": ["push"], "tampon": [], "tickets": []},
			"labels": {"etoile": "Ticket gagnant", "lune": "Le panneau SORTIE", "horloge": "Le feu rouge"},
		},
		"profond": {
			"name": "la Fournaise",
			"ambient": Color(0.56, 0.36, 0.32),
			"particles": [Color(1, 0.5, 0.2, 0.7), Color(1, 0.75, 0.3, 0.6)],
			"decor": {"tuyau": [], "chaudiere": []},
			"labels": {"champignon": "La cocotte siffle... et explose de colère !", "cristal": "Le coffre-fort cède"},
		},
	},
	"vendredi": {
		"paradoxal": {
			"name": "la Montagne de cartons",
			"ambient": Color(1.0, 0.86, 0.7),
			"particles": [Color(1, 0.85, 0.6), Color(0.9, 0.8, 0.7)],
			"decor": {"carton": ["push"], "sac": [], "pile": []},
			"labels": {"etoile": "Tasse de thé chaud", "lune": "Le phare de poche", "horloge": "Le banc"},
		},
		"profond": {
			"name": "les Mines de plomb",
			"ambient": Color(0.4, 0.42, 0.52),
			"particles": [Color(0.6, 0.62, 0.7, 0.5)],
			"decor": {"wagonnet": ["push"], "pioche": [], "gravats": []},
			"labels": {"champignon": "Le sac se met à bouger tout seul !", "cristal": "Le filon s'effrite"},
		},
	},
	"samedi": {
		"paradoxal": {
			"name": "la Salle de bal vide",
			"ambient": Color(0.82, 0.86, 1.0),
			"particles": [Color(0.85, 0.9, 1), Color(1, 0.95, 0.8)],
			"decor": {"chaise": ["push"], "guirlande": ["float"], "verre": []},
			"labels": {"etoile": "Lettre reçue", "lune": "Le phare lointain", "horloge": "La boîte à musique"},
		},
		"profond": {
			"name": "le Quai désert",
			"ambient": Color(0.36, 0.4, 0.52),
			"particles": [Color(0.6, 0.66, 0.78, 0.45)],
			"decor": {"bouee": [], "banc_vide": [], "lampadaire_eteint": []},
			"labels": {"champignon": "Le téléphone sonne... ce n'est pas pour toi.", "cristal": "La bouteille se brise"},
		},
	},
}

static func kind(family: int) -> String:
	return "paradoxal" if family == FloorGenerator.Family.PARADOXAL else "profond"

static func has_place(night: String) -> bool:
	return LIST.has(night)

static func place(night: String, family: int) -> Dictionary:
	return LIST.get(night, {}).get(kind(family), {})

# Decors a semer sur l'etage : les interactifs, puis les decors propres au lieu.
static func decor_names(night: String, family: int) -> Array:
	return INTERACTIVE[kind(family)] + place(night, family)["decor"].keys()

static func has_flag(night: String, family: int, decor_name: String, flag: String) -> bool:
	return flag in place(night, family).get("decor", {}).get(decor_name, [])

static func label(night: String, family: int, decor_name: String) -> String:
	return place(night, family).get("labels", {}).get(decor_name, DEFAULT_LABELS.get(decor_name, ""))

# Regle d'etage de la nuit (null si elle n'en a pas encore). Interface : variables map,
# floor_data, strength et INTRO ; au besoin on_decor(nom) sur la carte et, en statique,
# apply_combat(arene, force) dans l'arene.
static func rule_script(night: String) -> GDScript:
	var path := "res://scripts/exploration/rules/%s.gd" % night
	return load(path) if ResourceLoader.exists(path) else null

static func rule(night: String) -> Node:
	var script := rule_script(night)
	return script.new() if script else null
