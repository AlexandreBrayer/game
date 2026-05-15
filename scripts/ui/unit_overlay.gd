class_name UnitOverlay
extends Node2D

# Affiche la barre de vie + nom d'une unité en espace monde,
# positionné au-dessus du sprite par le parent.

const BAR_WIDTH  := 80.0
const BAR_HEIGHT := 10.0

var _hp: int     = 0
var _hp_max: int = 1
var _label: String = ""


func setup(unit: BattleUnit) -> void:
	_hp     = unit.hp
	_hp_max = unit.hp_max
	_label  = unit.unit_name
	unit.hp_changed.connect(_on_hp_changed)
	unit.died.connect(queue_redraw)
	queue_redraw()


func _on_hp_changed(current: int, maximum: int) -> void:
	_hp     = current
	_hp_max = maximum
	queue_redraw()


func _draw() -> void:
	var font      := ThemeDB.fallback_font
	var font_size := 14

	# Nom centré au-dessus de la barre
	var text_w := font.get_string_size(_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(-text_w / 2.0, -BAR_HEIGHT - 4.0), _label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

	# Fond de barre
	draw_rect(Rect2(-BAR_WIDTH / 2.0, 0.0, BAR_WIDTH, BAR_HEIGHT),
			Color(0.12, 0.12, 0.12, 0.85))

	# Remplissage HP avec couleur dynamique
	var ratio := clampf(float(_hp) / float(_hp_max), 0.0, 1.0) if _hp_max > 0 else 0.0
	var hp_color: Color
	if ratio > 0.5:
		hp_color = Color(0.22, 0.82, 0.3)
	elif ratio > 0.25:
		hp_color = Color(0.95, 0.72, 0.1)
	else:
		hp_color = Color(0.9, 0.22, 0.18)
	if ratio > 0.0:
		draw_rect(Rect2(-BAR_WIDTH / 2.0, 0.0, BAR_WIDTH * ratio, BAR_HEIGHT), hp_color)

	# Bordure
	draw_rect(Rect2(-BAR_WIDTH / 2.0, 0.0, BAR_WIDTH, BAR_HEIGHT),
			Color(1.0, 1.0, 1.0, 0.8), false, 1.0)
