class_name Teppistello
extends Control

signal fuga_finita

var parlando := false

@export var colore_pelle := Color("#e8b48a")
@export var colore_cappello := Color("550d12ff")
@export var colore_felpa := Color("#fffffff")

const ORO := Color("#ffd700")
const BOCCA := Color("#5a1f1f")
const BASE := Vector2(160, 190)   # griglia su cui è disegnato, non toccare
const N_OPS := 3
const K_OP := 1.6                # quanto sono grossi gli sbirri

@export var dimensione := Vector2(320, 380):
	set(v):
		dimensione = v
		custom_minimum_size = v
		queue_redraw()

var _t := 0.0
var _bocca := 0.0

# musica
var _musica := false
var _bpm := 0.0
var _bus := 0
var _beat := 0.0
var _lato := 1.0
var _beat_prec := -1

# fuga
var _fuga := false
var _ops_attivi := false
var _fuga_t := 0.0
var _fuga_dur := 2.5
var _fuga_dir := 1.0
var _fx := 0.0
var _spara_t := 0.0
var _flash := [0.0, 0.0, 0.0]
var _proiettili: Array[Dictionary] = []


func _init() -> void:
	custom_minimum_size = Vector2(160, 190)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	custom_minimum_size = dimensione


# ---------- API ----------

# await teppistello.fuggi()  -> aspetta che sia sparito
# direzione: 1 = scappa a destra, -1 = a sinistra
func fuggi(durata := 2.5, direzione := 1.0) -> void:
	_fuga = true
	_ops_attivi = true
	_fuga_t = 0.0
	_fuga_dur = maxf(durata, 0.5)
	_fuga_dir = 1.0 if direzione >= 0.0 else -1.0
	_fx = 0.0
	_spara_t = 0.0
	_proiettili.clear()
	parlando = false
	await fuga_finita


# lo rimette al suo posto dopo la fuga
func torna() -> void:
	_fuga = false
	_ops_attivi = false
	_fx = 0.0
	_proiettili.clear()


# bpm > 0  -> va a tempo fisso (es. segui_musica(true, 140.0))
# bpm = 0  -> legge il volume del bus audio (es. segui_musica(true, 0.0, "Music"))
func segui_musica(attiva := true, bpm := 0.0, bus := "Master") -> void:
	_musica = attiva
	_bpm = bpm
	_bus = maxi(AudioServer.get_bus_index(bus), 0)
	_beat_prec = -1


# ---------- LOGICA ----------

func _process(d: float) -> void:
	_t += d
	_aggiorna_musica()
	if _fuga:
		_aggiorna_fuga(d)

	var target := 0.0
	if _fuga:
		target = 1.0                       # urla
	elif parlando:
		target = absf(sin(_t * 14.0))
	_bocca = lerpf(_bocca, target, 0.5)
	queue_redraw()


func _aggiorna_musica() -> void:
	var target := 0.0
	if _musica:
		if _bpm > 0.0:
			var fase := _t * _bpm / 60.0
			target = pow(1.0 - fposmod(fase, 1.0), 3.0)   # botta sul beat, poi cala
			var n := int(fase)
			if n != _beat_prec:
				_beat_prec = n
				_lato = -_lato
		else:
			var db := AudioServer.get_bus_peak_volume_left_db(_bus, 0)
			target = clampf(inverse_lerp(-40.0, -6.0, db), 0.0, 1.0)
			if target > _beat + 0.3:
				_lato = -_lato
	_beat = lerpf(_beat, target, 0.5 if target > _beat else 0.15)


func _pos_op(i: int) -> Vector2:
	var x := BASE.x * 0.5 + _fx * 0.8 - _fuga_dir * (110.0 + i * 55.0)
	var y := BASE.y - absf(sin(_t * 18.0 + i * 1.7)) * 5.0
	return Vector2(x, y)


func _aggiorna_fuga(d: float) -> void:
	_fuga_t += d
	var p := clampf(_fuga_t / _fuga_dur, 0.0, 1.0)
	_fx = _fuga_dir * BASE.x * 2.6 * p * p          # accelera mentre scappa


	for i in N_OPS:
		_flash[i] = maxf(_flash[i] - d, 0.0)

	_spara_t -= d
	if _spara_t <= 0.0 and p < 0.9:
		_spara_t = randf_range(0.08, 0.16)
		var i := randi() % N_OPS
		var canna := _pos_op(i) + Vector2(32.0 * K_OP * _fuga_dir, -46.0 * K_OP)
		_flash[i] = 0.06
		_proiettili.append({
			"pos": canna,
			"vel": Vector2(_fuga_dir * 700.0, randf_range(-420.0, -260.0)),  # y: quanto sfiorano la testa
			"vita": 0.8})

	for i in range(_proiettili.size() - 1, -1, -1):
		var b := _proiettili[i]
		b["pos"] += b["vel"] * d
		b["vita"] -= d
		if b["vita"] <= 0.0:
			_proiettili.remove_at(i)

	if _fuga_t >= _fuga_dur:
		_fuga = false
		_ops_attivi = false
		_proiettili.clear()
		fuga_finita.emit()


