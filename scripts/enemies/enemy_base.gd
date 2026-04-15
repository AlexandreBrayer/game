class_name EnemyBase
extends Node2D

signal passive_triggered(passive_id: String)

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


# IA : à override dans chaque ennemi
# heroes = Array de HeroBase vivants
func choose_action(heroes: Array) -> int:
	return 0

func cast_action(index: int, heroes: Array) -> void:
	pass


func _cleanup_passives() -> void:
	var i := battle_unit.passives.size() - 1
	while i >= 0:
		if battle_unit.passives[i].consumed:
			battle_unit.passives.remove_at(i)
		i -= 1
