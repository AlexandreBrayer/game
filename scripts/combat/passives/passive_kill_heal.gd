class_name PassiveKillHeal
extends Passive

func _init() -> void:
	passive_id = "kill_heal"
	passive_name = "Instinct de prédateur"


func on_kill(owner: BattleUnit, _target: BattleUnit) -> void:
	var healed := owner.apply_heal(int(owner.hp_max * 0.05))
	print("  [Passif] Kill Heal : +%d HP (%d / %d)" % [healed, owner.hp, owner.hp_max])
