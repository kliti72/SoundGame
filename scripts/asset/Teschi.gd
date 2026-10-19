@tool
class_name DifficoltaTeschi
extends Control

# --- stile fisso ---
const BIANCO := Color("000000ff")
const VERDE_SCURO := Color("ac001bff")
const VIOLA_SCURO := Color("ac001bff")
const GRIGIO := Color("8c8c8c")

const N_SPINE := 25

@export var totale := 8:
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

@export var soglia_medio := 4:
	set(v):
		soglia_medio = v
		queue_redraw()

@export var soglia_difficile := 7:
	set(v):
		soglia_difficile = v
		queue_redraw()

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

func _colore_livello() -> Color:
	if livello >= soglia_difficile:
		return VIOLA_SCURO
	if livello >= soglia_medio:
		return VERDE_SCURO
	return BIANCO

# --- disegno ---
func _draw() -> void:
	var col_attivo := _colore_livello()
	for i in totale:
		var c := Vector2(i * (grandezza + spazio) + grandezza / 2.0, grandezza / 2.0)
		if i < livello:
			_cerchio_spine(c, grandezza, col_attivo)
		else:
			_cerchio_spine(c, grandezza, GRIGIO)

func _cerchio_spine(c: Vector2, s: float, col: Color) -> void:
	var r := s * 0.40
	var spess := maxf(s * 0.04, 1.0)

	# anello
	draw_arc(c, r, 0.0, TAU, 48, col, spess, true)

	# spine (piccoli triangoli verso l'esterno)
	for j in N_SPINE:
		var ang := TAU * j / N_SPINE + 0.2
		var dir := Vector2.from_angle(ang)
		var perp := Vector2(-dir.y, dir.x)
		var base := c + dir * r
		draw_colored_polygon(PackedVector2Array([
			base + perp * s * 0.025,
			base + dir * s * 0.09 + perp * s * 0.02,
			base - perp * s * 0.025,
		]), col)
