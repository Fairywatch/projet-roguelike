class_name Items
extends RefCounted

# Objets passifs : cumulables sans limite. Chaque passif est decrit par ses effets ("mods"),
# additionnes pour tous les exemplaires possedes (voir GameState.mod()). Ajouter un passif =
# ajouter une ligne ici, sans code, tant qu'il n'utilise que des effets existants :
#   max_hp, damage (entiers) ; speed, dash_cooldown, attack_cooldown, dash_length (fractions,
#   ex. 0.1 = +10 %) ; reach, knockback (pixels) ; heal_on_hit, heal_on_kill, crit, evasion
#   (chances) ; iframes (secondes) ; extra_lives, shield, thorns, active_recharge (entiers) ;
#   slow_on_hit, dash_trail (drapeaux) ; enemy_hp, enemy_speed, enemy_cooldown, telegraph,
#   drop_chance, encounter_rate (fractions).
# Chaque objet a aussi un tier (S, A, B, C : sa puissance) et une icone (tools/gen_items.py).
enum { COMMUN, RARE, LEGENDAIRE }
const RARITY_NAMES := ["Commun", "Rare", "Légendaire"]
const RARITY_COLORS := [Color(0.85, 0.88, 1.0), Color(0.45, 0.75, 1.0), Color(1.0, 0.8, 0.3)]
# Tier = puissance de l'objet (la rarete, elle, dit s'il est frequent). Couleurs facon "tier list".
const TIER_COLORS := {"S": Color(1.0, 0.36, 0.4), "A": Color(1.0, 0.64, 0.26), "B": Color(1.0, 0.9, 0.36), "C": Color(0.55, 0.86, 0.52)}
const ICON_DIR := "res://assets/sprites/items/"

