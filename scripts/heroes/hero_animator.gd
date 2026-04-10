class_name HeroAnimator
extends Node

enum State {
	IDLE,
	ATTACK,
	CAST,
	HURT,
	DEATH,
	VICTORY,
}

@onready var hero: HeroBase = get_parent() as HeroBase
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _state: State = State.IDLE
var _anim_names := {
	State.IDLE:    "idle",
	State.ATTACK:  "attack",
	State.CAST:    "cast",
	State.HURT:    "hurt",
	State.DEATH:   "death",
	State.VICTORY: "victory",
}


func _ready() -> void:
	assert(animation_player != null, "HeroAnimator: AnimationPlayer manquant dans " + name)
	await owner.ready
	if hero and hero.battle_unit:
		hero.battle_unit.hp_changed.connect(_on_hp_changed)
		hero.battle_unit.died.connect(_on_died)
	play(State.IDLE)


func play(state: State) -> void:
	_state = state
	var anim: String = _anim_names.get(state, "idle")
	if animation_player.has_animation(anim):
		animation_player.play(anim)
	else:
		push_warning("HeroAnimator: animation '%s' introuvable sur %s" % [anim, hero.name if hero else name])


func play_attack(callback: Callable = Callable()) -> void:
	play(State.ATTACK)
	if callback.is_valid():
		await animation_player.animation_finished
		callback.call()
	play(State.IDLE)


func play_cast(callback: Callable = Callable()) -> void:
	play(State.CAST)
	if callback.is_valid():
		await animation_player.animation_finished
		callback.call()
	play(State.IDLE)


func _on_hp_changed(current: int, _maximum: int) -> void:
	if current > 0 and _state != State.DEATH:
		play(State.HURT)
		await animation_player.animation_finished
		if _state == State.HURT:
			play(State.IDLE)


func _on_died() -> void:
	play(State.DEATH)
