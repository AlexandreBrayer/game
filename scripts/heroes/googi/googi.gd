class_name Googi
extends HeroBase

func _ready() -> void:
	super._ready()
	print("Googi est prêt pour la bataille!")
	print(data.hero_name + " a " + str(battle_unit.hp) + " HP et " + str(battle_unit.atk) + " ATK.")

func on_damaged(amount: int) -> void:
	print("Googi a été endommagé de %d points!" % amount)
