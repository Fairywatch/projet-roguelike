class_name Items
extends RefCounted

const PASSIVES := [
	{"id": "plume_de_reve", "name": "Plume de reve", "desc": "+1 PV max"},
	{"id": "sablier_fele", "name": "Sablier fele", "desc": "Dash se recharge plus vite"},
	{"id": "larme_de_crocodile", "name": "Larme de crocodile", "desc": "Chance de soin en touchant un ennemi"},
	{"id": "coup_de_barre", "name": "Coup de barre", "desc": "Le dash laisse une trainee blessante"},
	{"id": "grelot_du_sommeil", "name": "Grelot du sommeil", "desc": "Les ennemis touches sont ralentis"},
	{"id": "oeil_qui_traine", "name": "Oeil qui traine", "desc": "Les telegraphes ennemis durent plus longtemps"},
	{"id": "croque_mort_au_chomage", "name": "Croque-mort au chomage", "desc": "Survit a un coup fatal (par combat)"},
	{"id": "pacte_dombre", "name": "Pacte d'ombre", "desc": "+Degats, -1 PV max"},
]

const ACTIVES := [
	{"id": "sept_ans_de_malheur", "name": "Sept Ans de Malheur", "desc": "Invincibilite bref + leurre"},
	{"id": "mouchoir_usage", "name": "Mouchoir usage", "desc": "Soigne 1 PV (charges limitees)"},
	{"id": "reveil_strident", "name": "Reveil strident", "desc": "Etourdit les ennemis proches"},
]

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

static func find(id: String) -> Dictionary:
	var passive := find_passive(id)
	if not passive.is_empty():
		return passive
	return find_active(id)
