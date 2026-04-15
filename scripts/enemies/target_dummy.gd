class_name TargetDummy
extends EnemyBase

@export_group("Config")
@export var base_damage: int = 1
@export var aoe_damage: int = 1


func get_actions() -> Array[Dictionary]:
	return [
		{"name": "Frappe",     "targets": 1},
		{"name": "Frappe AOE", "targets": -1},
	]


func cast_action(index: int, heroes: Array) -> void:
	super.cast_action(index, heroes)
	match index:
		0:  # Frappe simple
			for hero in heroes:
				if hero is HeroBase:
					deal_damage(hero.battle_unit, base_damage + battle_unit.atk)
		1:  # AOE
			for hero in heroes:
				if hero is HeroBase:
					deal_damage(hero.battle_unit, aoe_damage + battle_unit.atk)
