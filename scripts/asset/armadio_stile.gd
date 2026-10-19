@tool
class_name ArmadioStile
extends Resource
## ============================================================
## STILE DELL'ARMADIO: qui c'è SOLO l'aspetto, zero logica.
##
## CONTRATTO con la logica (ArmadioVinili), NON rinominare:
##   Variabili lette dalla logica per il layout:
##     margine, spessore_ripiano, scala_vinile
##   Funzioni chiamate dalla logica dentro il suo _draw():
##     disegna_muro(ci, size)
##     disegna_armadio(ci, area, righe)
##     disegna_vinile(ci, rect, dati)
##   `ci` è il Control su cui disegnare (usa ci.draw_*).
##   `dati` è un Dictionary: titolo, artista, colore, copertina.
##
## Per cambiare look: modifica i valori export o riscrivi il
## corpo delle funzioni disegna_*. Le firme restano uguali.
## ============================================================

@export var font: Font:
	set(v):
		font = v
		emit_changed()

@export_group("Layout (letti dalla logica)")
## spazio vuoto tra bordo del Control e armadio
@export var margine: float = 40.0:
	set(v):
		margine = v
		emit_changed()
## altezza del ripiano; i vinili ci poggiano sopra
@export var spessore_ripiano: float = 10.0:
	set(v):
		spessore_ripiano = v
		emit_changed()
## quanto è grande la copertina rispetto alla cella (0.1 - 1.0)
@export_range(0.1, 1.0) var scala_vinile: float = 0.68:
	set(v):
		scala_vinile = v
		emit_changed()

@export_group("Forme")
@export var spike_size: float = 26.0:
	set(v):
		spike_size = v
		emit_changed()

@export_group("Colori")
@export var colore_muro_alto: Color = Color("14001f"):
	set(v):
		colore_muro_alto = v
		emit_changed()
@export var colore_muro_basso: Color = Color("050005"):
	set(v):
		colore_muro_basso = v
		emit_changed()
@export var colore_armadio: Color = Color("0c0c0c"):
	set(v):
		colore_armadio = v
		emit_changed()
@export var colore_ripiano: Color = Color("1c1c1c"):
	set(v):
		colore_ripiano = v
		emit_changed()
@export var colore_neon: Color = Color("7a00ff"):
	set(v):
		colore_neon = v
		emit_changed()
@export var colore_neon_2: Color = Color("c4001a"):
	set(v):
		colore_neon_2 = v
		emit_changed()
@export var colore_testo: Color = Color("e8e8e8"):
	set(v):
		colore_testo = v
		emit_changed()


func _font() -> Font:
	return font if font != null else ThemeDB.fallback_font


# ------------------------------------------------------------ MURO

func disegna_muro(ci: CanvasItem, size: Vector2) -> void:
	# gradiente verticale
	var pts := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	var cols := PackedColorArray([colore_muro_alto, colore_muro_alto, colore_muro_basso, colore_muro_basso])
	ci.draw_polygon(pts, cols)

	# graffi/tag, deterministici (seed fisso = non tremano a ogni redraw)
	var rng := RandomNumberGenerator.new()
	rng.seed = 666
	for i in 40:
		var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var l := rng.randf_range(10.0, 50.0)
		var a := rng.randf_range(-0.6, 0.6)
		var c := colore_neon if i % 3 else colore_neon_2
		c.a = 0.12
		ci.draw_line(p, p + Vector2(cos(a), sin(a)) * l, c, 1.5)

	# alone neon dietro l'armadio
	var centro := size * 0.5
	for i in 8:
		var r := (minf(size.x, size.y) * 0.5) * (1.0 + i * 0.08)
		var c := colore_neon
		c.a = 0.025
		ci.draw_circle(centro, r, c)


# --------------------------------------------------------- ARMADIO

