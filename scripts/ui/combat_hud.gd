class_name CombatHUD
extends CanvasLayer

const SpellButtonScene := preload("res://scenes/ui/hud/SpellButton.tscn")

@onready var hero_label: Label            = %HeroLabel
@onready var spell_buttons: GridContainer = %SpellButtons
@onready var spell_panel: PanelContainer  = %SpellPanel
@onready var status_label: Label          = %StatusLabel
@onready var log_scroll: ScrollContainer  = %LogScroll
@onready var log_list: VBoxContainer      = %LogList

var _manager: CombatManager = null
var _pending_spell_index: int = -1
var _pending_spell_meta: Dictionary = {}
var _selected_targets: Array[BattleUnit] = []
var _needed_enemies: int = 0
var _needed_allies: int  = 0
var _current_hero: HeroBase = null
var _targeting_item: UsableItem = null


func setup(manager: CombatManager) -> void:
	_manager = manager
	_set_action_panel_visible(false)
	CombatLog.entry_added.connect(_on_log_entry)
	_manager.hero_action_requested.connect(_on_hero_action_requested)
	_manager.target_selection_requested.connect(_on_target_selection_requested)
	_manager.state_changed.connect(_on_state_changed)
	_manager.combat_ended.connect(_on_combat_ended)
	_manager.turn_started.connect(_on_turn_started)
	_manager.item_menu_requested.connect(_on_item_menu_requested)
	_manager.item_target_requested.connect(_on_item_target_requested)


func _on_log_entry(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	log_list.add_child(lbl)
	# scroll vers le bas au prochain frame
	await get_tree().process_frame
	log_scroll.scroll_vertical = int(log_scroll.get_v_scroll_bar().max_value)


func build_cards() -> void:
	# Branche les clics monde sur les unités au lieu de cartes UI
	for hero in _manager.heroes:
		hero.unit_clicked.connect(_on_unit_card_pressed)
	for enemy in _manager.enemies:
		enemy.unit_clicked.connect(_on_unit_card_pressed)


# -- Callbacks manager --

func _on_hero_action_requested(hero: HeroBase) -> void:
	_current_hero = hero
	hero_label.text = "Tour de " + hero.data.hero_name
	status_label.text = "Choisissez un sort"
	_build_spell_buttons(hero)
	_set_action_panel_visible(true)
	_set_units_selectable(false, false)


func _on_target_selection_requested(hero: HeroBase, spell_index: int, spell_meta: Dictionary) -> void:
	_pending_spell_index = spell_index
	_pending_spell_meta = spell_meta
	_selected_targets.clear()
	var t: Dictionary = spell_meta.get("targets", {"enemies": 1, "allies": 0})
	_needed_enemies = t.get("enemies", 0)
	_needed_allies = t.get("allies", 0)
	status_label.text = _targeting_hint()
	_set_units_selectable(_needed_enemies > 0, _needed_allies > 0)


func _on_state_changed(new_state: CombatManager.State) -> void:
	match new_state:
		CombatManager.State.ENEMY_TURN:
			_set_action_panel_visible(false)
			_set_units_selectable(false, false)
			status_label.text = "Tour des ennemis…"
		CombatManager.State.RESOLVING:
			_set_units_selectable(false, false)


func _on_turn_started(unit: BattleUnit) -> void:
	for hero in _manager.heroes:
		hero.set_highlighted(false)
	for enemy in _manager.enemies:
		enemy.set_highlighted(false)
	if unit.source_node and unit.source_node.has_method("set_highlighted"):
		unit.source_node.set_highlighted(true)


func _on_combat_ended(victory: bool) -> void:
	_set_action_panel_visible(false)
	_set_units_selectable(false, false)
	hero_label.text = "Victoire !" if victory else "Défaite…"
	status_label.text = ""


# -- Construction des boutons de sorts --

func _build_spell_buttons(hero: HeroBase) -> void:
	for child in spell_buttons.get_children():
		child.queue_free()

	# Bouton objets si l'inventaire n'est pas vide
	if not _manager.inventory.is_empty():
		var item_btn: Button = SpellButtonScene.instantiate()
		item_btn.text = "Objets"
		item_btn.pressed.connect(func(): _manager.on_item_menu_opened())
		spell_buttons.add_child(item_btn)

	var spells := hero.get_spells()
	for i in spells.size():
		var spell: Dictionary = spells[i]
		var btn: Button = SpellButtonScene.instantiate()
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


# -- Objets --

func _on_item_menu_requested(_hero: HeroBase) -> void:
	_build_item_buttons()


func _build_item_buttons() -> void:
	for child in spell_buttons.get_children():
		child.queue_free()

	# Bouton retour
	var back_btn: Button = SpellButtonScene.instantiate()
	back_btn.text = "<- Sorts"
	back_btn.pressed.connect(func(): _build_spell_buttons(_current_hero))
	spell_buttons.add_child(back_btn)

	for item in _manager.inventory:
		if item.uses == 0:
			continue
		var btn: Button = SpellButtonScene.instantiate()
		btn.text = item.item_name if item.uses < 0 else "%s (%d)" % [item.item_name, item.uses]
		btn.tooltip_text = item.description
		btn.pressed.connect(_on_item_button_pressed.bind(item))
		spell_buttons.add_child(btn)



func _on_item_button_pressed(item: UsableItem) -> void:
	_manager.on_item_selected(item)


func _on_item_target_requested(_hero: HeroBase, item: UsableItem) -> void:
	_targeting_item = item
	_selected_targets.clear()
	var t: Dictionary = item.targets
	_needed_enemies = t.get("enemies", 0)
	_needed_allies  = t.get("allies", 0)
	status_label.text = "Cible pour " + item.item_name
	_set_units_selectable(_needed_enemies > 0, _needed_allies > 0)


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
		if _targeting_item != null:
			_manager.on_item_targets_selected(_selected_targets)
			_targeting_item = null
		else:
			_manager.on_targets_selected(_selected_targets)
		_set_units_selectable(false, false)


func _set_units_selectable(p_enemies: bool, p_allies: bool) -> void:
	for hero in _manager.heroes:
		hero.set_selectable(p_allies)
	for enemy in _manager.enemies:
		enemy.set_selectable(p_enemies)


func _set_action_panel_visible(visible: bool) -> void:
	spell_panel.visible = visible


func _targeting_hint() -> String:
	var parts: Array[String] = []
	if _needed_enemies > 0:
		parts.append("%d ennemi(s)" % _needed_enemies)
	if _needed_allies > 0:
		parts.append("%d allié(s)" % _needed_allies)
	return "Choisissez : " + ", ".join(parts)