const PASSIVES := [
	{"id": "plume_de_reve", "name": "Plume de rêve", "desc": "+1 PV max", "mods": {"max_hp": 1}, "rarity": COMMUN, "tier": "B"},
	{"id": "sablier_fele", "name": "Sablier fêlé", "desc": "Dash recharge 15 % plus vite", "mods": {"dash_cooldown": -0.15}, "rarity": COMMUN, "tier": "B"},
	{"id": "larme_de_crocodile", "name": "Larme de crocodile", "desc": "15 % de chance de soin en frappant", "mods": {"heal_on_hit": 0.15}, "rarity": RARE, "tier": "A"},
	{"id": "coup_de_barre", "name": "Coup de barre", "desc": "Le dash laisse une traînée blessante", "mods": {"dash_trail": 1}, "rarity": RARE, "tier": "B"},
	{"id": "grelot_du_sommeil", "name": "Grelot du sommeil", "desc": "Les ennemis touchés sont ralentis", "mods": {"slow_on_hit": 1}, "rarity": COMMUN, "tier": "C"},
	{"id": "oeil_qui_traine", "name": "Œil qui traîne", "desc": "Télégraphes ennemis 25 % plus longs", "mods": {"telegraph": 0.25}, "rarity": COMMUN, "tier": "C"},
	{"id": "croque_mort_au_chomage", "name": "Croque-mort au chômage", "desc": "Survit à un coup fatal par combat", "mods": {"extra_lives": 1}, "rarity": LEGENDAIRE, "tier": "S"},
	{"id": "pacte_dombre", "name": "Pacte d'ombre", "desc": "+1 dégât, -1 PV max", "mods": {"damage": 1, "max_hp": -1}, "rarity": RARE, "tier": "B"},
	{"id": "chaussons_de_velours", "name": "Chaussons de velours", "desc": "+12 % de vitesse", "mods": {"speed": 0.12}, "rarity": COMMUN, "tier": "B"},
	{"id": "oreiller_de_plumes", "name": "Oreiller de plumes", "desc": "+2 PV max, -8 % de vitesse", "mods": {"max_hp": 2, "speed": -0.08}, "rarity": RARE, "tier": "A"},
	{"id": "doudou_protecteur", "name": "Doudou protecteur", "desc": "Bloque le premier coup de chaque combat", "mods": {"shield": 1}, "rarity": RARE, "tier": "A"},
	{"id": "cafe_serre", "name": "Café serré", "desc": "Attaque 20 % plus rapide", "mods": {"attack_cooldown": -0.2}, "rarity": RARE, "tier": "A"},
	{"id": "bras_de_morphee", "name": "Bras de Morphée", "desc": "Attaque plus longue", "mods": {"reach": 10}, "rarity": COMMUN, "tier": "C"},
	{"id": "coup_de_foudre", "name": "Coup de foudre", "desc": "15 % de coups critiques (dégâts x2)", "mods": {"crit": 0.15}, "rarity": RARE, "tier": "A"},
	{"id": "mouton_compteur", "name": "Mouton compteur", "desc": "+15 % de chance de butin", "mods": {"drop_chance": 0.15}, "rarity": COMMUN, "tier": "C"},
	{"id": "veilleuse", "name": "Veilleuse", "desc": "25 % de rencontres en moins", "mods": {"encounter_rate": -0.25}, "rarity": COMMUN, "tier": "C"},
	{"id": "ronflement_sonore", "name": "Ronflement sonore", "desc": "Les coups repoussent les ennemis", "mods": {"knockback": 22}, "rarity": COMMUN, "tier": "C"},
	{"id": "somnambule", "name": "Somnambule", "desc": "Dash 30 % plus long", "mods": {"dash_length": 0.3}, "rarity": COMMUN, "tier": "C"},
	{"id": "couverture_lestee", "name": "Couverture lestée", "desc": "Invincibilité plus longue après un coup", "mods": {"iframes": 0.4}, "rarity": COMMUN, "tier": "B"},
	{"id": "marchand_de_sable", "name": "Marchand de sable", "desc": "Ennemis 15 % moins résistants", "mods": {"enemy_hp": -0.15}, "rarity": LEGENDAIRE, "tier": "A"},
	{"id": "berceuse_inversee", "name": "Berceuse inversée", "desc": "Ennemis 10 % plus lents", "mods": {"enemy_speed": -0.1}, "rarity": RARE, "tier": "B"},
	{"id": "reve_lucide", "name": "Rêve lucide", "desc": "25 % de chance de soin en tuant", "mods": {"heal_on_kill": 0.25}, "rarity": RARE, "tier": "A"},
	{"id": "cauchemar_apprivoise", "name": "Cauchemar apprivoisé", "desc": "+1 dégât, ennemis 10 % plus rapides", "mods": {"damage": 1, "enemy_speed": 0.1}, "rarity": RARE, "tier": "A"},
	{"id": "pile_rechargeable", "name": "Pile rechargeable", "desc": "L'objet actif regagne une charge de plus", "mods": {"active_recharge": 1}, "rarity": RARE, "tier": "B"},
	{"id": "tisane_de_camomille", "name": "Tisane de camomille", "desc": "+1 PV max, 5 % de soin en frappant", "mods": {"max_hp": 1, "heal_on_hit": 0.05}, "rarity": COMMUN, "tier": "A"},
	{"id": "poussiere_detoile", "name": "Poussière d'étoile", "desc": "+10 % de critiques, +5 % de vitesse", "mods": {"crit": 0.1, "speed": 0.05}, "rarity": COMMUN, "tier": "B"},
	{"id": "pyjama_en_soie", "name": "Pyjama en soie", "desc": "+5 % de vitesse, dash 10 % plus rapide", "mods": {"speed": 0.05, "dash_cooldown": -0.1}, "rarity": COMMUN, "tier": "B"},
	{"id": "pyjama_a_epines", "name": "Pyjama à épines", "desc": "Blesse les ennemis proches quand on est touché", "mods": {"thorns": 1}, "rarity": RARE, "tier": "B"},
	{"id": "miroir_de_poche", "name": "Miroir de poche", "desc": "15 % de chance d'esquiver un coup", "mods": {"evasion": 0.15}, "rarity": RARE, "tier": "A"},
	{"id": "attrape_reves", "name": "Attrape-rêves", "desc": "8 % d'esquive, +10 % de butin", "mods": {"evasion": 0.08, "drop_chance": 0.1}, "rarity": COMMUN, "tier": "B"},
	{"id": "billes_perdues", "name": "Billes perdues", "desc": "Attaque 10 % plus rapide et plus longue", "mods": {"attack_cooldown": -0.1, "reach": 5}, "rarity": COMMUN, "tier": "B"},
	{"id": "coeur_de_lune", "name": "Cœur de lune", "desc": "+2 PV max, +1 dégât", "mods": {"max_hp": 2, "damage": 1}, "rarity": LEGENDAIRE, "tier": "S"},
	{"id": "reve_eveille", "name": "Rêve éveillé", "desc": "+20 % de vitesse, dash 25 % plus rapide, 10 % d'esquive", "mods": {"speed": 0.2, "dash_cooldown": -0.25, "evasion": 0.1}, "rarity": LEGENDAIRE, "tier": "S"},
	{"id": "etoile_du_berger", "name": "Étoile du berger", "desc": "25 % de critiques, attaque bien plus longue", "mods": {"crit": 0.25, "reach": 15}, "rarity": LEGENDAIRE, "tier": "S"},
	{"id": "sommeil_de_plomb", "name": "Sommeil de plomb", "desc": "Bloque les deux premiers coups de chaque combat", "mods": {"shield": 2}, "rarity": LEGENDAIRE, "tier": "S"},
	{"id": "montre_a_gousset", "name": "Montre à gousset", "desc": "Ennemis attaquent 15 % moins souvent", "mods": {"enemy_cooldown": 0.15}, "rarity": RARE, "tier": "B"},
]

