@tool
class_name TimbroRank
extends Control

# --- stile fisso ---
const INCHIOSTRO := Color("e63946")
const GRIGIO := Color("6b6b6b")

# --- stesso font del resto ---
const FONT_PATH := "res://fonts/Traptur.otf"

@export var rank := "S":  # S, A, B, C, D ("" = non classificato)
	set(v):
		rank = v.to_upper().substr(0, 2)
		queue_redraw()

@export var testo_alto := "DARK POINT":
	set(v):
		testo_alto = v
		queue_redraw()

@export var testo_basso := "OFFICIAL RANK":
	set(v):
		testo_basso = v
		queue_redraw()

@export var larghezza := 112.0:
	set(v):
		larghezza = maxf(v, 32.0)
		_aggiorna_dimensione()

@export var altezza := 64.0:
	set(v):
		altezza = maxf(v, 24.0)
		_aggiorna_dimensione()

@export_range(-45.0, 45.0, 0.5) var inclinazione := -8.0:
	set(v):
		inclinazione = v
		queue_redraw()

var _font: Font

func _ready() -> void:
	_carica_font()
	_aggiorna_dimensione()

# --- metodi ---
func imposta_rank(r: String) -> void:
	rank = r

# comodo per collegarlo alla precisione del giocatore (0..100)
static func rank_da_percentuale(p: float) -> String:
	if p >= 95.0: return "S"
	if p >= 85.0: return "A"
	if p >= 70.0: return "B"
	if p >= 50.0: return "C"
	return "D"

# --- utility ---
func _carica_font() -> void:
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	else:
		_font = ThemeDB.fallback_font
	queue_redraw()

func _aggiorna_dimensione() -> void:
	custom_minimum_size = Vector2(larghezza, altezza)
	size = custom_minimum_size
	queue_redraw()

func _stella(centro: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + k * PI / 5.0
		var rr := r if k % 2 == 0 else r * 0.42
		pts.append(centro + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)

# testo centrato in x su 0, a metà altezza cy, si rimpicciolisce se non ci sta
func _testo_centrato(txt: String, cy: float, fs: int, max_w: float, col: Color) -> void:
	if txt.is_empty():
		return
	var dim := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	while dim.x > max_w and fs > 5:
		fs -= 1
		dim = _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var base_y := cy + (_font.get_ascent(fs) - _font.get_descent(fs)) / 2.0
	draw_string(_font, Vector2(-dim.x / 2.0, base_y), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

# --- disegno ---
func _draw() -> void:
	if _font == null:
		_carica_font()

	var col := INCHIOSTRO if rank != "" else GRIGIO
	draw_set_transform_matrix(Transform2D(deg_to_rad(inclinazione), size / 2.0))

	var w := larghezza - 4.0
	var h := altezza - 4.0
	var sp := maxf(h * 0.06, 2.0)  # distanza tra cornice esterna e interna
	var banda := h * 0.20

	# doppia cornice
	draw_rect(Rect2(-w / 2.0, -h / 2.0, w, h), col, false, maxf(h * 0.045, 2.0))
	draw_rect(Rect2(-w / 2.0 + sp, -h / 2.0 + sp, w - sp * 2.0, h - sp * 2.0),
			col, false, 1.0)

	# linee che separano le bande dal centro
	var y_alto := -h / 2.0 + sp + banda
	var y_basso := h / 2.0 - sp - banda
	draw_line(Vector2(-w / 2.0 + sp, y_alto), Vector2(w / 2.0 - sp, y_alto), col, 1.0)
	draw_line(Vector2(-w / 2.0 + sp, y_basso), Vector2(w / 2.0 - sp, y_basso), col, 1.0)

	# scritte nelle bande
	var fs := int(banda * 0.62)
	var max_w := w - sp * 4.0
	_testo_centrato(testo_alto, -h / 2.0 + sp + banda / 2.0, fs, max_w, col)
	_testo_centrato(testo_basso, h / 2.0 - sp - banda / 2.0, fs, max_w, col)

	# centro: lettera del rank + stelle sui lati
	var alt_centro := y_basso - y_alto
	var txt := rank if rank != "" else "-"
	var fs_r := int(alt_centro * (0.95 if txt.length() == 1 else 0.70))
	_testo_centrato(txt, 0.0, fs_r, w * 0.4, col)
	_stella(Vector2(-w * 0.34, 0), alt_centro * 0.16, col)
	_stella(Vector2(w * 0.34, 0), alt_centro * 0.16, col)

	draw_set_transform_matrix(Transform2D.IDENTITY)  # reset
