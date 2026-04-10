# Script de test à attacher sur une scène vide.
# Noeuds attendus dans la scène :
#   - Googi  (scène googi.tscn)
#   - Dummy  (scène target_dummy.tscn, ou Node2D + target_dummy.gd + EnemyData)
extends Node

@export var rounds: int = 5

@onready var googi: Googi = $Googi
@onready var dummy: TargetDummy = $Dummy


func _ready() -> void:
	await get_tree().process_frame  # laisse les _ready enfants s'exécuter

	assert(googi != null, "CombatTest: noeud Googi manquant")
	assert(dummy != null, "CombatTest: noeud Dummy manquant")

	_run_test()


func _run_test() -> void:
	print("=== DEBUT DU COMBAT TEST ===")
	googi.on_battle_start()
	dummy.on_battle_start()

	for round_n in range(1, rounds + 1):
		if not googi.battle_unit.is_alive() or not dummy.battle_unit.is_alive():
			break
		print("\n-- Round %d --" % round_n)
		_do_round()

	print("\n=== FIN DU COMBAT ===")
	if googi.battle_unit.is_alive():
		print("Googi survit avec %d HP" % googi.battle_unit.hp)
	else:
		print("Googi est mort.")
	if dummy.battle_unit.is_alive():
		print("Dummy survit avec %d HP" % dummy.battle_unit.hp)
	else:
		print("Dummy est détruit.")


func _do_round() -> void:
	# Tour de Googi : frappe agile sur le Dummy
	if googi.battle_unit.is_alive():
		print("[Googi] lance Frappe Agile")
		googi.cast_spell(0, [dummy.battle_unit])
		print("  → Dummy HP : %d / %d" % [dummy.battle_unit.hp, dummy.battle_unit.hp_max])

	# Tour du Dummy : attaque Googi de 1
	if dummy.battle_unit.is_alive():
		print("[Dummy] attaque Googi de 1")
		googi.take_damage(1, dummy.battle_unit)
		print("  → Googi HP : %d / %d" % [googi.battle_unit.hp, googi.battle_unit.hp_max])

	# Fin de tour
	googi.on_turn_end()
	dummy.on_turn_end()

	googi.battle_unit.tick_cooldowns()
	dummy.battle_unit.tick_cooldowns()
	googi.battle_unit.tick_statuses()
	dummy.battle_unit.tick_statuses()
