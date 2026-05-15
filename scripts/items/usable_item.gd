class_name UsableItem
extends Resource

@export var item_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

## Utilisations restantes. -1 = illimité.
@export var uses: int = 1

## Format identique aux sorts : enemies/allies > 0 = sélection manuelle, -1 = tous, 0 = aucun.
@export var targets: Dictionary = {"enemies": 0, "allies": 1}


## Override dans les sous-classes. Retourne un message de log.
func use(user: BattleUnit, p_targets: Array[BattleUnit]) -> String:
	return "%s utilise %s" % [user.unit_name, item_name]
