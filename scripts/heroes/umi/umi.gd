class_name Umi
extends HeroBase

@export_group("General config")
@export var tsunami_damages: float = 30.0
@export var maree_descendante_damages: float = 15.0
@export var maree_montante_heal: float = 20.0
@export_group("Spells config")
@export var tsunami_cooldown: int = 2
@export var maree_descendante_cooldown: int = 1
@export var maree_montante_cooldown: int = 3
@export var tsunami_description: String = "Attaque tous les ennemis avec une vague puissante."
@export var maree_descendante_description: String = "Frappe un ennemi avec une vague descendante."
@export var maree_montante_description: String = "Soigne tous les allies avec une vague montante."

func _ready() -> void:
    super()._ready()
    print(data.hero_name + " a " + str(battle_unit.hp) + " HP et " + str(battle_unit.atk) + " ATK.")

# -- Spells --

func get_spells() -> Array[Dictionary]:
    return [
        {"name": "Tsunami", "description": tsunami_description, "cooldown_max": tsunami_cooldown, "targets": {"enemies": -1, "allies": 0}},
        {"name": "Maree Descendante", "description": maree_descendante_description, "cooldown_max": maree_descendante_cooldown, "targets": {"enemies": 1, "allies": 0}},
        {"name": "Maree Montante", "description": maree_montante_description, "cooldown_max": maree_montante_cooldown, "targets": {"enemies": 0, "allies": -1}},
    ]

func cast_spell(index: int, targets: Array[BattleUnit]) -> void:
    if battle_unit.get_cooldown(str(index)) > 0:
        return
    spell_cast.emit(index, battle_unit)
    var cd: int = get_spells()[index].get("cooldown_max", 0)
    if cd > 0:
        battle_unit.set_cooldown(str(index), cd)
    match index:
        0: _tsunami(targets)
        1: _maree_descendante(targets)
        2: _maree_montante(targets)

func _tsunami(targets: Array[BattleUnit]) -> void:
    for t in targets:
        deal_damage(t, int(battle_unit.atk * 0.5 + tsunami_damages))

func _maree_descendante(targets: Array[BattleUnit]) -> void:
    for t in targets:
        deal_damage(t, int(battle_unit.atk * 0.5 + maree_descendante_damages))

func _maree_montante(targets: Array[BattleUnit]) -> void:
    for t in targets:
        heal(t, int(battle_unit.atk * 0.5 + maree_montante_heal))