@tool
class_name CappelloLogo
extends Control

# --- stile fisso ---
const NERO := Color("0d0d0d")
const BIANCO := Color("ffffff")
const GRIGIO_BORDO := Color("6b6b6b")

# --- stesso font delle banconote ---
const FONT_PATH := "res://fonts/Traptur.otf"

@export var testo := "COIN":
	set(v):
		testo = v
		queue_redraw()

@export var larghezza := 56.0:
	set(v):
		larghezza = maxf(v, 1.0)
		_aggiorna_dimensione()

@export var altezza := 40.0:
	set(v):
		altezza = maxf(v, 1.0)
		_aggiorna_dimensione()

var _font: Font

func _ready() -> void:
	_carica_font()
	_aggiorna_dimensione()

# --- metodi ---
func imposta_testo(t: String) -> void:
	testo = t

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

# --- disegno ---
func _draw() -> void:
	if _font == null:
		_carica_font()
	var w := larghezza
	var h := altezza

	# calotta (semi-ellisse)
	var dcx := w * 0.40
	var rx := w * 0.36
	var ry := h * 0.58
	var by := h * 0.72
	var calotta := PackedVector2Array()
	for k in 33:
		var a := PI + PI * k / 32.0
		calotta.append(Vector2(dcx + cos(a) * rx, by + sin(a) * ry))

	# visiera
	var visiera := PackedVector2Array([
		Vector2(dcx + rx * 0.1, by - h * 0.02),
		Vector2(w * 0.97, by + h * 0.05),
		Vector2(w * 0.92, by + h * 0.16),
		Vector2(dcx + rx * 0.1, by + h * 0.13),
	])
	draw_colored_polygon(visiera, NERO)
	var vis_bordo := visiera.duplicate()
	vis_bordo.append(vis_bordo[0])
	draw_polyline(vis_bordo, BIANCO, 1.5, true)

	# fascia sotto la calotta
	var fascia := Rect2(dcx - rx, by, rx * 2.0, h * 0.13)
	draw_rect(fascia, NERO)
	draw_rect(fascia, BIANCO, false, 1.5)

	# calotta + bordo
	draw_colored_polygon(calotta, NERO)
	var cal_bordo := calotta.duplicate()
	cal_bordo.append(cal_bordo[0])
	draw_polyline(cal_bordo, BIANCO, 1.5, true)

	# cucitura centrale + bottoncino
	draw_line(Vector2(dcx, by - ry), Vector2(dcx, by), GRIGIO_BORDO, 1.0, true)
	draw_circle(Vector2(dcx, by - ry), maxf(h * 0.04, 1.5), BIANCO)

	# scritta sulla calotta, si rimpicciolisce da sola se non ci sta
	var fs := int(h * 0.30)
	var max_w := rx * 1.4
	var dim := _font.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	while dim.x > max_w and fs > 6:
		fs -= 1
		dim = _font.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var cy_testo := by - ry * 0.42
	var base_y := cy_testo + (_font.get_ascent(fs) - _font.get_descent(fs)) / 2.0
	draw_string(_font, Vector2(dcx - dim.x / 2.0, base_y), testo,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, BIANCO)
