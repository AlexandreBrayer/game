class_name HeroBase
extends Node2D

signal spell_cast(spell_index: int, caster: BattleUnit)
signal status_applied(status_id: String, target: BattleUnit)
signal passive_triggered(passive_id: String)
signal damage_received(amount: int, attacker: BattleUnit)
signal unit_clicked(unit: BattleUnit)

@export var data: HeroData

var battle_unit: BattleUnit = null
var sprite: Sprite2D = null
var _is_highlighted: bool = false
var _is_selectable: bool  = false
var _glow_phase: float    = 0.0


func _ready() -> void:
	assert(data != null, "HeroBase: data (HeroData) must be set on " + name)
	battle_unit = BattleUnit.from_hero_data(data, self)
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
		sprite.texture = _make_placeholder(Color(0.3, 0.6, 1.0))


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


func create_battle_unit() -> BattleUnit:
	battle_unit = BattleUnit.from_hero_data(data, self)
	return battle_unit


# -- Hooks de passifs (à override dans les héros spécifiques) --

func on_battle_start() -> void:
	for p in battle_unit.passives:
		p.on_battle_start(battle_unit)
		if p.log_message != "":
			passive_triggered.emit(p.log_message)
			p.log_message = ""
	_cleanup_passives()

func on_turn_start() -> void:
	for p in battle_unit.passives:
		p.on_turn_start(battle_unit)
		if p.log_message != "":
			passive_triggered.emit(p.log_message)
			p.log_message = ""
	_cleanup_passives()

func on_turn_end() -> void:
	for p in battle_unit.passives:
		p.on_turn_end(battle_unit)
		if p.log_message != "":
			passive_triggered.emit(p.log_message)
			p.log_message = ""
	_cleanup_passives()

func on_damaged(_amount: int) -> void:
	pass

func on_healed(amount: int) -> void:
	for p in battle_unit.passives:
		p.on_healed(battle_unit, amount)
		if p.log_message != "":
			passive_triggered.emit(p.log_message)
			p.log_message = ""
	_cleanup_passives()

func on_kill(target: BattleUnit) -> void:
	for p in battle_unit.passives:
		p.on_kill(battle_unit, target)
		if p.log_message != "":
			passive_triggered.emit(p.log_message)
			p.log_message = ""
	_cleanup_passives()

func on_ally_died(ally: BattleUnit) -> void:
	for p in battle_unit.passives:
		p.on_ally_died(battle_unit, ally)
		if p.log_message != "":
			passive_triggered.emit(p.log_message)
			p.log_message = ""
	_cleanup_passives()

func on_battle_end(victory: bool) -> void:
	for p in battle_unit.passives:
		p.on_battle_end(battle_unit, victory)
		if p.log_message != "":
			passive_triggered.emit(p.log_message)
			p.log_message = ""
	_cleanup_passives()


# Point d'entrée des dégâts : le CombatManager appelle toujours cette méthode.
# Retourne les dégâts effectivement reçus (après passifs).
# attacker peut être null (dégâts de statut, etc.)
func take_damage(amount: int, attacker: BattleUnit = null) -> int:
	var current := amount
	for p in battle_unit.passives:
		current = p.on_take_damage(battle_unit, current, attacker)
		if p.log_message != "":
			passive_triggered.emit(p.log_message)
			p.log_message = ""
	_cleanup_passives()
	if current > 0:
		var received := battle_unit.apply_damage(current)
		if received > 0:
			damage_received.emit(received, attacker)
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
func cast_spell(_index: int, _targets: Array[BattleUnit]) -> void:
	pass


# Retourne true si le sort nécessite une sélection manuelle de cible
func spell_needs_targeting(index: int) -> bool:
	var spells := get_spells()
	if index < 0 or index >= spells.size():
		return false
	var t: Dictionary = spells[index].get("targets", {"enemies": 1, "allies": 0})
	return t.get("enemies", 0) > 0 or t.get("allies", 0) > 0
