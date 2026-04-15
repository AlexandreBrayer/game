class_name CombatHUD
extends CanvasLayer

# -- Noeuds attendus dans la scène --
# CombatHUD (CanvasLayer)
# └── Main (VBoxContainer)
#     ├── EnemiesRow       (HBoxContainer)  ← barres HP ennemis
#     ├── HeroesRow        (HBoxContainer)  ← barres HP héros
#     └── ActionPanel      (VBoxContainer)
#         ├── HeroLabel    (Label)          ← "Tour de X"
#         ├── SpellButtons (HBoxContainer)  ← boutons sorts
#         └── StatusLabel  (Label)          ← "Choisissez une cible…"

@onready var enemies_row: HBoxContainer   = %EnemiesRow
@onready var heroes_row: HBoxContainer    = %HeroesRow
@onready var hero_label: Label            = %HeroLabel
@onready var spell_buttons: HBoxContainer = %SpellButtons
@onready var status_label: Label          = %StatusLabel

var _manager: CombatManager = null
var _pending_spell_index: int = -1
var _pending_spell_meta: Dictionary = {}
var _selected_targets: Array[BattleUnit] = []
var _needed_enemies: int = 0
var _needed_allies: int = 0

# Références aux unit cards pour les rendre cliquables
var _enemy_cards: Array = []
var _hero_cards: Array = []


func setup(manager: CombatManager) -> void:
	_manager = manager
	_set_action_panel_visible(false)
	_manager.hero_action_requested.connect(_on_hero_action_requested)
	_manager.target_selection_requested.connect(_on_target_selection_requested)
	_manager.state_changed.connect(_on_state_changed)
	_manager.combat_ended.connect(_on_combat_ended)
	_manager.turn_started.connect(_on_turn_started)


func build_cards() -> void:
	_build_unit_cards()


func _build_unit_cards() -> void:
	for child in enemies_row.get_children():
		child.queue_free()
	for child in heroes_row.get_children():
		child.queue_free()
	_enemy_cards.clear()
	_hero_cards.clear()

	for enemy in _manager.enemies:
		var card := _make_unit_card(enemy.battle_unit, true)
		enemies_row.add_child(card)
		_enemy_cards.append(card)

	for hero in _manager.heroes:
		var card := _make_unit_card(hero.battle_unit, false)
		heroes_row.add_child(card)
		_hero_cards.append(card)


func _make_unit_card(unit: BattleUnit, is_enemy: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(120, 80)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	var name_label := Label.new()
	name_label.text = unit.unit_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	var hp_bar := ProgressBar.new()
	hp_bar.min_value = 0
	hp_bar.max_value = unit.hp_max
	hp_bar.value = unit.hp
	hp_bar.name = "HPBar"
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hp_bar)

	var hp_label := Label.new()
	hp_label.text = "%d / %d" % [unit.hp, unit.hp_max]
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.name = "HPLabel"
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hp_label)

	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton \
				and event.button_index == MOUSE_BUTTON_LEFT \
				and event.pressed:
			_on_unit_card_pressed(unit)
	)

	# Réagit aux changements de HP
	unit.hp_changed.connect(func(cur, _max):
		hp_bar.value = cur
		hp_label.text = "%d / %d" % [cur, _max]
		if not unit.is_alive():
			panel.modulate = Color(0.4, 0.4, 0.4)
	)

	return panel


# -- Callbacks manager --

func _on_hero_action_requested(hero: HeroBase) -> void:
	hero_label.text = "Tour de " + hero.data.hero_name
	status_label.text = "Choisissez un sort"
	_build_spell_buttons(hero)
	_set_action_panel_visible(true)
	_set_cards_selectable(false, false)


func _on_target_selection_requested(hero: HeroBase, spell_index: int, spell_meta: Dictionary) -> void:
	_pending_spell_index = spell_index
	_pending_spell_meta = spell_meta
	_selected_targets.clear()
	var t: Dictionary = spell_meta.get("targets", {"enemies": 1, "allies": 0})
	_needed_enemies = t.get("enemies", 0)
	_needed_allies = t.get("allies", 0)
	status_label.text = _targeting_hint()
	_set_cards_selectable(_needed_enemies > 0, _needed_allies > 0)


func _on_state_changed(new_state: CombatManager.State) -> void:
	match new_state:
		CombatManager.State.ENEMY_TURN:
			_set_action_panel_visible(false)
			_set_cards_selectable(false, false)
			status_label.text = "Tour des ennemis…"
		CombatManager.State.RESOLVING:
			_set_cards_selectable(false, false)


func _on_turn_started(_unit: BattleUnit) -> void:
	pass


func _on_combat_ended(victory: bool) -> void:
	_set_action_panel_visible(false)
	_set_cards_selectable(false, false)
	hero_label.text = "Victoire !" if victory else "Défaite…"
	status_label.text = ""


# -- Construction des boutons de sorts --

func _build_spell_buttons(hero: HeroBase) -> void:
	for child in spell_buttons.get_children():
		child.queue_free()

	var spells := hero.get_spells()
	for i in spells.size():
		var spell: Dictionary = spells[i]
		var btn := Button.new()
		var cd := hero.battle_unit.get_cooldown(str(i))
		if cd > 0:
			btn.text = "%s (CD: %d)" % [spell["name"], cd]
			btn.disabled = true
		else:
			btn.text = spell["name"]
		btn.tooltip_text = spell.get("description", "")
		btn.pressed.connect(_on_spell_button_pressed.bind(i))
		spell_buttons.add_child(btn)


func _on_spell_button_pressed(index: int) -> void:
	_manager.on_spell_selected(index)


# -- Sélection de cibles --

func _on_unit_card_pressed(unit: BattleUnit) -> void:
	if _manager.state != CombatManager.State.WAITING_TARGET:
		return
	if not unit.is_alive():
		return

	if _selected_targets.has(unit):
		_selected_targets.erase(unit)
	else:
		_selected_targets.append(unit)

	# Vérifie si on a assez de cibles
	var enemy_count := _selected_targets.filter(func(u): return not u.is_hero).size()
	var ally_count  := _selected_targets.filter(func(u): return u.is_hero).size()

	var enemies_ok := _needed_enemies <= 0 or enemy_count >= _needed_enemies
	var allies_ok  := _needed_allies  <= 0 or ally_count  >= _needed_allies

	if enemies_ok and allies_ok:
		_manager.on_targets_selected(_selected_targets)
		_set_cards_selectable(false, false)


func _set_cards_selectable(p_enemies: bool, p_allies: bool) -> void:
	for card in _enemy_cards:
		var panel := card as PanelContainer
		if panel and panel.modulate != Color(0.4, 0.4, 0.4):
			panel.modulate = Color(1.3, 1.1, 0.5) if p_enemies else Color.WHITE
	for card in _hero_cards:
		var panel := card as PanelContainer
		if panel and panel.modulate != Color(0.4, 0.4, 0.4):
			panel.modulate = Color(0.5, 1.3, 0.5) if p_allies else Color.WHITE


func _set_action_panel_visible(visible: bool) -> void:
	spell_buttons.visible = visible


func _targeting_hint() -> String:
	var parts: Array[String] = []
	if _needed_enemies > 0:
		parts.append("%d ennemi(s)" % _needed_enemies)
	if _needed_allies > 0:
		parts.append("%d allié(s)" % _needed_allies)
	return "Choisissez : " + ", ".join(parts)
