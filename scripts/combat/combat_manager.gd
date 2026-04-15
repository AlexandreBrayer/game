class_name CombatManager
extends Node

# -- Signaux pour le HUD --
signal state_changed(state: State)
signal turn_started(unit: BattleUnit)
signal combat_ended(victory: bool)
# Emis quand le joueur doit choisir un sort pour un héros
signal hero_action_requested(hero: HeroBase)
# Emis quand le joueur doit choisir des cibles
signal target_selection_requested(hero: HeroBase, spell_index: int, spell_meta: Dictionary)

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

var _turn_order: Array = []       # mix HeroBase | EnemyBase trié par VIT
var _current_index: int = 0
var _pending_hero: HeroBase = null
var _pending_spell_index: int = -1


func start_combat(p_heroes: Array[HeroBase], p_enemies: Array[EnemyBase]) -> void:
	heroes = p_heroes
	enemies = p_enemies

	for h in heroes:
		h.on_battle_start()
		h.battle_unit.died.connect(_on_unit_died.bind(h.battle_unit))
	for e in enemies:
		e.on_battle_start()
		e.battle_unit.died.connect(_on_unit_died.bind(e.battle_unit))

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
	current.on_turn_start()
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
	enemy.cast_action(idx, living_heroes)
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


# Le joueur a confirmé ses cibles
func on_targets_selected(targets: Array[BattleUnit]) -> void:
	if state != State.WAITING_TARGET or _pending_hero == null:
		return
	_resolve_hero_spell(_pending_hero, _pending_spell_index, targets)


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
		for h in heroes:
			h.on_battle_end(true)
		combat_ended.emit(true)
		return true
	if not heroes_alive:
		state = State.DEFEAT
		for h in heroes:
			h.on_battle_end(false)
		combat_ended.emit(false)
		return true
	return false


func _on_unit_died(_unit: BattleUnit) -> void:
	# Notifie les alliés
	for h in heroes:
		if not h.battle_unit.is_alive():
			continue
		# On notifie seulement si c'est un allié qui est mort
		# (logique étendue possible ici pour les ennemis aussi)
	pass
