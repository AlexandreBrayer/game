class_name Googi
extends HeroBase

@export_group("Config")
@export var frappe_agile_damages: float = 20.0
@export var deluge_de_griffes_damages: float = 10.0


func _ready() -> void:
	super._ready()
	print(data.hero_name + " a " + str(battle_unit.hp) + " HP et " + str(battle_unit.atk) + " ATK.")


# -- Spells --

func get_spells() -> Array[Dictionary]:
	return [
		{"name": "Frappe Agile", "description": "Attaque rapide sur une cible.", "cooldown_max": 0, "targets": {"enemies": 1, "allies": 0}},
		{"name": "Déluge de Griffes", "description": "Frappe tous les ennemis", "cooldown_max": 1, "targets": {"enemies": -1, "allies": 0}},
		{"name": "Parade Agile", "description": "Frappe tous les ennemis.", "cooldown_max": 2, "targets": {"enemies": 0, "allies": 0}},
	]


func cast_spell(index: int, targets: Array[BattleUnit]) -> void:
	if battle_unit.get_cooldown(str(index)) > 0:
		return
	match index:
		0: _frappe_agile(targets)
		1: _deluge_de_griffes(targets)
		2: _parade_agile(targets)
	var cd: int = get_spells()[index].get("cooldown_max", 0)
	if cd > 0:
		battle_unit.set_cooldown(str(index), cd)
	spell_cast.emit(index, battle_unit)


func _frappe_agile(targets: Array[BattleUnit]) -> void:
	for t in targets:
		var dmg := int(battle_unit.atk + frappe_agile_damages)
		t.apply_damage(dmg)
		if not t.is_alive():
			on_kill(t)


func _deluge_de_griffes(targets: Array[BattleUnit]) -> void:
	for t in targets:
		var dmg := int(battle_unit.atk * 0.5 + deluge_de_griffes_damages)
		t.apply_damage(dmg)
		if not t.is_alive():
			on_kill(t)


func _parade_agile(_targets: Array[BattleUnit]) -> void:
	battle_unit.passives.append(PassiveParadeAgile.new())
	passive_triggered.emit("parade_agile")
