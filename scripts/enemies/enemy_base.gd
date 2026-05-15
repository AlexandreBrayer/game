class_name EnemyBase
extends Node2D

signal passive_triggered(passive_id: String)
signal damage_received(amount: int, attacker: BattleUnit)
signal action_used(action_name: String)
signal unit_clicked(unit: BattleUnit)

@export var data: EnemyData

var battle_unit: BattleUnit = null
var sprite: Sprite2D = null
var _is_highlighted: bool = false
var _is_selectable: bool  = false
var _glow_phase: float    = 0.0


func _ready() -> void:
	assert(data != null, "EnemyBase: data (EnemyData) must be set on " + name)
	battle_unit = _create_battle_unit()
	_setup_sprite()
	_setup_visual()


func _setup_sprite() -> void:
	if has_node("Sprite2D"):
		sprite = $Sprite2D as Sprite2D
	else:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	if data.sprite_texture:
		sprite.texture = data.sprite_texture
	else:
		sprite.texture = _make_placeholder(Color(1.0, 0.35, 0.3))
	sprite.flip_h = true


func _make_placeholder(color: Color) -> ImageTexture:
	var img := Image.create(64, 128, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


func _setup_visual() -> void:
	var half_h := sprite.texture.get_height() / 2.0 if sprite.texture else 64.0
	var overlay := UnitOverlay.new()
	overlay.position = Vector2(0.0, -half_h - 18.0)
	overlay.z_index = 5
	add_child(overlay)
	overlay.setup(battle_unit)


func set_highlighted(value: bool) -> void:
	_is_highlighted = value
	_glow_phase = 0.0


func set_selectable(value: bool) -> void:
	_is_selectable = value


func _process(delta: float) -> void:
	if sprite == null:
		return
	if battle_unit == null or not battle_unit.is_alive():
		sprite.modulate = Color(0.4, 0.4, 0.4, 1.0)
		return
	if _is_highlighted:
		_glow_phase += delta * 4.0
		var t := (sin(_glow_phase) + 1.0) / 2.0
		sprite.modulate = Color(0.5 + t * 0.2, 0.72 + t * 0.1, 1.0 + t * 0.4, 1.0)
	elif _is_selectable:
		sprite.modulate = Color(1.3, 1.2, 0.45, 1.0)
	else:
		sprite.modulate = Color.WHITE


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed):
		return
	if sprite == null or sprite.texture == null:
		return
	var mouse_local := to_local(get_global_mouse_position())
	var hw := sprite.texture.get_width()  / 2.0
	var hh := sprite.texture.get_height() / 2.0
	if Rect2(-hw, -hh, hw * 2.0, hh * 2.0).has_point(mouse_local):
		unit_clicked.emit(battle_unit)
		get_viewport().set_input_as_handled()


func _create_battle_unit() -> BattleUnit:
	var unit := BattleUnit.new()
	unit.unit_name = data.enemy_name
	unit.is_hero = false
	unit.hp_max = data.base_hp
	unit.hp = data.base_hp
	unit.atk = data.base_atk
	unit.vit = data.base_vit
	unit.crit = data.base_crit
	unit.shield = data.base_shield
	unit.source_node = self
	return unit


# Point d'entrée des dégâts (même convention que HeroBase)
func take_damage(amount: int, attacker: BattleUnit = null) -> int:
	var current := amount
	for p in battle_unit.passives:
		current = p.on_take_damage(battle_unit, current, attacker)
	_cleanup_passives()
	if current > 0:
		var received := battle_unit.apply_damage(current)
		if received > 0:
			damage_received.emit(received, attacker)
			on_damaged(received)
		return received
	return 0


# -- Hooks de passifs --

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

func on_damaged(_amount: int) -> void:
	pass

func on_kill(_target: BattleUnit) -> void:
	pass

func on_battle_end(_victory: bool) -> void:
	pass


# Utilitaire : attaque via la chaîne passive (comme HeroBase.deal_damage)
func deal_damage(target: BattleUnit, amount: int) -> void:
	var final_amount := battle_unit.compute_outgoing_damage(amount)
	if target.source_node != null and target.source_node.has_method("take_damage"):
		target.source_node.take_damage(final_amount, battle_unit)
	else:
		target.apply_damage(final_amount)
	if not target.is_alive():
		on_kill(target)


# IA : liste des actions disponibles (à override)
# Chaque dict : { "name": String, "targets": int }
#   targets == -1  → toutes les cibles
#   targets > 0   → N cibles au choix (random)
func get_actions() -> Array[Dictionary]:
	return [{"name": "Attaque", "targets": 1}]


# IA : choisit aléatoirement parmi les actions non en cooldown
func choose_action(_heroes: Array) -> int:
	var actions := get_actions()
	var available: Array[int] = []
	for i in actions.size():
		if battle_unit.get_cooldown(str(i)) <= 0:
			available.append(i)
	if available.is_empty():
		return 0
	return available[randi() % available.size()]


# À override dans chaque ennemi ; heroes = cibles déjà filtrées par CombatManager
func cast_action(index: int, _heroes: Array) -> void:
	var actions := get_actions()
	var action_name: String = actions[index]["name"] if index < actions.size() else "Attaque"
	action_used.emit(action_name)


func _cleanup_passives() -> void:
	var i := battle_unit.passives.size() - 1
	while i >= 0:
		if battle_unit.passives[i].consumed:
			battle_unit.passives.remove_at(i)
		i -= 1
