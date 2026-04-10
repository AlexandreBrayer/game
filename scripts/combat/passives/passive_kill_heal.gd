class_name PassiveKillHeal
extends Passive

func _init() -> void:
	passive_id = "kill_heal"
	passive_name = "Instinct de prédateur"


func on_kill(owner: BattleUnit, _target: BattleUnit) -> void:
	owner.apply_heal(int(owner.hp_max * 0.05))
