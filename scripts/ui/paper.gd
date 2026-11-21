class_name Paper
extends RefCounted

# Interface "carnet de reves" : les panneaux de papier (menus, HUD, messages) portent ce theme, qui
# passe leurs textes a l'encre. Les textes poses directement sur le jeu gardent le theme du projet
# (clairs, cernes d'encre). Voir tools/gen_theme.py.

const THEME := preload("res://assets/ui/paper_theme.tres")
const INK := Color(0.17, 0.13, 0.25)
const INK_SOFT := Color(0.36, 0.31, 0.47)
const RED_PENCIL := Color(0.78, 0.28, 0.32)
const BLUE_PENCIL := Color(0.32, 0.44, 0.73)

static func apply(control: Control) -> Control:
	control.theme = THEME
	return control
