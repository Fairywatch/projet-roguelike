class_name Bestiary
extends RefCounted

# Bestiaire par nuit (docs/bestiaire.md). Chaque creature est un script de
# scripts/combat/mobs/<nuit>/ qui etend BaseMob et construit son propre sprite.
# Une nuit absente de NIGHTS utilise encore les anciens monstres (en attendant sa production).

const MOBS_DIR := "res://scripts/combat/mobs/"
const NIGHTS := {
	"lundi": {
		"creatures": ["lundi/bailleur", "lundi/mouton", "lundi/veilleuse", "lundi/paupiere"],
		"bosses": ["lundi/grande_couette", "lundi/reveil_grincheux", "lundi/choeur_baillements"],
		"final": "lundi/porte_des_voix",
	},
	"mardi": {
		"creatures": ["mardi/trotteuse", "mardi/pile_devoirs", "mardi/stylo_rouge", "mardi/battement"],
		"bosses": ["mardi/tableau_noir", "mardi/horloge_classe", "mardi/cloche"],
		"final": "mardi/examen",
	},
	"mercredi": {
		"creatures": ["mercredi/reflet", "mercredi/pile_ou_face", "mercredi/carrefour", "mercredi/masque"],
		"bosses": ["mercredi/miroir_brise", "mercredi/labyrinthe", "mercredi/deux_voies"],
		"final": "mercredi/autre_soi",
	},
	"jeudi": {
		"creatures": ["jeudi/grogne", "jeudi/porte_close", "jeudi/ressort", "jeudi/cocotte"],
		"bosses": ["jeudi/patron", "jeudi/tapis_roulant", "jeudi/mur"],
		"final": "jeudi/colere",
	},
	"vendredi": {
		"creatures": ["vendredi/fardeau", "vendredi/sangsue", "vendredi/soignant", "vendredi/bougie_fondue"],
		"bosses": ["vendredi/atlas", "vendredi/nid", "vendredi/balancier"],
		"final": "vendredi/poids_du_monde",
	},
	"samedi": {
		"creatures": ["samedi/silhouette", "samedi/echo", "samedi/chaise", "samedi/lettre"],
		"bosses": ["samedi/maison_vide", "samedi/telephone", "samedi/foule_lointaine"],
		"final": "samedi/absence",
	},
}
const ELITE_CHANCE := 0.1
const ALT_CHANCE := 0.5
# Versions d'un boss tire au hasard : 3 boss x 4 versions = 12 combinaisons par nuit.
const BOSS_VERSIONS := ["normal", "cauchemar", "elite", "comportement"]

static func has_night(night_id: String) -> bool:
	return NIGHTS.has(night_id)

static func make(path: String) -> BaseMob:
	return load(MOBS_DIR + path + ".gd").new()

# Ennemi ordinaire : cauchemar sur les etages cauchemar, elite et variante de comportement au hasard.
static func creature(night_id: String, nightmare_floor: bool) -> BaseMob:
	var mob := make(NIGHTS[night_id]["creatures"].pick_random())
	mob.nightmare = nightmare_floor
	mob.elite = randf() < ELITE_CHANCE
	mob.alt = randf() < ALT_CHANCE
	return mob

# Boss de portail : une combinaison boss + version jamais tiree dans la nuit en cours
# (history, garde dans la sauvegarde), en preferant la version cauchemar sur un etage cauchemar.
static func boss(night_id: String, nightmare_floor: bool, history: Array) -> BaseMob:
	var combos := _unused_combos(night_id, history)
	if combos.is_empty():
		history.clear()
		combos = _unused_combos(night_id, history)
	var preferred := combos.filter(func(key: String): return key.ends_with("|cauchemar") == nightmare_floor)
	var key: String = (preferred if not preferred.is_empty() else combos).pick_random()
	history.append(key)
	var parts := key.split("|")
	var mob := make(parts[0])
	mob.nightmare = parts[1] == "cauchemar"
	mob.elite = parts[1] == "elite"
	mob.alt = parts[1] == "comportement"
	return mob

static func _unused_combos(night_id: String, history: Array) -> Array:
	var combos := []
	for path in NIGHTS[night_id]["bosses"]:
		for version in BOSS_VERSIONS:
			var key: String = path + "|" + version
			if key not in history:
				combos.append(key)
	return combos

static func final_boss(night_id: String) -> BaseMob:
	return make(NIGHTS[night_id]["final"])
