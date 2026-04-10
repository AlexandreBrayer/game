class_name PassiveParadeAgile
extends Passive

const DAMAGE_REFLECT_PERCENTAGE := 0.5

func _init() -> void:
	passive_id = "parade_agile"
	passive_name = "Parade Agile"


func on_take_damage(_owner: BattleUnit, amount: int, attacker: BattleUnit) -> int:
	if attacker and attacker.is_alive():
		# Reflect a portion of the damage back to the attacker
		attacker.apply_damage(int(amount * DAMAGE_REFLECT_PERCENTAGE))
	consumed = true
	return 0
