class_name UnitOverlay
extends Node2D

# Affiche la barre de vie + nom + buffs/débuffs d'une unité en espace monde,
# positionné au-dessus du sprite par le parent.

const BAR_WIDTH  := 80.0
const BAR_HEIGHT := 10.0
const BUFF_FONT_SIZE := 11
const BUFF_TAG_PAD_X := 4.0
const BUFF_TAG_PAD_Y := 2.0
const BUFF_LINE_GAP  := 2.0
const BUFF_COLORS := {
	"attack_up": Color(0.6, 1.0, 0.6),
	"attack_down": Color(1.0, 0.5, 0.5),
	"shield": Color(0.4, 0.7, 1.0),
	"status": Color(1.0, 0.85, 0.4),
}

var _hp: int     = 0
var _hp_max: int = 1
var _label: String = ""
var _unit: BattleUnit = null


func setup(unit: BattleUnit) -> void:
	_unit = unit
	_hp     = unit.hp
	_hp_max = unit.hp_max
	_label  = unit.unit_name
	unit.hp_changed.connect(_on_hp_changed)
	unit.shield_changed.connect(func(_val): queue_redraw())
	unit.died.connect(queue_redraw)
	unit.buffs_changed.connect(queue_redraw)
	queue_redraw()


func _on_hp_changed(current: int, maximum: int) -> void:
	_hp     = current
	_hp_max = maximum
	queue_redraw()


func _draw() -> void:
	if _unit == null:
		return

	var font      := ThemeDB.fallback_font
	var font_size := 14

	# --- Buffs / Debuffs : lignes de pastilles au-dessus du nom ---
	var buff_lines: Array[Array] = _build_buff_lines(font, font_size)
	var buff_area_height := 0.0
	if not buff_lines.is_empty():
		for line in buff_lines:
			buff_area_height += BUFF_TAG_PAD_Y * 2.0 + BUFF_FONT_SIZE
		buff_area_height += (buff_lines.size() - 1) * BUFF_LINE_GAP

	var name_y := -BAR_HEIGHT - 4.0 - buff_area_height
	var buff_y := name_y

	# Dessiner chaque ligne de pastilles
	for line in buff_lines:
		var x := 0.0
		for tag in line:
			var tag_text: String = tag[0]
			var tag_color: Color = tag[1]
			var tag_w := font.get_string_size(tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, BUFF_FONT_SIZE).x + BUFF_TAG_PAD_X * 2.0
			var tag_h := BUFF_FONT_SIZE + BUFF_TAG_PAD_Y * 2.0

			# Fond de la pastille
			var bg := Color(tag_color.r * 0.15, tag_color.g * 0.15, tag_color.b * 0.15, 0.85)
			draw_rect(Rect2(x - tag_w / 2.0, buff_y, tag_w, tag_h), bg)
			# Bordure subtile
			draw_rect(Rect2(x - tag_w / 2.0, buff_y, tag_w, tag_h),
					Color(tag_color.r * 0.5, tag_color.g * 0.5, tag_color.b * 0.5, 0.6), false, 1.0)
			# Texte
			draw_string(font, Vector2(x - tag_w / 2.0 + BUFF_TAG_PAD_X, buff_y + BUFF_FONT_SIZE + BUFF_TAG_PAD_Y - 1.0),
					tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, BUFF_FONT_SIZE, tag_color)
			x += tag_w + 4.0

		buff_y += BUFF_TAG_PAD_Y * 2.0 + BUFF_FONT_SIZE + BUFF_LINE_GAP

	# Nom centré au-dessus de la barre
	var text_w := font.get_string_size(_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(-text_w / 2.0, name_y), _label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

	# Barre de vie
	_draw_hp_bar(font)

	# Indicateur de shield dans la HP bar
	if _unit.shield > 0:
		var shield_text := "🛡%d" % _unit.shield
		var sw := font.get_string_size(shield_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		draw_string(font, Vector2(BAR_WIDTH / 2.0 - sw - 2.0, BUFF_FONT_SIZE + BUFF_TAG_PAD_Y - 1.0),
				shield_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, BUFF_COLORS["shield"])


func _draw_hp_bar(font: Font) -> void:
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

	# Texte des HP dans la barre
	var hp_text := "%d/%d" % [_hp, _hp_max]
	var font_size := 9
	var tw := font.get_string_size(hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(-tw / 2.0, BAR_HEIGHT - 2.0),
			hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


# Construit une liste de lignes, chaque ligne étant une liste de [texte, couleur]
func _build_buff_lines(font: Font, font_size: int) -> Array[Array]:
	var tags: Array[Array] = []  # [text, color]

	# --- Damage buffs ---
	for buff in _unit.damage_buffs:
		var parts: Array[String] = []
		if buff.get("flat", 0) != 0:
			var s: String = "+%d" % buff["flat"] if buff["flat"] > 0 else "%d" % buff["flat"]
			parts.append("ATK %s" % s)
		if buff.get("mult_bonus", 0.0) != 0.0:
			var m: float = 1.0 + buff.get("mult_bonus", 0.0)
			parts.append("x%.1f" % m)
		var turns: int = buff.get("turns", 0)
		parts.append("%dt" % turns)
		tags.append([" ".join(parts), BUFF_COLORS["attack_up"]])

	# --- Statuses ---
	for status_id in _unit.statuses:
		var s: Dictionary = _unit.statuses[status_id]
		var text: String = status_id
		if s.get("stacks", 1) > 1:
			text += " x%d" % s["stacks"]
		text += " (%dt)" % s["duration"]
		tags.append([text, BUFF_COLORS["status"]])

	if tags.is_empty():
		return []

	# Répartir les tags en lignes (max ~120px par ligne)
	var line_max_width := 140.0
	var lines: Array[Array] = [[]]
	var line_w := 0.0

	for tag in tags:
		var tag_w := font.get_string_size(tag[0], HORIZONTAL_ALIGNMENT_LEFT, -1, BUFF_FONT_SIZE).x + BUFF_TAG_PAD_X * 2.0 + 4.0
		if line_w + tag_w > line_max_width and not lines[-1].is_empty():
			lines.append([])
			line_w = 0.0
		lines[-1].append(tag)
		line_w += tag_w

	return lines
