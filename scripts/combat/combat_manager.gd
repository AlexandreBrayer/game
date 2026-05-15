class_name CombatManager
extends Node

# -- Signaux pour le HUD --
signal state_changed(state: State)
signal turn_started(unit: BattleUnit)
signal combat_ended(victory: bool)
# Emis quand le joueur doit choisir un sort pour un hero
signal hero_action_requested(hero: HeroBase)
# Emis quand le joueur doit choisir des cibles
signal target_selection_requested(hero: HeroBase, spell_index: int, spell_meta: Dictionary)
# Emis pour ouvrir la liste d'objets
signal item_menu_requested(hero: HeroBase)
# Emis quand un objet necessite une selection de cibles
signal item_target_requested(hero: HeroBase, item: UsableItem)

enum State {
	IDLE,
	PLAYER_TURN,
	WAITING_SPELL,
	WAITING_TARGET,
	RESOLVING,
	ENEMY_TURN,
	VICTORY,
	DEFEAT,
}

var state: State = State.IDLE:
	set(v):
		state = v
		state_changed.emit(v)

var heroes: Array[HeroBase] = []
var enemies: Array[EnemyBase] = []

var _turn_order: Array = []       # mix HeroBase | EnemyBase trie par VIT
var _current_index: int = 0
var _pending_hero: HeroBase = null
var _pending_spell_index: int = -1
var _pending_item: UsableItem = null

## Inventaire partage de la run (peuple par la scene avant start_combat).
var inventory: Array[UsableItem] = []


func start_combat(p_heroes: Array[HeroBase], p_enemies: Array[EnemyBase]) -> void:
	heroes = p_heroes
	enemies = p_enemies
	CombatLog.clear()
	CombatLog.log("=== Combat commence ===")

	for h in heroes:
		h.on_battle_start()
		h.spell_cast.connect(func(spell_index: int, _caster: BattleUnit):
			var sname: String = h.get_spells()[spell_index].get("name", "Sort %d" % spell_index)
			CombatLog.log("  %s utilise %s" % [h.data.hero_name, sname])
		)
		h.passive_triggered.connect(func(msg): CombatLog.log("  ❆ [%s] %s" % [h.data.hero_name, msg]))
		h.damage_received.connect(func(amount: int, attacker: BattleUnit):
			var att := attacker.unit_name if attacker else "?"
			CombatLog.log("  %s inflige %d dégâts à %s (%d/%d HP)" % [att, amount, h.battle_unit.unit_name, h.battle_unit.hp, h.battle_unit.hp_max])
		)
		h.battle_unit.died.connect(func(): CombatLog.log("  ✖ %s est mort !" % h.battle_unit.unit_name))
	for e in enemies:
		e.on_battle_start()
		e.battle_unit.died.connect(func(): CombatLog.log("  ✖ %s est mort !" % e.battle_unit.unit_name))
		e.damage_received.connect(func(amount: int, attacker: BattleUnit):
			var att := attacker.unit_name if attacker else "?"
			CombatLog.log("  %s inflige %d dégâts à %s (%d/%d HP)" % [att, amount, e.battle_unit.unit_name, e.battle_unit.hp, e.battle_unit.hp_max])
		)
		e.action_used.connect(func(action_name: String):
			CombatLog.log("  %s utilise %s" % [e.battle_unit.unit_name, action_name])
		)

	_build_turn_order()
	state = State.PLAYER_TURN
	_next_turn()


func _build_turn_order() -> void:
	_turn_order.clear()
	for h in heroes:
		_turn_order.append(h)
	for e in enemies:
		_turn_order.append(e)
	_turn_order.sort_custom(func(a, b): return a.battle_unit.vit > b.battle_unit.vit)
	_current_index = 0


# -- Tour suivant --

func _next_turn() -> void:
	if _check_end():
		return

	# Avance jusqu'à une unité vivante
	var loops := 0
	while loops < _turn_order.size():
		var unit = _turn_order[_current_index]
		if unit.battle_unit.is_alive():
			break
		_current_index = (_current_index + 1) % _turn_order.size()
		loops += 1

	var current = _turn_order[_current_index]
	current.battle_unit.tick_cooldowns()
	current.battle_unit.tick_statuses()
	current.battle_unit.tick_damage_buffs()
	current.on_turn_start()
	CombatLog.log("\n— Tour de %s —" % current.battle_unit.unit_name)
	turn_started.emit(current.battle_unit)

	if current is HeroBase:
		_start_hero_turn(current)
	else:
		_start_enemy_turn(current)


func _start_hero_turn(hero: HeroBase) -> void:
	state = State.WAITING_SPELL
	_pending_hero = hero
	hero_action_requested.emit(hero)


