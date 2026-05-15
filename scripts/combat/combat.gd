extends Node

# Noeud racine de la scène de combat.
# Récupère les héros et ennemis présents dans la scène,
# injecte le CombatManager dans le HUD, puis démarre.

## Y de la ligne de combat (même pour les deux équipes)
@export var row_y: float = 600.0
## Espacement horizontal entre les unités d'une même équipe
@export var unit_spacing: float = 180.0
## Distance entre l'unité héros la plus proche et l'unité ennemie la plus proche
@export var team_gap: float = 400.0
## Centre horizontal de l'écran (point de référence entre les deux équipes)
@export var screen_center_x: float = 960.0

@onready var combat_manager: CombatManager = $CombatManager
@onready var combat_hud: CombatHUD         = $CombatHUD


func _ready() -> void:
	var heroes: Array[HeroBase] = []
	for child in $Heroes.get_children():
		if child is HeroBase:
			heroes.append(child)

	var enemies: Array[EnemyBase] = []
	for child in $Enemies.get_children():
		if child is EnemyBase:
			enemies.append(child)

	assert(heroes.size() > 0, "Combat: aucun héros trouvé dans $Heroes")
	assert(enemies.size() > 0, "Combat: aucun ennemi trouvé dans $Enemies")

	_position_heroes(heroes)
	_position_enemies(enemies)

	_populate_inventory()
	combat_hud.setup(combat_manager)
	combat_manager.start_combat(heroes, enemies)
	combat_hud.build_cards()


# Héros alignés horizontalement, le dernier (index le plus haut) le plus proche du centre.
func _position_heroes(heroes: Array) -> void:
	var count := heroes.size()
	for i in count:
		var x := screen_center_x - team_gap / 2.0 - (count - 1 - i) * unit_spacing
		heroes[i].position = Vector2(x, row_y)


# Ennemis alignés horizontalement, le premier (index 0) le plus proche du centre.
func _position_enemies(enemies: Array) -> void:
	var count := enemies.size()
	for i in count:
		var x := screen_center_x + team_gap / 2.0 + i * unit_spacing
		enemies[i].position = Vector2(x, row_y)


func _populate_inventory() -> void:
	# -- Potion de soin (x3) --
	var potion := ItemHeal.new()
	potion.item_name  = "Potion"
	potion.description = "Restaure 40 PV à un allié."
	potion.heal_amount = 40
	potion.uses        = 3
	potion.targets     = {"enemies": 0, "allies": 1}
	combat_manager.inventory.append(potion)

	# -- Grande Potion (x1) --
	var grande := ItemHeal.new()
	grande.item_name   = "Grande Potion"
	grande.description = "Restaure 100 PV à un allié."
	grande.heal_amount = 100
	grande.uses        = 1
	grande.targets     = {"enemies": 0, "allies": 1}
	combat_manager.inventory.append(grande)

	# -- Elixir de Force (x2) : +20 dégâts fixes pendant 3 tours --
	var elixir := ItemDamageBoost.new()
	elixir.item_name    = "Elixir de Force"
	elixir.description  = "Confère +20 dégâts fixes pendant 3 tours."
	elixir.flat_bonus   = 20
	elixir.mult_bonus   = 0.0
	elixir.duration_turns = 3
	elixir.uses         = 2
	elixir.targets      = {"enemies": 0, "allies": 1}
	combat_manager.inventory.append(elixir)

	# -- Berserk (x1) : +50 % dégâts pendant 2 tours --
	var berserk := ItemDamageBoost.new()
	berserk.item_name     = "Rage Berserk"
	berserk.description   = "Confère +50 % de dégâts pendant 2 tours."
	berserk.flat_bonus    = 0
	berserk.mult_bonus    = 0.5
	berserk.duration_turns = 2
	berserk.uses          = 1
	berserk.targets       = {"enemies": 0, "allies": 1}
	combat_manager.inventory.append(berserk)
