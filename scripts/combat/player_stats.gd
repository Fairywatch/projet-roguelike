class_name PlayerStats
extends RefCounted

# Statistiques du joueur calculees a partir de ses objets (GameState.mod()). Une seule source :
# le joueur en combat (PlayerCombat.apply_items), la fiche de stats de l'inventaire et l'Autre
# Soi, qui copie le joueur, lisent tous les memes chiffres.

const SPEED := 200.0
const DASH_SPEED := 600.0
const DASH_DURATION := 0.18
const DASH_COOLDOWN := 0.6
const ATTACK_COOLDOWN := 0.35
const ATTACK_REACH := 30.0
const HURT_INVINCIBILITY := 0.8
# Rafale de plumes (attaque speciale) : 3 plumes en eventail, toutes les 3 s.
const FEATHERS := 3
const SPECIAL_COOLDOWN := 3.0
# Ensemble : Plumier + Plume de paon = Tempete de plumes (la rafale part dans toutes les directions).
const STORM_SET := ["plumier", "plume_de_paon"]
# Styles d'attaque (objets avec "style", voir Items) : un seul a la fois, le dernier pris.
#   cooldown : multiplie le temps entre deux attaques ; reach : multiplie la portee.
# Equilibrage, sur une cible (coup de base : enchainement 1 + 1 + 2 degats en ~1,3 s, ~3,1 / s) :
#   estoc ~2,7 / s mais deux fois plus loin et a travers toute une ligne ; toupie ~2,5 / s mais
#   tout autour ; fronde ~2,3 / s mais de loin ; maillet ~2,6 / s en coups lourds qui assomment.
const STYLES := {
	"estoc": {"name": "Estoc", "cooldown": 1.15, "reach": 1.9},
	"toupie": {"name": "Toupie", "cooldown": 1.25, "reach": 0.9},
	"fronde": {"name": "Fronde", "cooldown": 1.35, "reach": 1.0},
	"maillet": {"name": "Maillet", "cooldown": 2.2, "reach": 1.25},
}
const MAX_GUARD_SHEEP := 4
# Plafonds : un empilement d'objets ne doit pas rendre intouchable.
const MIN_COOLDOWN_MULT := 0.3
const MIN_SPEED_MULT := 0.5
const MAX_EVASION := 0.5
# Soin en frappant / en tuant : 15 % au plus chacun, quels que soient les objets cumules (au-dela,
# se soigner devient trop facile).
const MAX_HEAL_ON_HIT := 0.15
const MAX_HEAL_ON_KILL := 0.15
const MAX_SHIELD := 3
const MAX_EXTRA_LIVES := 2

static func damage() -> int:
	return 1 + int(GameState.mod("damage"))

static func move_speed() -> float:
	return SPEED * maxf(MIN_SPEED_MULT, 1.0 + GameState.mod("speed"))

static func dash_cooldown() -> float:
	return DASH_COOLDOWN * maxf(MIN_COOLDOWN_MULT, 1.0 + GameState.mod("dash_cooldown"))

static func attack_cooldown() -> float:
	return ATTACK_COOLDOWN * maxf(MIN_COOLDOWN_MULT, 1.0 + GameState.mod("attack_cooldown")) * _style_value("cooldown")

# Style d'attaque actif ("" : le coup de base) : le dernier objet de style pris.
static func style() -> String:
	var ids: Array = GameState.passive_items.keys()
	for i in range(ids.size() - 1, -1, -1):
		var item := Items.find_passive(ids[i])
		if item.has("style"):
			return item["style"]
	return ""

static func _style_value(key: String) -> float:
	var current := style()
	return STYLES[current][key] if current != "" else 1.0

static func style_reach() -> float:
	return _style_value("reach")

static func dash_hits() -> bool:
	return GameState.mod("dash_hits") > 0.0

static func guard_sheep() -> int:
	return mini(MAX_GUARD_SHEEP, int(GameState.mod("guard_sheep")))

static func dash_duration() -> float:
	return DASH_DURATION * (1.0 + GameState.mod("dash_length"))

static func reach() -> float:
	return ATTACK_REACH + GameState.mod("reach")

static func iframes() -> float:
	return HURT_INVINCIBILITY + GameState.mod("iframes")

static func crit() -> float:
	return clampf(GameState.mod("crit"), 0.0, 1.0)

