class_name HeroSpells
extends Node

signal spell_executed(spell: SpellData, caster: BattleUnit, targets: Array[BattleUnit])

@onready var hero: HeroBase = get_parent() as HeroBase

var _spells: Array[SpellData] = []


func _ready() -> void:
	assert(hero != null and hero is HeroBase, "HeroSpells doit être enfant d'un HeroBase")
	# Attend que hero_base ait initialisé son battle_unit
	await owner.ready
	_spells = hero.data.spells if hero.data else []


func get_available_spells() -> Array[SpellData]:
	if not hero.battle_unit:
		return []
	var available: Array[SpellData] = []
	for spell in _spells:
		if hero.battle_unit.get_cooldown(spell.spell_name) == 0:
			available.append(spell)
	return available


func cast(spell: SpellData, targets: Array[BattleUnit]) -> void:
	if not hero.battle_unit or not hero.battle_unit.is_alive():
		return
	if hero.battle_unit.get_cooldown(spell.spell_name) > 0:
		push_warning("HeroSpells: %s est en cooldown" % spell.spell_name)
		return

	_apply_spell(spell, targets)

	if spell.cooldown_max > 0:
		hero.battle_unit.set_cooldown(spell.spell_name, spell.cooldown_max)

	spell_executed.emit(spell, hero.battle_unit, targets)
	hero.spell_cast.emit(spell, hero.battle_unit)


func _apply_spell(spell: SpellData, targets: Array[BattleUnit]) -> void:
	for target in targets:
		if not target.is_alive():
			continue

		match spell.spell_type:
			SpellData.SpellType.DAMAGE:
				var dmg := int(hero.battle_unit.atk * spell.base_power)
				if randf() < hero.battle_unit.crit:
					dmg = int(dmg * 1.5)
				var killed_before := not target.is_alive()
				target.apply_damage(dmg)
				if target.is_alive() == false and not killed_before:
					hero.on_kill(target)

			SpellData.SpellType.HEAL:
				var amount := int(spell.base_power * (hero.battle_unit.atk + hero.battle_unit.heal_bonus))
				target.apply_heal(amount)
				hero.on_healed(amount)

			SpellData.SpellType.SHIELD:
				target.shield += int(spell.base_power * hero.battle_unit.atk)

			SpellData.SpellType.BUFF, SpellData.SpellType.DEBUFF, SpellData.SpellType.AFFLICTION:
				if spell.applies_status != "":
					target.add_status(spell.applies_status, spell.status_duration, spell.status_stacks)
					hero.status_applied.emit(spell.applies_status, target)
