class_name BattleUnit
extends RefCounted

signal hp_changed(current: int, maximum: int)
signal shield_changed(current: int)
signal died()

var unit_name: String = ""
var is_hero: bool = true

var hp_max: int = 0
var hp: int = 0:
	set(value):
		hp = clampi(value, 0, hp_max)
		hp_changed.emit(hp, hp_max)
		if hp == 0:
			died.emit()

var atk: int = 0
var vit: int = 0
var crit: float = 0.0
var heal_bonus: int = 0

var shield: int = 0:
	set(value):
		shield = maxi(0, value)
		shield_changed.emit(shield)

var statuses: Dictionary = {}
var cooldowns: Dictionary = {}
var passives: Array[Passive] = []
## Buffs de dégâts sortants : Array de {flat: int, mult_bonus: float, turns: int}
var damage_buffs: Array = []

# référence optionnelle vers le noeud héros dans la scène
var source_node: Node = null


static func from_hero_data(data: HeroData, node: Node = null) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.unit_name = data.hero_name
	unit.is_hero = true
	unit.hp_max = data.base_hp
	unit.hp = data.base_hp
	unit.atk = data.base_atk
	unit.vit = data.base_vit
	unit.crit = data.base_crit
	unit.heal_bonus = data.base_heal
	unit.shield = data.base_shield
	unit.source_node = node
	return unit


func is_alive() -> bool:
	return hp > 0


func apply_damage(amount: int) -> int:
	var absorbed := mini(shield, amount)
	shield -= absorbed
	var remaining := amount - absorbed
	hp -= remaining
	return remaining


func apply_heal(amount: int) -> int:
	var healed := mini(amount + heal_bonus, hp_max - hp)
	hp += healed
	return healed


func add_status(status_id: String, duration: int, stacks: int = 1) -> void:
	if statuses.has(status_id):
		statuses[status_id]["stacks"] = mini(statuses[status_id]["stacks"] + stacks, 99)
		statuses[status_id]["duration"] = maxi(statuses[status_id]["duration"], duration)
	else:
		statuses[status_id] = {"duration": duration, "stacks": stacks}


func tick_statuses() -> void:
	var to_remove: Array[String] = []
	for id in statuses:
		statuses[id]["duration"] -= 1
		if statuses[id]["duration"] <= 0:
			to_remove.append(id)
	for id in to_remove:
		statuses.erase(id)


func get_cooldown(spell_id: String) -> int:
	return cooldowns.get(spell_id, 0)


func set_cooldown(spell_id: String, value: int) -> void:
	if value <= 0:
		cooldowns.erase(spell_id)
	else:
		cooldowns[spell_id] = value


func tick_cooldowns() -> void:
	for id in cooldowns.keys():
		cooldowns[id] -= 1
		if cooldowns[id] <= 0:
			cooldowns.erase(id)


func tick_damage_buffs() -> void:
	var i := damage_buffs.size() - 1
	while i >= 0:
		damage_buffs[i]["turns"] -= 1
		if damage_buffs[i]["turns"] <= 0:
			damage_buffs.remove_at(i)
		i -= 1


## Applique les buffs de dégâts actifs sur un montant de base.
func compute_outgoing_damage(base: int) -> int:
	var flat := 0
	var mult := 1.0
	for buff in damage_buffs:
		flat += buff.get("flat", 0)
		mult += buff.get("mult_bonus", 0.0)
	return int((base + flat) * mult)
