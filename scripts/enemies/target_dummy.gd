class_name TargetDummy
extends EnemyBase

@export_group("Config")
@export var base_damage: int = 1 


func cast_action(index: int, heroes: Array) -> void:
	for hero in heroes:
		if hero is HeroBase:
			hero.take_damage(base_damage + battle_unit.atk, battle_unit)
