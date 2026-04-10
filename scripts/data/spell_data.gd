class_name SpellData
extends Resource

enum TargetType {
	SINGLE_ENEMY,
	ALL_ENEMIES,
	SINGLE_ALLY,
	ALL_ALLIES,
	SELF,
}

enum SpellType {
	DAMAGE,
	HEAL,
	SHIELD,
	BUFF,
	DEBUFF,
	AFFLICTION,
}

@export var spell_name: String = ""
@export_multiline var spell_description: String = ""
@export var spell_icon: Texture2D

@export_group("Combat")
@export var spell_type: SpellType = SpellType.DAMAGE
@export var target_type: TargetType = TargetType.SINGLE_ENEMY
@export var base_power: float = 1.0
@export var cooldown_max: int = 0

@export_group("Status Effect")
@export var applies_status: String = ""
@export var status_duration: int = 0
@export var status_stacks: int = 1
