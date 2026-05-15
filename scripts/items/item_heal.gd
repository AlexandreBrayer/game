class_name ItemHeal
extends UsableItem

## Montant fixe de PV restaurés (avant heal_bonus de la cible).
@export var heal_amount: int = 30


func use(user: BattleUnit, p_targets: Array[BattleUnit]) -> String:
	var total := 0
	for t in p_targets:
		total += t.apply_heal(heal_amount)
	return "%s utilise %s → soigne %d PV" % [user.unit_name, item_name, total]
