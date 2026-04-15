class_name Googi
extends HeroBase

@export_group("General config")
@export var frappe_agile_damages: float = 20.0
@export var deluge_de_griffes_damages: float = 10.0
@export var parade_agile_reflect_percent: float = 0.5
@export_group("Spells config")
@export var frappe_agile_cooldown: int = 0
@export var deluge_de_griffes_cooldown: int = 1
@export var parade_agile_cooldown: int = 2
@export var frappe_agile_description: String = "Attaque rapide sur une cible."
@export var deluge_de_griffes_description: String = "Frappe tous les ennemis."
@export var parade_agile_description: String = "Parade qui annule les dégâts du prochain coup et reflète une partie des dégâts sur l'attaquant."

func _ready() -> void:
	super._ready()
	print(data.hero_name + " a " + str(battle_unit.hp) + " HP et " + str(battle_unit.atk) + " ATK.")


# -- Spells --

func get_spells() -> Array[Dictionary]:
	return [
		{"name": "Frappe Agile", "description": frappe_agile_description, "cooldown_max": frappe_agile_cooldown, "targets": {"enemies": 1, "allies": 0}},
		{"name": "Déluge de Griffes", "description": deluge_de_griffes_description, "cooldown_max": deluge_de_griffes_cooldown, "targets": {"enemies": - 1, "allies": 0}},
		{"name": "Parade Agile", "description": parade_agile_description, "cooldown_max": parade_agile_cooldown, "targets": {"enemies": 0, "allies": 0}},
	]


func cast_spell(index: int, targets: Array[BattleUnit]) -> void:
	if battle_unit.get_cooldown(str(index)) > 0:
		return
	spell_cast.emit(index, battle_unit)
	var cd: int = get_spells()[index].get("cooldown_max", 0)
	if cd > 0:
		battle_unit.set_cooldown(str(index), cd)
	match index:
		0: _frappe_agile(targets)
		1: _deluge_de_griffes(targets)
		2: _parade_agile(targets)


func _frappe_agile(targets: Array[BattleUnit]) -> void:
	for t in targets:
		deal_damage(t, int(battle_unit.atk + frappe_agile_damages))


func _deluge_de_griffes(targets: Array[BattleUnit]) -> void:
	for t in targets:
		deal_damage(t, int(battle_unit.atk * 0.5 + deluge_de_griffes_damages))


func _parade_agile(_targets: Array[BattleUnit]) -> void:
	battle_unit.passives.append(PassiveParadeAgile.new(parade_agile_reflect_percent))
	passive_triggered.emit("parade_agile")
