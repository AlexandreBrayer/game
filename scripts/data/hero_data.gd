class_name HeroData
extends Resource

@export var hero_name: String = ""
@export_multiline var hero_description: String = ""
@export var hero_icon: Texture2D

@export_group("Base Stats")
@export var base_hp: int = 100
@export var base_atk: int = 10
@export var base_vit: int = 10
@export var base_shield: int = 0
@export var base_crit: float = 0.05
@export var base_heal: int = 0

@export_group("Spells")
@export var spells: Array[SpellData] = []
