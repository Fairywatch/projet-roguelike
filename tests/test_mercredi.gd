# Lancer : godot --headless --path . --script res://tests/test_mercredi.gd
# Bestiaire du mercredi (Doute) : verification commune + mecaniques propres.
extends "res://tests/bestiary_check.gd"

func _init() -> void:
	night = "mercredi"

func check_specific(a: Node) -> void:
	# Pile ou Face : invulnerable sur pile, vulnerable sur face.
	var coin = spawn(a, "mercredi/pile_ou_face")
	await process_frame
	var hp: int = coin.hp
	coin.take_hit(1)
	assert(coin.hp == hp)
	coin.invulnerable = false
	coin.take_hit(1)
	assert(coin.hp == hp - 1)
	await clear_mobs()

	# Les Deux Voies : frapper la mauvaise voie soigne la bonne.
	var path = spawn(a, "mercredi/deux_voies")
	for i in 3:
		await process_frame
	var other = path.partner
	path.take_hit(3)
	var true_hp: int = path.hp
	other.take_hit(1)
	assert(path.hp > true_hp and other.hp == other.max_hp)
	await clear_mobs()

	# L'Autre Soi, phase 3 : calme si le joueur n'attaque pas, et s'efface apres assez de paix.
	var double = spawn(a, "mercredi/autre_soi")
	await process_frame
	double.take_hit(int(double.max_hp * 0.7))
	assert(double.phase == 3)
	a.player.last_attack_time = -100.0
	double.peace = double.PEACE_TIME - 0.2
	await create_timer(0.5).timeout
	assert(not is_instance_valid(double) or double.state == double.State.DEAD)
