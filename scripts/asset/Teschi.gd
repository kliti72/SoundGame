@tool
class_name DifficoltaTeschi
extends Control

# --- stile fisso ---
const ROSSO := Color("ffff")
const NERO := Color("0d0d0d")
const GRIGIO := Color("8c8c8c")
const GRIGIO_DET := Color("4a4a4a")

@export var totale := 3:
	set(v):
		totale = maxi(v, 1)
		livello = livello  # ri-clampa
		_aggiorna_dimensione()

@export var livello := 1:
	set(v):
		livello = clampi(v, 0, totale)
		queue_redraw()

@export var grandezza := 36.0:
	set(v):
		grandezza = maxf(v, 4.0)
		_aggiorna_dimensione()

@export var spazio := 6.0:
	set(v):
		spazio = maxf(v, 0.0)
		_aggiorna_dimensione()

func _ready() -> void:
	_aggiorna_dimensione()

# --- metodi ---
func imposta_livello(n: int) -> void:
	livello = n

func get_livello() -> int:
	return livello

# --- utility ---
func _aggiorna_dimensione() -> void:
	custom_minimum_size = Vector2(totale * grandezza + spazio * (totale - 1), grandezza)
	size = custom_minimum_size
	queue_redraw()

# --- disegno ---
func _draw() -> void:
	for i in totale:
		var cx := i * (grandezza + spazio) + grandezza / 2.0
		var cy := grandezza / 2.0
		if i < livello:
			_teschio(cx, cy, grandezza, ROSSO, NERO)
		else:
			_teschio(cx, cy, grandezza, GRIGIO, GRIGIO_DET)

func _teschio(cx: float, cy: float, s: float, corpo: Color, det: Color) -> void:
	# cranio: cerchio grande
	var rc := s * 0.38
	var cc := Vector2(cx, cy - s * 0.08)
	draw_circle(cc, rc, corpo)

	# mascella: rettangolo sotto il cranio
	var mw := s * 0.40
	var mh := s * 0.24
	var mtop := cy + s * 0.14
	draw_rect(Rect2(cx - mw / 2.0, mtop, mw, mh), corpo)

	# occhi: due cerchi scavati
	var ro := s * 0.10
	var oy := cc.y + s * 0.02
	draw_circle(Vector2(cx - s * 0.15, oy), ro, det)
	draw_circle(Vector2(cx + s * 0.15, oy), ro, det)

	# naso: triangolino
	var ny := cc.y + s * 0.17
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx, ny - s * 0.05),
		Vector2(cx + s * 0.045, ny + s * 0.05),
		Vector2(cx - s * 0.045, ny + s * 0.05),
	]), det)

	# denti: righine verticali sulla mascella
	var spess := maxf(s * 0.025, 1.0)
	for k in [-1, 0, 1]:
		var dx: float = cx + k * mw * 0.25
		draw_line(Vector2(dx, mtop + mh * 0.35), Vector2(dx, mtop + mh), det, spess)