func disegna_armadio(ci: CanvasItem, a: Rect2, righe: int) -> void:
	ci.draw_rect(a, colore_armadio)

	# bordo neon doppio
	var glow := colore_neon
	glow.a = 0.35
	ci.draw_rect(a.grow(3), glow, false, 6.0)
	ci.draw_rect(a, colore_neon, false, 2.0)

	# spuntoni sugli angoli
	var s := spike_size
	_spike(ci, a.position, Vector2(-1, -1), s)
	_spike(ci, Vector2(a.end.x, a.position.y), Vector2(1, -1), s)
	_spike(ci, Vector2(a.position.x, a.end.y), Vector2(-1, 1), s)
	_spike(ci, a.end, Vector2(1, 1), s)

	# spuntoni lungo il bordo alto
	var n := maxi(2, int(a.size.x / 120.0))
	for i in n:
		var x := a.position.x + (i + 0.5) * a.size.x / n
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(x - 10, a.position.y),
			Vector2(x, a.position.y - s * 0.7),
			Vector2(x + 10, a.position.y),
		]), colore_neon_2)

	# ripiani
	var h_riga := a.size.y / righe
	for r in righe:
		var y := a.position.y + (r + 1) * h_riga
		ci.draw_rect(Rect2(a.position.x, y - spessore_ripiano, a.size.x, spessore_ripiano), colore_ripiano)
		ci.draw_line(Vector2(a.position.x, y - spessore_ripiano), Vector2(a.end.x, y - spessore_ripiano), colore_neon_2, 1.5)


func _spike(ci: CanvasItem, angolo: Vector2, dir: Vector2, s: float) -> void:
	var tri := PackedVector2Array([
		angolo + Vector2(dir.x * s * 0.45, 0),
		angolo + dir * s,
		angolo + Vector2(0, dir.y * s * 0.45),
	])
	ci.draw_colored_polygon(tri, colore_neon_2)
	ci.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), colore_testo, 1.5)


# ----------------------------------------------------------- VINILE

func disegna_vinile(ci: CanvasItem, r: Rect2, dati: Dictionary) -> void:
	var colore: Color = dati.get("colore", Color("c4001a"))

	# disco che spunta da dietro la copertina
	var centro := Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.35)
	var raggio := r.size.x * 0.5
	ci.draw_circle(centro, raggio, Color("060606"))
	for k in range(1, 5):
		ci.draw_arc(centro, raggio * (0.45 + k * 0.1), 0.0, TAU, 48, Color(1, 1, 1, 0.06), 1.0)
	ci.draw_circle(centro, raggio * 0.28, colore)
	ci.draw_circle(centro, raggio * 0.04, Color("060606"))

	# copertina (texture vera o finta)
	var tex: Texture2D = dati.get("copertina", null)
	if tex != null:
		ci.draw_texture_rect(tex, r, false)
	else:
		ci.draw_rect(r, colore.darkened(0.55))
		ci.draw_rect(Rect2(r.position.x, r.position.y + r.size.y * 0.62, r.size.x, r.size.y * 0.38), colore.darkened(0.2))
		ci.draw_line(r.position + Vector2(8, 8), r.position + r.size - Vector2(8, 8), Color(1, 1, 1, 0.07), 2.0)
		ci.draw_line(Vector2(r.end.x - 8, r.position.y + 8), Vector2(r.position.x + 8, r.end.y - 8), Color(1, 1, 1, 0.07), 2.0)

	# bordo + spuntone alto-sinistra
	ci.draw_rect(r, colore_testo, false, 2.0)
	var t := r.size.x * 0.16
	ci.draw_colored_polygon(PackedVector2Array([
		r.position, r.position + Vector2(t, 0), r.position + Vector2(0, t)
	]), colore_neon_2)

	# testo
	var f := _font()
	var fs_titolo := maxi(10, int(r.size.x * 0.11))
	var fs_artista := maxi(8, int(r.size.x * 0.08))
	var tw := r.size.x - 12.0
	ci.draw_multiline_string(f, Vector2(r.position.x + 6, r.position.y + r.size.y * 0.74),
		String(dati.get("titolo", "")), HORIZONTAL_ALIGNMENT_CENTER, tw, fs_titolo, 2, colore_testo)
	ci.draw_string(f, Vector2(r.position.x + 6, r.end.y - 8),
		String(dati.get("artista", "")), HORIZONTAL_ALIGNMENT_CENTER, tw, fs_artista, colore_testo.darkened(0.3))