# ---------- DISEGNO ----------

func _ellisse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)

func _disegna_ops(mondo: Transform2D) -> void:
	var felpe := [Color("#2a9d8f"), Color("#f4a261"), Color("#6a4c93")]
	var pelli := [Color("#e0ac69"), Color("#fffff"), Color("#c68642")] 
	var cappelli := [Color("#111111"), Color("#6a4c93"), Color("#1a1a1a")]
	var jeans := Color("#1b1b2f")

	for i in N_OPS:
		draw_set_transform_matrix(mondo * Transform2D(0.0, Vector2(_fuga_dir * K_OP, K_OP), 0.0, _pos_op(i)))
		var gamba := sin(_t * 18.0 + i * 1.7) * 7.0
		var felpa: Color = felpe[i % 3]
		var pelle: Color = pelli[i % 3]
		var cap: Color = cappelli[i % 3]

		# gambe larghe + scarpe bianche
		draw_line(Vector2(-4, -12), Vector2(-4 + gamba, -2), jeans, 6.0)
		draw_line(Vector2(4, -12), Vector2(4 - gamba, -2), jeans, 6.0)
		draw_rect(Rect2(-8 + gamba, -3, 9, 4), Color.WHITE)
		draw_rect(Rect2(-1 - gamba, -3, 9, 4), Color.WHITE)

		# felpa + striscia
		draw_rect(Rect2(-9, -52, 18, 40), felpa)
		draw_rect(Rect2(-9, -30, 18, 3), felpa.darkened(0.25))

		# catena + pendente
		draw_arc(Vector2(0, -52), 8, 0.2, PI - 0.2, 12, ORO, 2.0)
		draw_circle(Vector2(0, -41), 3, ORO)

		# testa
		draw_circle(Vector2(0, -61), 9, pelle)
		draw_circle(Vector2(5, -62), 1.6, Color.BLACK)           # occhio
		draw_rect(Rect2(6, -57, 3, 2), ORO)                      # dente d'oro

		# capelli / cappello diversi per ognuno
		var cupola := PackedVector2Array()
		var r := 10.0 if i % 3 != 2 else 12.0
		for k in 13:
			var a := PI + PI * k / 12.0
			cupola.append(Vector2(0, -64) + Vector2(cos(a) * r, sin(a) * r))
		if i % 3 == 0:                                            # beanie
			draw_colored_polygon(cupola, cap)
			draw_rect(Rect2(-10, -66, 20, 4), cap.lightened(0.25))
		elif i % 3 == 1:                                          # snapback con visiera
			draw_colored_polygon(cupola, cap)
			draw_colored_polygon(PackedVector2Array([
				Vector2(6, -66), Vector2(21, -65), Vector2(21, -62), Vector2(6, -62)
			]), cap.darkened(0.3))
			draw_circle(Vector2(0, -74), 1.8, ORO)
		else:                                                     # afro / treccine
			draw_colored_polygon(cupola, cap)
			for t in 4:
				draw_line(Vector2(-9 + t * 5.0, -64), Vector2(-11 + t * 6.0, -53), cap, 2.0)

		# braccio + pistola
		draw_line(Vector2(0, -44), Vector2(18, -46), felpa.darkened(0.15), 5.0)
		draw_circle(Vector2(18, -46), 3, pelle)
		draw_line(Vector2(14, -46), Vector2(32, -46), Color("#111111"), 4.0)

		if _flash[i] > 0.0:
			draw_circle(Vector2(36, -46), 7, Color("#ffd23f"))


