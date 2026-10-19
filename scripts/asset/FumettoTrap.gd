class_name Fumetto
extends PanelContainer

signal finito
signal scrittura_iniziata
signal scrittura_finita
signal _avanza

@export_group("ChatContenitor")
@export var Canvas_Padre : CanvasLayer;
@export var Teppistello: Personaggio

@export_group("Testo")
@export var font: Font
@export var dimensione_font := 24
@export var colore_testo := Color("ecebf5")
@export var larghezza_testo := 560.0
@export var secondi_per_carattere := 0.03

@export_group("Dialogo")
@export var id_dialogo := ""
@export var righe: Array[String] = []

@export_group("Stile trap")
@export var colore_fondo := Color("0a0a0f")
@export var colore_bordo := Color("ecebf5")
@export var colore_neon := Color("9b2cff")
@export var spessore_bordo := 4.0
@export var ombra := Vector2(9, 9)
@export var coda := 28.0

enum Lato { SOPRA, SOTTO, SINISTRA, DESTRA }

@export var lato_coda := Lato.SOPRA
@export_range(0.0, 1.0) var posizione_coda := 0.92   # lungo il lato: 0 = inizio, 1 = fine
@export var inclinazione := 22.0                      # quanto la punta pende di lato (+ destra/giù, - sinistra/su)

@export var passo := 22.0
@export var sporcizia := 3.5


var _label := Label.new()
var _punti := PackedVector2Array()
var _dim_cache := Vector2.ZERO
var _in_corso := false
var _scrivendo := false
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	var vuoto := StyleBoxEmpty.new()
	vuoto.content_margin_left = 24 + (coda if lato_coda == Lato.SINISTRA else 0.0)
	vuoto.content_margin_right = 24 + ombra.x + (coda if lato_coda == Lato.DESTRA else 0.0)
	vuoto.content_margin_top = 18 + (coda if lato_coda == Lato.SOPRA else 0.0)
	vuoto.content_margin_bottom = 18 + ombra.y + (coda if lato_coda == Lato.SOTTO else 0.0)
	add_theme_stylebox_override("panel", vuoto)

	if font:
		_label.add_theme_font_override("font", font)
	else:
		var sf := SystemFont.new()
		sf.font_names = ["Impact", "Bangers", "Arial Black"]
		_label.add_theme_font_override("font", sf)
	_label.add_theme_font_size_override("font_size", dimensione_font)
	_label.add_theme_color_override("font_color", colore_testo)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size.x = larghezza_testo
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	

# await fumetto.parla("benvenuto", ["Yo!", "Benvenuto fra."])
# true se ha parlato, false se l'aveva già detto.
func parla(id: String = "", testi: Array[String] = [], forza := false, fuggire := true, have_next := false) -> bool:
	if _in_corso:
		return false
	if id == "":
		id = id_dialogo
	if testi.is_empty():
		testi = righe
	if testi.is_empty():
		return false
	if not forza and id != "" and DialogoMemoria.gia_detto(id):
		finito.emit()
		print("finito")
		termina_conversazione()
		return false

	_in_corso = true
	visible = true
	for t in testi:
		await _scrivi(t)
	visible = false
	_in_corso = false

	if id != "":
		DialogoMemoria.segna_detto(id)
		if(fuggire == true):
			await Teppistello.fuggi(3.5, -1);
		if(!have_next):
			termina_conversazione()
		
	finito.emit()
	return true


func _scrivi(testo: String) -> void:
	_label.text = testo
	_label.visible_ratio = 0.0
	_scrivendo = true
	scrittura_iniziata.emit()
	_tween = create_tween()
	_tween.tween_property(_label, "visible_ratio", 1.0, testo.length() * secondi_per_carattere)
	_tween.tween_callback(_fine_scrittura)
	await _avanza

func termina_conversazione():
	Canvas_Padre.visible = false;


func _fine_scrittura() -> void:
	_scrivendo = false
	scrittura_finita.emit()