# Objets actifs : un seul a la fois, utilise avec E en combat.
const ACTIVES := [
	{"id": "sept_ans_de_malheur", "name": "Sept Ans de Malheur", "desc": "Invincibilité brève + leurre", "rarity": RARE, "tier": "B"},
	{"id": "mouchoir_usage", "name": "Mouchoir usagé", "desc": "Soigne 1 PV", "rarity": COMMUN, "tier": "B"},
	{"id": "reveil_strident", "name": "Réveil strident", "desc": "Étourdit les ennemis proches", "rarity": COMMUN, "tier": "B"},
	{"id": "oreiller_volant", "name": "Oreiller volant", "desc": "2 dégâts à tous les ennemis proches", "rarity": RARE, "tier": "A"},
	{"id": "tasse_de_cafe", "name": "Tasse de café", "desc": "Dash recharge et +50 % de vitesse 4 s", "rarity": COMMUN, "tier": "C"},
]

static func rarity(id: String) -> int:
	return find(id).get("rarity", COMMUN)

static func rarity_color(id: String) -> Color:
	return RARITY_COLORS[rarity(id)]

static func tier(id: String) -> String:
	return find(id).get("tier", "C")

static func tier_color(id: String) -> Color:
	return TIER_COLORS[tier(id)]

# Icone propre a l'objet (tools/gen_items.py).
static func icon(id: String) -> Texture2D:
	return load(ICON_DIR + id + ".png")

static func find_passive(id: String) -> Dictionary:
	for item in PASSIVES:
		if item["id"] == id:
			return item
	return {}

static func find_active(id: String) -> Dictionary:
	for item in ACTIVES:
		if item["id"] == id:
			return item
	return {}

static func is_active(id: String) -> bool:
	return not find_active(id).is_empty()

static func find(id: String) -> Dictionary:
	var passive := find_passive(id)
	if not passive.is_empty():
		return passive
	return find_active(id)
