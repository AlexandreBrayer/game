extends Node

# Noeud racine de la scène de combat.
# Récupère les héros et ennemis présents dans la scène,
# injecte le CombatManager dans le HUD, puis démarre.

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

	combat_hud.setup(combat_manager)
	combat_manager.start_combat(heroes, enemies)
	combat_hud.build_cards()
