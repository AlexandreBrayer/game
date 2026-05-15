class_name EnemyData
extends Resource

@export var enemy_name: String = ""
@export_multiline var enemy_description: String = ""
@export var sprite_texture: Texture2D

@export_group("Base Stats")
@export var base_hp: int = 100
@export var base_atk: int = 10
@export var base_vit: int = 10
@export var base_shield: int = 0
@export var base_crit: float = 0.0
