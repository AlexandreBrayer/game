class_name PassiveParadeAgile
extends Passive

const DAMAGE_REFLECT_PERCENTAGE := 0.5

var damage_reflect_percentage: float = DAMAGE_REFLECT_PERCENTAGE

func _init(reflect: float = DAMAGE_REFLECT_PERCENTAGE) -> void:
	passive_id = "parade_agile"
	passive_name = "Parade Agile"
	self.damage_reflect_percentage = reflect


func on_take_damage(_owner: BattleUnit, amount: int, attacker: BattleUnit) -> int:
	print("  [Passif] Parade Agile : parade réussie, dégâts annulés et reflet de %d%%" % int(self.damage_reflect_percentage * 100))
	if attacker and attacker.is_alive():
		# Reflect a portion of the damage back to the attacker
		attacker.apply_damage(int(amount * self.damage_reflect_percentage))
	consumed = true
	return 0
