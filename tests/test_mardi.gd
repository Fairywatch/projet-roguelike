# Lancer : godot --headless --path . --script res://tests/test_mardi.gd
# Bestiaire du mardi (Stress) : verification commune + mecaniques propres.
extends "res://tests/bestiary_check.gd"

func _init() -> void:
	night = "mardi"

func check_specific(a: Node) -> void:
	# Trotteuse : chaque charge est plus rapide que la precedente.
	var hand = spawn(a, "mardi/trotteuse")
	await process_frame
	var speed: float = hand.dash_speed
	hand._on_attack_end()
	assert(hand.dash_speed > speed)
	await clear_mobs()

	# Pile de devoirs (variante) : se divise en deux petites piles au premier coup.
	var pile = spawn(a, "mardi/pile_devoirs", {"alt": true})
	await process_frame
	pile.take_hit(1)
	for i in 3:
		await process_frame
	var smalls := get_nodes_in_group("mobs").filter(func(m): return m.display_name == "Pile de devoirs" and m.small)
	assert(smalls.size() == 2)
	await clear_mobs()

	# Battement : les battements accelerent.
	var heart = spawn(a, "mardi/battement")
	await process_frame
	var cooldown: float = heart.cooldown_duration
	heart._on_attack_begin()
	assert(heart.cooldown_duration < cooldown)
	await clear_mobs()

	# Examen : en phase 2 l'arene se resserre, et assez de degats la font reculer.
	var exam = spawn(a, "mardi/examen")
	await process_frame
	exam.take_hit(int(exam.max_hp * 0.4))
	assert(exam.phase == 2)
	exam._on_attack_begin()
	assert(is_instance_valid(exam.countdown) and not exam.countdown.retracting)
	exam.take_hit(int(exam.max_hp * 0.16) + 1)
	assert(exam.countdown.retracting)