func _start_enemy_turn(enemy: EnemyBase) -> void:
	state = State.ENEMY_TURN
	await get_tree().create_timer(0.5).timeout  # pause visuelle
	var living_heroes := heroes.filter(func(h): return h.battle_unit.is_alive())
	if living_heroes.is_empty():
		return

	var idx := enemy.choose_action(living_heroes)

	# Filtre les cibles selon le champ targets de l'action
	var actions := enemy.get_actions()
	var target_count: int = 1
	if idx < actions.size():
		target_count = actions[idx].get("targets", 1)

	var targets: Array
	if target_count == -1:
		targets = living_heroes
	else:
		var shuffled := living_heroes.duplicate()
		shuffled.shuffle()
		targets = shuffled.slice(0, mini(target_count, shuffled.size()))

	enemy.cast_action(idx, targets)
	_end_turn(enemy)


# -- API appelée par le HUD --

# Le joueur a choisi un sort
func on_spell_selected(spell_index: int) -> void:
	if state != State.WAITING_SPELL or _pending_hero == null:
		return
	_pending_spell_index = spell_index
	var spell_meta: Dictionary = _pending_hero.get_spells()[spell_index]
	var t: Dictionary = spell_meta.get("targets", {"enemies": 1, "allies": 0})

	# Sorts sans sélection manuelle : on résout directement
	if t.get("enemies", 0) <= 0 and t.get("allies", 0) <= 0:
		var auto_targets: Array[BattleUnit] = []
		if t.get("enemies", 0) == -1:
			for e in enemies:
				if e.battle_unit.is_alive():
					auto_targets.append(e.battle_unit)
		if t.get("allies", 0) == -1:
			for h in heroes:
				if h.battle_unit.is_alive():
					auto_targets.append(h.battle_unit)
		_resolve_hero_spell(_pending_hero, spell_index, auto_targets)
	else:
		state = State.WAITING_TARGET
		target_selection_requested.emit(_pending_hero, spell_index, spell_meta)


# Le joueur a confirme ses cibles (sort)
func on_targets_selected(targets: Array[BattleUnit]) -> void:
	if state != State.WAITING_TARGET or _pending_hero == null:
		return
	_resolve_hero_spell(_pending_hero, _pending_spell_index, targets)


# -- API objets --

## Appele par le HUD quand le joueur clique sur le bouton Objets.
func on_item_menu_opened() -> void:
	if state != State.WAITING_SPELL or _pending_hero == null:
		return
	item_menu_requested.emit(_pending_hero)


## Appele par le HUD quand le joueur selectionne un objet dans la liste.
func on_item_selected(item: UsableItem) -> void:
	if state != State.WAITING_SPELL or _pending_hero == null:
		return
	_pending_item = item
	var t: Dictionary = item.targets
	if t.get("enemies", 0) <= 0 and t.get("allies", 0) <= 0:
		var msg := item.use(_pending_hero.battle_unit, [])
		_consume_item(item)
		CombatLog.log("  [ITEM] " + msg)
		_pending_item = null
		_end_turn(_pending_hero)
	else:
		state = State.WAITING_TARGET
		item_target_requested.emit(_pending_hero, item)


## Appele par le HUD quand les cibles d'un objet sont confirmees.
func on_item_targets_selected(targets: Array[BattleUnit]) -> void:
	if state != State.WAITING_TARGET or _pending_hero == null or _pending_item == null:
		return
	var msg := _pending_item.use(_pending_hero.battle_unit, targets)
	_consume_item(_pending_item)
	CombatLog.log("  [ITEM] " + msg)
	_pending_item = null
	_end_turn(_pending_hero)


func _consume_item(item: UsableItem) -> void:
	if item.uses > 0:
		item.uses -= 1
		if item.uses == 0:
			inventory.erase(item)


func _resolve_hero_spell(hero: HeroBase, spell_index: int, targets: Array[BattleUnit]) -> void:
	state = State.RESOLVING
	hero.cast_spell(spell_index, targets)
	_end_turn(hero)


# -- Fin de tour --

func _end_turn(unit) -> void:
	unit.on_turn_end()
	_pending_hero = null
	_pending_spell_index = -1
	_current_index = (_current_index + 1) % _turn_order.size()

	if not _check_end():
		_next_turn()


func _check_end() -> bool:
	var heroes_alive := heroes.any(func(h): return h.battle_unit.is_alive())
	var enemies_alive := enemies.any(func(e): return e.battle_unit.is_alive())

	if not enemies_alive:
		state = State.VICTORY
		CombatLog.log("\n=== Victoire ! ===")
		for h in heroes:
			h.on_battle_end(true)
		combat_ended.emit(true)
		return true
	if not heroes_alive:
		state = State.DEFEAT
		CombatLog.log("\n=== Défaite… ===")
		for h in heroes:
			h.on_battle_end(false)
		combat_ended.emit(false)
		return true
	return false


