class_name Passive
extends Resource

var passive_id: String = ""
var passive_name: String = ""

# -1 = permanent, 0+ = nombre de tours restants
var duration: int = -1

# Mis à true par le passif lui-même quand il doit être retiré (usage unique, durée écoulée…)
var consumed: bool = false


# -- Hooks appelés par HeroBase (owner = la BattleUnit qui possède ce passif) --

func on_battle_start(owner: BattleUnit) -> void:
	pass

func on_turn_start(owner: BattleUnit) -> void:
	pass

func on_turn_end(owner: BattleUnit) -> void:
	if duration > 0:
		duration -= 1
		if duration == 0:
			consumed = true

# Retourne les dégâts après modification (0 = attaque annulée)
func on_take_damage(owner: BattleUnit, amount: int, attacker: BattleUnit) -> int:
	return amount

func on_kill(owner: BattleUnit, target: BattleUnit) -> void:
	pass

func on_healed(owner: BattleUnit, amount: int) -> void:
	pass

func on_ally_died(owner: BattleUnit, ally: BattleUnit) -> void:
	pass

func on_battle_end(owner: BattleUnit, victory: bool) -> void:
	pass
