@tool
class_name RombiRating
extends Control

signal cambiato(pieni: int)

# --- stile fisso ---
const NERO := Color("E63946")
const BIANCO := Color("ffffff")
const GRIGIO := Color("f6f6f600")
const GRIGIO_BORDO := Color("ffffff")

# --- font: metti qui il path del tuo font ---
const FONT_PATH := "res://fonts/Traptur.otf"

@export var lettera := "LEVEL":
	set(v):
		lettera = v.substr(0, 1)
		queue_redraw()

@export var totale := 5:
	set(v):
		totale = maxi(v, 1)
		pieni = pieni  # ri-clampa
		_aggiorna_dimensione()

@export var pieni := 0:
	set(v):
		pieni = clampi(v, 0, totale)
		queue_redraw()

@export var larghezza_rombo := 56.0:
	set(v):
		larghezza_rombo = maxf(v, 1.0)
		_aggiorna_dimensione()

@export var altezza_rombo := 32.0:
	set(v):
		altezza_rombo = maxf(v, 1.0)
		_aggiorna_dimensione()

@export var spazio := 10.0:
	set(v):
		spazio = maxf(v, 0.0)
		_aggiorna_dimensione()

var _font: Font

func _ready() -> void:
	_carica_font()
	_aggiorna_dimensione()

# --- metodi ---
func riempi(n: int) -> void:
	pieni = n
	cambiato.emit(pieni)

func svuota() -> void:
	riempi(0)

func riempi_tutti() -> void:
	riempi(totale)

func get_pieni() -> int:
	return pieni

func imposta_lettera(l: String) -> void:
	lettera = l

# --- utility ---
func _carica_font() -> void:
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	else:
		_font = ThemeDB.fallback_font  # se il path è sbagliato non crasha
	queue_redraw()

func _aggiorna_dimensione() -> void:
	var larghezza_tot := totale * larghezza_rombo + spazio * (totale - 1)
	custom_minimum_size = Vector2(larghezza_tot, altezza_rombo)
	size = custom_minimum_size
	queue_redraw()

func _rett(cx: float, cy: float, w: float, h: float) -> Rect2:
	return Rect2(cx - w / 2.0, cy - h / 2.0, w, h)

# --- disegno ---
func _draw() -> void:
	if _font == null:
		_carica_font()
	var w := larghezza_rombo
	var h := altezza_rombo
	for i in totale:
		var cx := i * (w + spazio) + w / 2.0
		var cy := h / 2.0
		if i < pieni:
			_disegna_card(cx, cy, w, h, NERO, NERO, BIANCO, BIANCO)
		else:
			_disegna_card(cx, cy, w, h, GRIGIO, GRIGIO_BORDO, NERO, NERO)

# stesso disegno per entrambe, cambiano solo i colori
func _disegna_card(cx: float, cy: float, w: float, h: float,
		fondo: Color, bordo: Color, dettagli: Color, col_lettera: Color) -> void:
	# corpo
	draw_rect(_rett(cx, cy, w, h), fondo)
	draw_rect(_rett(cx, cy, w, h), bordo, false, 1.0)

	# bordo interno
	draw_rect(_rett(cx, cy, w * 0.82, h * 0.70), dettagli, false, 1.0)

	# pallini agli angoli
	var dx := w * 0.31
	var dy := h * 0.24
	var rp := maxf(h * 0.05, 1.0)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			draw_circle(Vector2(cx + dx * sx, cy + dy * sy), rp, dettagli)

	# lettera centrata con il tuo font
	var fs := int(h * 0.6)
	var dim := _font.get_string_size(lettera, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var base_y := cy + (_font.get_ascent(fs) - _font.get_descent(fs)) / 2.0
	draw_string(_font, Vector2(cx - dim.x / 2.0, base_y), lettera,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col_lettera)
