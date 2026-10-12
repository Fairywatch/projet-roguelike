# Lancer : godot --headless --path . --script res://tests/test_vendredi.gd
# Bestiaire du vendredi (Epuisement) : verification commune + mecaniques propres.
extends "res://tests/bestiary_check.gd"

func _init() -> void:
	night = "vendredi"

func _count(mob_name: String) -> int:
	return get_nodes_in_group("mobs").filter(func(m): return m.display_name == mob_name and m.state != m.State.DEAD).size()

func check_specific(a: Node) -> void:
	# Fardeau : chaque coup fait tomber un passager.
	var burden = spawn(a, "vendredi/fardeau")
	await process_frame
	burden.take_hit(1)
	for i in 3:
		await process_frame
	assert(_count("Passager") == 1)
	await clear_mobs()

	# Sangsue : accrochee, elle ralentit le joueur ; un dash la decroche.
	var leech = spawn(a, "vendredi/sangsue")
	await process_frame
	leech.host = a.player
	await physics_frame
	await physics_frame
	assert(a.player.slow_timer > 0.0)
	a.player._start_dash()
	await physics_frame
	await physics_frame
	assert(leech.host == null)
	await clear_mobs()

	# Soignant : soigne les ennemis proches.
	var healer = spawn(a, "vendredi/soignant")
	var hurt = spawn(a, "vendredi/fardeau")
	await process_frame
	hurt.global_position = healer.global_position + Vector2(40, 0)
	hurt.hp = 1
	healer.heal_timer = 0.0
	await physics_frame
	await physics_frame
	assert(hurt.hp > 1)
	await clear_mobs()

	# Oeuf : eclot en Soignant s'il n'est pas casse a temps.
	var egg = spawn(a, "vendredi/oeuf")
	await process_frame
	egg.timer = 0.05
	await create_timer(0.3).timeout
	assert(_count("Soignant") == 1)
	await clear_mobs()

	# Poids du Monde : invulnerable tant qu'un Soignant le protege.
	var weight = spawn(a, "vendredi/poids_du_monde")
	for i in 4:
		await process_frame
	var hp: int = weight.hp
	weight.take_hit(1)
	assert(weight.hp == hp)
	for m in get_nodes_in_group("mobs"):
		if m.display_name == "Soignant":
			m.take_hit(99)
	for i in 3:
		await process_frame
	weight.take_hit(1)
	assert(weight.hp == hp - 1)