static func evasion() -> float:
	return minf(MAX_EVASION, GameState.mod("evasion"))

static func heal_on_hit() -> float:
	return minf(MAX_HEAL_ON_HIT, GameState.mod("heal_on_hit"))

static func heal_on_kill() -> float:
	return minf(MAX_HEAL_ON_KILL, GameState.mod("heal_on_kill"))

static func shield() -> int:
	return mini(MAX_SHIELD, int(GameState.mod("shield")))

static func extra_lives() -> int:
	return mini(MAX_EXTRA_LIVES, int(GameState.mod("extra_lives")))

static func thorns() -> int:
	return int(GameState.mod("thorns"))

static func knockback() -> float:
	return GameState.mod("knockback")

static func feathers() -> int:
	return FEATHERS + int(GameState.mod("feathers"))

static func special_cooldown() -> float:
	return SPECIAL_COOLDOWN * maxf(MIN_COOLDOWN_MULT, 1.0 + GameState.mod("special_cooldown"))

static func feather_pierce() -> bool:
	return GameState.mod("feather_pierce") > 0.0

static func feather_storm() -> bool:
	return STORM_SET.all(func(id): return GameState.passive_items.has(id))

# Fiche de stats : [nom, valeur] ; les effets que le joueur n'a pas ne sont pas listes.
static func lines() -> Array:
	var out := [
		["PV", "%d / %d  (max %d)" % [GameState.current_hp(), GameState.max_hp(), GameState.MAX_HP_CAP]],
		["Dégâts", ("%d  (chaque coup : %d)" if style() == "maillet" else "%d  (3e coup : %d)") % [damage(), damage() * 2]],
		["Attaques / s", "%.1f" % (1.0 / attack_cooldown())],
		["Portée", "%d" % roundi(reach() * style_reach())],
		["Vitesse", _percent(move_speed() / SPEED - 1.0, true)],
		["Dash", "recharge %.2f s" % dash_cooldown()],
		["Rafale", "%d plumes, recharge %.1f s" % [feathers(), special_cooldown()]],
	]
	if style() != "":
		out.insert(1, ["Style", STYLES[style()]["name"]])
	if dash_hits():
		out.append(["Dash", "blesse les ennemis touchés"])
	if guard_sheep() > 0:
		out.append(["Moutons gardiens", "%d" % guard_sheep()])
	if feather_pierce():
		out.append(["Plumes", "traversent les ennemis"])
	if feather_storm():
		out.append(["Tempête de plumes", "rafale tout autour"])
	if GameState.mod("finisher_volley") > 0.0:
		out.append(["3e coup", "lance une rafale"])
	var optional := [
		["Critiques (x2)", crit(), true], ["Esquive", evasion(), true], ["Soin en frappant", heal_on_hit(), true],
		["Soin en tuant", heal_on_kill(), true], ["Coups bloqués / combat", shield(), false],
		["Survies / combat", extra_lives(), false], ["Épines", thorns(), false],
		["Invincibilité après un coup", iframes() - HURT_INVINCIBILITY, false],
		["Dash plus long", GameState.mod("dash_length"), true], ["Recul des ennemis", knockback(), false],
		["PV ennemis", GameState.mod("enemy_hp"), true], ["Vitesse ennemis", GameState.mod("enemy_speed"), true],
		["Cadence ennemis", -GameState.mod("enemy_cooldown"), true], ["Télégraphes", GameState.mod("telegraph"), true],
		["Butin", GameState.mod("drop_chance"), true], ["Rencontres", GameState.mod("encounter_rate"), true],
		["Ennemis en plus", GameState.mod("enemy_count"), false], ["Dégâts reçus en plus", GameState.mod("enemy_damage"), false],
	]
	for entry in optional:
		if absf(entry[1]) > 0.001:
			out.append([entry[0], _percent(entry[1], true) if entry[2] else ("+%s" % _number(entry[1]))])
	if GameState.mod("no_loot") > 0.0:
		out.append(["Butin", "aucun"])
	out.append(["Butin de combat (étage)", "%d / %d" % [GameState.combat_items_left(), GameState.COMBAT_ITEMS_PER_FLOOR]])
	return out

static func _percent(value: float, signed: bool) -> String:
	var text := "%d %%" % roundi(value * 100.0)
	return ("+" + text) if signed and value > 0.0 else text

static func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
