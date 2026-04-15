class_name EnemyBase
extends Node2D

signal passive_triggered(passive_id: String)
signal damage_received(amount: int, attacker: BattleUnit)
signal action_used(action_name: String)

@export var data: EnemyData

var battle_unit: BattleUnit = null


func _ready() -> void:
	assert(data != null, "EnemyBase: data (EnemyData) must be set on " + name)
	battle_unit = _create_battle_unit()


func _create_battle_unit() -> BattleUnit:
	var unit := BattleUnit.new()
	unit.unit_name = data.enemy_name
	unit.is_hero = false
	unit.hp_max = data.base_hp
	unit.hp = data.base_hp
	unit.atk = data.base_atk
	unit.vit = data.base_vit
	unit.crit = data.base_crit
	unit.shield = data.base_shield
	unit.source_node = self
	return unit


# Point d'entrée des dégâts (même convention que HeroBase)
func take_damage(amount: int, attacker: BattleUnit = null) -> int:
	var current := amount
	for p in battle_unit.passives:
		current = p.on_take_damage(battle_unit, current, attacker)
	_cleanup_passives()
	if current > 0:
		var received := battle_unit.apply_damage(current)
		if received > 0:
			damage_received.emit(received, attacker)
			on_damaged(received)
		return received
	return 0


# -- Hooks de passifs --

func on_battle_start() -> void:
	for p in battle_unit.passives:
		p.on_battle_start(battle_unit)
	_cleanup_passives()

func on_turn_start() -> void:
	for p in battle_unit.passives:
		p.on_turn_start(battle_unit)
	_cleanup_passives()

func on_turn_end() -> void:
	for p in battle_unit.passives:
		p.on_turn_end(battle_unit)
	_cleanup_passives()

func on_damaged(_amount: int) -> void:
	pass

func on_kill(_target: BattleUnit) -> void:
	pass

func on_battle_end(_victory: bool) -> void:
	pass


# Utilitaire : attaque via la chaîne passive (comme HeroBase.deal_damage)
func deal_damage(target: BattleUnit, amount: int) -> void:
	if target.source_node != null and target.source_node.has_method("take_damage"):
		target.source_node.take_damage(amount, battle_unit)
	else:
		target.apply_damage(amount)
	if not target.is_alive():
		on_kill(target)


# IA : liste des actions disponibles (à override)
# Chaque dict : { "name": String, "targets": int }
#   targets == -1  → toutes les cibles
#   targets > 0   → N cibles au choix (random)
func get_actions() -> Array[Dictionary]:
	return [{"name": "Attaque", "targets": 1}]


# IA : choisit aléatoirement parmi les actions non en cooldown
func choose_action(_heroes: Array) -> int:
	var actions := get_actions()
	var available: Array[int] = []
	for i in actions.size():
		if battle_unit.get_cooldown(str(i)) <= 0:
			available.append(i)
	if available.is_empty():
		return 0
	return available[randi() % available.size()]


# À override dans chaque ennemi ; heroes = cibles déjà filtrées par CombatManager
func cast_action(index: int, _heroes: Array) -> void:
	var actions := get_actions()
	var action_name: String = actions[index]["name"] if index < actions.size() else "Attaque"
	action_used.emit(action_name)


func _cleanup_passives() -> void:
	var i := battle_unit.passives.size() - 1
	while i >= 0:
		if battle_unit.passives[i].consumed:
			battle_unit.passives.remove_at(i)
		i -= 1