func _draw() -> void:
	var s := minf(size.x / BASE.x, size.y / BASE.y)
	var offset := (size - BASE * s) / 2.0
	var mondo := Transform2D(0.0, Vector2(s, s), 0.0, offset)

	# sbirri + scie di velocità (dietro)
	if _ops_attivi:
		_disegna_ops(mondo)
		draw_set_transform_matrix(mondo)
		for i in 4:
			var y := 60.0 + i * 28.0
			var x0 := 80.0 + _fx - _fuga_dir * (45.0 + fposmod(_t * 600.0 + i * 70.0, 120.0))
			draw_line(Vector2(x0, y), Vector2(x0 - _fuga_dir * 40.0, y), Color(1, 1, 1, 0.45), 2.0)

	# movimento del corpo
	var bob := 0.0
	var inclina := 0.0
	if _fuga:
		bob = -absf(sin(_t * 22.0)) * 6.0
		inclina = _fuga_dir * 0.2
	elif parlando:
		bob = -absf(sin(_t * 14.0)) * 3.0

	var pivot := Vector2(80, 190)
	var corpo := mondo * Transform2D(0.0, Vector2(_fx, bob)) \
		* Transform2D(0.0, pivot) * Transform2D(inclina, Vector2.ZERO) * Transform2D(0.0, -pivot)
	draw_set_transform_matrix(corpo)

	# felpa
	draw_colored_polygon(PackedVector2Array([
		Vector2(20, 190), Vector2(30, 150), Vector2(60, 135),
		Vector2(100, 135), Vector2(130, 150), Vector2(140, 190)
	]), colore_felpa)

	# collo + catena d'oro
	draw_rect(Rect2(68, 118, 24, 22), colore_pelle.darkened(0.15))
	draw_arc(Vector2(80, 136), 24, 0.15, PI - 0.15, 16, ORO, 3.0)
	draw_circle(Vector2(80, 162), 6, ORO)

	# orecchie + testa
	draw_circle(Vector2(38, 82), 8, colore_pelle.darkened(0.1))
	draw_circle(Vector2(122, 82), 8, colore_pelle.darkened(0.1))
	draw_circle(Vector2(80, 78), 42, colore_pelle)

	# occhi (guarda a sinistra) + sopracciglia da duro
	for x in [60.0, 90.0]:
		draw_circle(Vector2(x, 82), 7, Color.WHITE)
		draw_circle(Vector2(x - 2, 83), 3.5, Color.BLACK)
	draw_line(Vector2(50, 68), Vector2(70, 75), Color.BLACK, 3.0)
	draw_line(Vector2(82, 75), Vector2(100, 68), Color.BLACK, 3.0)

	# naso
	draw_line(Vector2(52, 90), Vector2(48, 98), colore_pelle.darkened(0.3), 2.0)

	# bocca
	_ellisse(Vector2(68, 107), 11, 2.0 + 9.0 * _bocca, BOCCA)

	# goccia di sudore mentre scappa
	if _fuga:
		var sg := fposmod(_t * 3.0, 1.0)
		draw_circle(Vector2(80 - _fuga_dir * 48.0, 55.0 + sg * 25.0), 3.0, Color("#7ecbff"))

	# cappello: balla col beat (perno alla base della cupola)
	var perno := Vector2(80, 66)
	var su := Vector2(0, -_beat * 9.0 - (4.0 if _fuga else 0.0))
	var ruota := _lato * _beat * 0.12
	if _fuga:
		ruota += sin(_t * 30.0) * 0.08
	draw_set_transform_matrix(corpo * Transform2D(0.0, perno + su) \
		* Transform2D(ruota, Vector2(1.0 + 0.04 * _beat, 1.0 - 0.08 * _beat), 0.0, Vector2.ZERO) \
		* Transform2D(0.0, -perno))

	var cupola := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		cupola.append(Vector2(80, 62) + Vector2(cos(a) * 46, sin(a) * 44))
	draw_colored_polygon(PackedVector2Array([
		Vector2(122, 54), Vector2(160, 48), Vector2(162, 60), Vector2(122, 66)
	]), colore_cappello.darkened(0.35))
	draw_colored_polygon(cupola, colore_cappello)
	draw_line(Vector2(34, 62), Vector2(126, 62), colore_cappello.darkened(0.25), 4.0)
	draw_rect(Rect2(34, 52, 8, 10), ORO)
	draw_circle(Vector2(80, 18), 4, colore_cappello.lightened(0.3))

	# proiettili (davanti a tutto)
	if _ops_attivi:
		draw_set_transform_matrix(mondo)
		for b in _proiettili:
			var v: Vector2 = b["vel"]
			var p: Vector2 = b["pos"]
			draw_line(p, p - v.normalized() * 20.0, Color("#ffd23f"), 2.5)
			draw_circle(p, 2.0, Color.WHITE)
