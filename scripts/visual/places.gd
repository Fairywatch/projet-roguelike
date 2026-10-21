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
const DEFAULT_LABELS := {"etoile": "Étoile filante", "lune": "La lune", "horloge": "L'horloge"}

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
			"labels": {},
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

# Regle d'etage de la nuit (null si elle n'en a pas encore).
static func rule(night: String) -> Node:
	var path := "res://scripts/exploration/rules/%s.gd" % night
	return load(path).new() if ResourceLoader.exists(path) else null
