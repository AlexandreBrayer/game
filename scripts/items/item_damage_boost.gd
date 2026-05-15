class_name ItemDamageBoost
extends UsableItem

## Bonus fixe ajouté à chaque attaque sortante pendant la durée.
@export var flat_bonus: int = 15
## Bonus multiplicateur ajouté (ex: 0.5 = +50%). S'accumule avec d'autres buffs.
@export var mult_bonus: float = 0.0
## Durée en tours.
@export var duration_turns: int = 3


func use(user: BattleUnit, p_targets: Array[BattleUnit]) -> String:
	for t in p_targets:
		t.damage_buffs.append({
			"flat": flat_bonus,
			"mult_bonus": mult_bonus,
			"turns": duration_turns,
		})
	var target_names := ", ".join(p_targets.map(func(t): return t.unit_name))
	return "%s utilise %s sur %s → +%d dégâts fixes pendant %d tours" \
			% [user.unit_name, item_name, target_names, flat_bonus, duration_turns]
