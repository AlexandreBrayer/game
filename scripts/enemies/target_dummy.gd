class_name TargetDummy
extends EnemyBase

@export_group("Config")
@export var base_damage: int = 1
@export var aoe_damage: int = 1


func get_spells() -> Array[Dictionary]:
	return [
		{"name": "Frappe",     "targets": {"enemies": 1,  "allies": 0}},
		{"name": "Frappe AOE", "targets": {"enemies": -1, "allies": 0}},
	]


func cast_spell(index: int, targets: Array[BattleUnit]) -> void:
	super.cast_spell(index, targets)
	match index:
		0:
			for t in targets:
				deal_damage(t, base_damage + battle_unit.atk)
		1:
			for t in targets:
				deal_damage(t, aoe_damage + battle_unit.atk)
