# Lancer : godot --headless --path . --script res://tests/test_samedi.gd
# Bestiaire du samedi (Solitude) : verification commune + mecaniques propres.
extends "res://tests/bestiary_check.gd"

func _init() -> void:
	night = "samedi"

func _zones_near(at: Vector2) -> int:
	return current_scene.get_children().filter(func(n): return n.get("kind") == "damage" and n.global_position.distance_to(at) < 5.0).size()

func check_specific(a: Node) -> void:
	# Echo : repete l'attaque du joueur la ou il a frappe.
	var echo = spawn(a, "samedi/echo")
	await process_frame
	var at := Vector2(300, 300)
	a.player.attacked.emit(at)
	assert(_zones_near(at) == 1)
	await clear_mobs()

	# Telephone Muet : triple degats juste apres la sonnerie.
	var phone = spawn(a, "samedi/telephone")
	await process_frame
	var hp: int = phone.hp
	phone.take_hit(1)
	assert(phone.hp == hp - 1)
	phone.answer_window = 1.0
	phone.take_hit(1)
	assert(phone.hp == hp - 4)
	await clear_mobs()

	# Lettre (variante) : frappee, elle se plie en 3 avions de papier qui suivent le joueur.
	var letter = spawn(a, "samedi/lettre", {"alt": true})
	await process_frame
	var before: int = current_scene.get_children().filter(func(n): return n.get("homing") != null and n.homing > 0.0).size()
	letter.take_hit(1)
	var planes: int = current_scene.get_children().filter(func(n): return n.get("homing") != null and n.homing > 0.0).size()
	assert(planes - before == 3)
	await clear_mobs()

	# L'Absence : la phase 3 eteint l'arene, sa mort la rallume.
	var absence = spawn(a, "samedi/absence")
	await process_frame
	var ambient: CanvasModulate = current_scene.get_children().filter(func(n): return n is CanvasModulate)[0]
	var color := ambient.color
	absence.take_hit(int(absence.max_hp * 0.7))
	assert(absence.phase == 3 and ambient.color != color)
	absence.take_hit(999)
	assert(ambient.color == color)
