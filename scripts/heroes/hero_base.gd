class_name HeroBase
extends Node2D

signal spell_cast(spell_index: int, caster: BattleUnit)
signal status_applied(status_id: String, target: BattleUnit)
signal passive_triggered(passive_id: String)

@export var data: HeroData

var battle_unit: BattleUnit = null


func _ready() -> void:
	assert(data != null, "HeroBase: data (HeroData) must be set on " + name)
	battle_unit = BattleUnit.from_hero_data(data, self)


func create_battle_unit() -> BattleUnit:
	battle_unit = BattleUnit.from_hero_data(data, self)
	return battle_unit


# -- Hooks de passifs (à override dans les héros spécifiques) --

func on_battle_start() -> void:
	for p in battle_unit.passives:
		p.on_battle_start(battle_unit)
	_cleanup_passives()

func on_turn_start() -> void:
	for p in battle_unit.passives:
		p.on_turn_start(battle_unit)
	_cleanup_passives()

func on_turn_end() -> void:
	for p in battle_unit.passives:
		p.on_turn_end(battle_unit)
	_cleanup_passives()

func on_damaged(amount: int) -> void:
	pass

func on_healed(amount: int) -> void:
	for p in battle_unit.passives:
		p.on_healed(battle_unit, amount)
	_cleanup_passives()

func on_kill(target: BattleUnit) -> void:
	for p in battle_unit.passives:
		p.on_kill(battle_unit, target)
	_cleanup_passives()

func on_ally_died(ally: BattleUnit) -> void:
	for p in battle_unit.passives:
		p.on_ally_died(battle_unit, ally)
	_cleanup_passives()

func on_battle_end(victory: bool) -> void:
	for p in battle_unit.passives:
		p.on_battle_end(battle_unit, victory)
	_cleanup_passives()


# Point d'entrée des dégâts : le CombatManager appelle toujours cette méthode.
# Retourne les dégâts effectivement reçus (après passifs).
# attacker peut être null (dégâts de statut, etc.)
func take_damage(amount: int, attacker: BattleUnit = null) -> int:
	var current := amount
	for p in battle_unit.passives:
		current = p.on_take_damage(battle_unit, current, attacker)
	_cleanup_passives()
	if current > 0:
		var received := battle_unit.apply_damage(current)
		if received > 0:
			on_damaged(received)
		return received
	return 0


# Utilitaire : inflige des dégâts à une cible en passant par son take_damage() si disponible.
# À utiliser dans tous les sorts pour respecter les passifs ennemis.
func deal_damage(target: BattleUnit, amount: int) -> void:
	if target.source_node and target.source_node.has_method("take_damage"):
		target.source_node.take_damage(amount, battle_unit)
	else:
		target.apply_damage(amount)
	if not target.is_alive():
		on_kill(target)


func _cleanup_passives() -> void:
	var i := battle_unit.passives.size() - 1
	while i >= 0:
		if battle_unit.passives[i].consumed:
			battle_unit.passives.remove_at(i)
		i -= 1


# -- Interface spells (à override dans chaque héros) --

# Retourne les métadonnées des sorts pour le HUD
# targets: {"enemies": int, "allies": int}
#   N > 0  → sélection manuelle de N unités
#   -1     → toutes les unités du groupe automatiquement
#   0      → groupe ignoré
# ex: {"enemies": 1, "allies": 0}  → 1 ennemi
#     {"enemies": -1, "allies": 0} → tous les ennemis
#     {"enemies": 1, "allies": 1}  → 1 ennemi + 1 allié
#     {"enemies": 0, "allies": 0}  → aucune cible (self / passif)
func get_spells() -> Array[Dictionary]:
	return []


# Exécute le sort à l'index donné sur les cibles
func cast_spell(index: int, targets: Array[BattleUnit]) -> void:
	pass


# Retourne true si le sort nécessite une sélection manuelle de cible
func spell_needs_targeting(index: int) -> bool:
	var spells := get_spells()
	if index < 0 or index >= spells.size():
		return false
	var t: Dictionary = spells[index].get("targets", {"enemies": 1, "allies": 0})
	return t.get("enemies", 0) > 0 or t.get("allies", 0) > 0
