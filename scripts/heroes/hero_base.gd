class_name HeroBase
extends Node2D

signal spell_cast(spell: SpellData, caster: BattleUnit)
signal status_applied(status_id: String, target: BattleUnit)
signal passive_triggered(passive_id: String)

@export var data: HeroData

var battle_unit: BattleUnit = null


func _ready() -> void:
	assert(data != null, "HeroBase: data (HeroData) must be set on " + name)
	battle_unit = BattleUnit.from_hero_data(data, self)


func create_battle_unit() -> BattleUnit:
	battle_unit = BattleUnit.from_hero_data(data, self)
	return battle_unit


# -- Hooks de passifs (à override dans les héros spécifiques) --

func on_battle_start() -> void:
	pass

func on_turn_start() -> void:
	pass

func on_turn_end() -> void:
	pass

func on_damaged(amount: int) -> void:
	pass

func on_healed(amount: int) -> void:
	pass

func on_kill(_target: BattleUnit) -> void:
	pass

func on_ally_died(_ally: BattleUnit) -> void:
	pass

func on_battle_end(victory: bool) -> void:
	pass