func _unhandled_input(e: InputEvent) -> void:
	if not _in_corso:
		return
	var click = e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT
	if not (e.is_action_pressed("ui_accept") or click):
		return
	get_viewport().set_input_as_handled()

	if _scrivendo:
		_tween.kill()
		_label.visible_ratio = 1.0
		_fine_scrittura()
	else:
		_avanza.emit()


# ---------- DISEGNO ----------
func _ricostruisci() -> void:
	_dim_cache = size
	var rng := RandomNumberGenerator.new()
	rng.seed = 666

	var sx := coda if lato_coda == Lato.SINISTRA else 0.0
	var dx := coda if lato_coda == Lato.DESTRA else 0.0
	var su := coda if lato_coda == Lato.SOPRA else 0.0
	var gi := coda if lato_coda == Lato.SOTTO else 0.0

	var r := Rect2(
		Vector2(spessore_bordo + sx, spessore_bordo + su),
		size - Vector2(
			spessore_bordo * 2 + ombra.x + sx + dx,
			spessore_bordo * 2 + ombra.y + su + gi))

	var tl := r.position
	var tr := Vector2(r.end.x, r.position.y)
	var br := r.end
	var bl := Vector2(r.position.x, r.end.y)

	var p := PackedVector2Array()
	_lato(p, tl, tr, Vector2.UP,    rng, posizione_coda,       1.0,  lato_coda == Lato.SOPRA)
	_lato(p, tr, br, Vector2.RIGHT, rng, posizione_coda,       1.0,  lato_coda == Lato.DESTRA)
	_lato(p, br, bl, Vector2.DOWN,  rng, 1.0 - posizione_coda, -1.0, lato_coda == Lato.SOTTO)
	_lato(p, bl, tl, Vector2.LEFT,  rng, 1.0 - posizione_coda, -1.0, lato_coda == Lato.SINISTRA)
	_punti = p


func _lato(p: PackedVector2Array, da: Vector2, a: Vector2, normale: Vector2,
		rng: RandomNumberGenerator, f: float, verso: float, con_coda: bool) -> void:
	var lung := da.distance_to(a)
	var dir := (a - da) / lung
	var n := maxi(int(ceil(lung / passo)), 1)
	var centro := clampf(f * lung, 28.0, lung - 28.0)
	var fatta := false

	for i in n:
		var d := i * lung / n
		if con_coda and d >= centro - 16.0 and d <= centro + 16.0:
			if not fatta:
				p.append(da + dir * (centro - 16.0))
				p.append(da + dir * (centro + inclinazione * verso) + normale * coda)
				p.append(da + dir * (centro + 16.0))
				fatta = true
			continue
		p.append(da + dir * d + normale * rng.randf_range(-sporcizia, sporcizia))
	_punti = p


func _draw() -> void:
	if _punti.size() < 3 or size != _dim_cache:
		_ricostruisci()

	# ombra neon
	var ombrap := PackedVector2Array()
	for v in _punti:
		ombrap.append(v + ombra)
	draw_colored_polygon(ombrap, colore_neon)

	# corpo
	draw_colored_polygon(_punti, colore_fondo)

	# mezzatinta
	var area := Rect2(size.x * 0.55, size.y * 0.3, size.x * 0.4, size.y * 0.4)
	var d := 10.0
	var yy := area.position.y
	var riga := 0
	while yy < area.end.y:
		var xx := area.position.x + (d * 0.5 if riga % 2 == 1 else 0.0)
		while xx < area.end.x:
			var t := (yy - area.position.y) / area.size.y
			draw_circle(Vector2(xx, yy), lerpf(1.0, 3.2, t), Color(colore_neon, 0.18))
			xx += d
		yy += d * 0.8
		riga += 1

	# bordo
	var chiuso := _punti.duplicate()
	chiuso.append(_punti[0])
	draw_polyline(chiuso, colore_bordo, spessore_bordo, true)
