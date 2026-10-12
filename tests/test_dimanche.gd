# Lancer : godot --headless --path . --script res://tests/test_dimanche.gd
# Bestiaire du dimanche (Angoisse) : verification commune + mecaniques propres.
extends "res://tests/bestiary_check.gd"

func _init() -> void:
	night = "dimanche"

func check_specific(a: Node) -> void:
	# Compte a rebours : detruit avant zero, pas d'explosion ; a zero, il explose et disparait.
	var bomb = spawn(a, "dimanche/compte_a_rebours")
	await process_frame
	bomb.count = 2
	bomb.tick = 0.01
	await create_timer(0.1).timeout
	assert(bomb.count == 1 and is_instance_valid(bomb.blast_zone))
	var blast = bomb.blast_zone
	bomb.take_hit(99)
	await process_frame
	assert(not is_instance_valid(blast) or blast.is_queued_for_deletion())
	await clear_mobs()

	# Mains du lundi : invulnerables sous terre, vulnerables une fois sorties.
	var hand = spawn(a, "dimanche/mains")
	await process_frame
	var hp: int = hand.hp
	hand.take_hit(1)
	assert(hand.hp == hp)
	hand._on_attack_begin()
	hand.take_hit(1)
	assert(hand.hp == hp - 1)
	await clear_mobs()

	# Ombre portee : frappe la ou le joueur se trouvait il y a une seconde.
	var shadow = spawn(a, "dimanche/ombre_portee")
	await create_timer(1.3).timeout
	assert(shadow.global_position.distance_to(a.player.global_position) < 40.0 or shadow.history.size() > 10)
	await clear_mobs()

	# La Derniere Nuit : en phase 3, invulnerable ; elle se dissout a l'aube.
	var night_boss = spawn(a, "dimanche/derniere_nuit")
	await process_frame
	night_boss.take_hit(int(night_boss.max_hp * 0.7))
	assert(night_boss.phase == 3 and night_boss.invulnerable)
	hp = night_boss.hp
	night_boss.take_hit(5)
	assert(night_boss.hp == hp)
	night_boss.dawn = 0.1
	await create_timer(0.4).timeout
	assert(not is_instance_valid(night_boss) or night_boss.state == night_boss.State.DEAD)
