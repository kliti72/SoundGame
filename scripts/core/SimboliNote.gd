class_name SimboliNote
extends RefCounted
## Disegno dei simboli delle note. Nessuno stato di gioco: solo forme.
##
## Per aggiungere un simbolo nuovo:
##   1) scrivi una funzione statica _xxx(ci, pos, s)
##   2) aggiungi il caso nel match di disegna()
##   3) aggiungi il nome in ELENCO
##
## ci  = il nodo che sta eseguendo _draw()
## pos = posizione CORRENTE del simbolo (cambia mentre vola)
## s   = { r, fase, a, tono, ali, apertura }
##       apertura: 0 = in volo, 1 = arrivato sulla nota

const DEFAULT := "pipistrello"
const ELENCO := ["pipistrello", "cerchio", "pillola"]   # tieni allineato con @export_enum in gioco.gd
# Come entra ogni simbolo (sovrascrivibile per singola nota con "ingresso" nel JSON).
# Ingressi disponibili: "bordo" (vola dal bordo dello schermo), "caduta" (cade dall'alto)
const INGRESSO := {
	"pipistrello": "bordo", 
	"cerchio": "bordo", 
	"pillola": "caduta"
	}

const VELOCITA_ALI := 6.0
const RIEMPIMENTO := Color(0.04, 0.04, 0.04, 0.55)

# Pipistrello
const ALI_CHIUSE := 0.45                      # larghezza delle ali in volo (1.0 = aperte)
const OCCHI_SPENTI := Color(0.45, 0.45, 0.45)
const OCCHI_ACCESI := Color(1.0, 0.15, 0.2)   # colore degli occhi all'arrivo

# Pillola
const PILLOLA_ACCESA := Color(1.0, 0.15, 0.2)  # colore della metà che si accende all'arrivo

static var _sagoma_bat := PackedVector2Array()


static func disegna(ci: CanvasItem, n: Dictionary, pos: Vector2, s: Dictionary) -> void:
	match n.simbolo:
		"pipistrello":
			_pipistrello(ci, pos, s)
		"pillola":
			_pillola(ci, pos, s)
		_:
			_cerchio(ci, pos, s)   # "cerchio" e simboli sconosciuti


# --- Utilità di forma ----------------------------------------------------------

static func riempi_e_contorna(ci: CanvasItem, pts: PackedVector2Array, riempimento: Color, contorno: Color, spessore: float) -> void:
	ci.draw_colored_polygon(pts, riempimento)
	var chiuso := pts.duplicate()
	chiuso.append(pts[0])
	ci.draw_polyline(chiuso, contorno, spessore, true)


## Forma a "stadio" (rettangolo con estremi tondi) per pillola/capsula.
## lung = lunghezza totale, r = raggio degli estremi, rot = rotazione in radianti
static func punti_capsula(centro: Vector2, lung: float, r: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var meta := lung * 0.5 - r
	for i in 13:
		pts.append(Vector2(meta, 0) + Vector2.from_angle(-PI / 2.0 + PI * i / 12.0) * r)
	for i in 13:
		pts.append(Vector2(-meta, 0) + Vector2.from_angle(PI / 2.0 + PI * i / 12.0) * r)
	for i in pts.size():
		pts[i] = centro + pts[i].rotated(rot)
	return pts


# --- Cerchio -------------------------------------------------------------------
static func _cerchio(ci: CanvasItem, pos: Vector2, s: Dictionary) -> void:
	var tono: Color = s.tono
	ci.draw_circle(pos, s.r, Color(RIEMPIMENTO, RIEMPIMENTO.a * s.a))
	ci.draw_arc(pos, s.r, 0.0, TAU, 64, Color(tono, s.a), 4.0, true)


# --- Pipistrello ---------------------------------------------------------------
# Sagoma in coordinate unitarie (larghezza da -1 a 1): calcolata una sola volta.
static func _sagoma() -> PackedVector2Array:
	if not _sagoma_bat.is_empty():
		return _sagoma_bat
	# Metà destra: dalla testa verso l'ala e giù fino alla coda
	var meta: Array[Vector2] = [
		Vector2(0.00, -0.28), Vector2(0.10, -0.55), Vector2(0.20, -0.30),   # testa, orecchio
		Vector2(0.55, -0.45), Vector2(1.00, -0.65),                          # braccio e punta ala
		Vector2(0.88, -0.15), Vector2(0.80, 0.15),                           # bordo ala 1
		Vector2(0.60, 0.00), Vector2(0.48, 0.30),                            # bordo ala 2
		Vector2(0.30, 0.10), Vector2(0.14, 0.45), Vector2(0.00, 0.38),       # bordo ala 3, coda
	]
	var centra := Vector2(0, 0.1)
	for p in meta:
		_sagoma_bat.append(p + centra)
	for i in range(meta.size() - 2, 0, -1):   # metà sinistra specchiata
		_sagoma_bat.append(Vector2(-meta[i].x, meta[i].y) + centra)
	return _sagoma_bat


static func _pipistrello(ci: CanvasItem, pos: Vector2, s: Dictionary) -> void:
	var tono: Color = s.tono
	var ap: float = s.apertura
	var larghezza := lerpf(ALI_CHIUSE, 1.0, ap)            # ali chiuse in volo, aperte all'arrivo
	var flap: float = sin(s.fase * VELOCITA_ALI) * s.ali   # le punte salgono e scendono

	var pts := PackedVector2Array()
	for p in _sagoma():
		pts.append(pos + Vector2(p.x * larghezza, p.y - absf(p.x) * flap) * s.r * 1.1)
	riempi_e_contorna(ci, pts, Color(RIEMPIMENTO, RIEMPIMENTO.a * s.a), Color(tono, s.a), 3.0)

	# Occhi: grigi in volo, si accendono quando arriva
	var colore := OCCHI_SPENTI.lerp(OCCHI_ACCESI, ap)
	for lato in [-1.0, 1.0]:
		var c: Vector2 = pos + Vector2(lato * 0.08, -0.17) * s.r * 1.1
		if ap > 0.0:
			ci.draw_circle(c, s.r * 0.12, Color(OCCHI_ACCESI, 0.25 * ap * s.a))   # alone
		ci.draw_circle(c, s.r * 0.055, Color(colore, s.a))


# --- Pillola -------------------------------------------------------------------
# Capsula con linea al centro. In volo gira su se stessa; all'arrivo si ferma in
# diagonale e una delle due metà si accende.
static func _pillola(ci: CanvasItem, pos: Vector2, s: Dictionary) -> void:
	var tono: Color = s.tono
	var ap: float = s.apertura
	var r: float = s.r
	var spessore := r * 0.6
	var rot = -PI / 4.0 + (1.0 - ap) * s.fase * 3.0
	var corpo := punti_capsula(pos, r * 2.1, spessore, rot)

	ci.draw_colored_polygon(corpo, Color(RIEMPIMENTO, RIEMPIMENTO.a * s.a))

	# metà destra colorata: i primi 13 punti di corpo sono il suo semicerchio
	var meta := PackedVector2Array([pos + Vector2(0, -spessore).rotated(rot)])
	for i in 13:
		meta.append(corpo[i])
	meta.append(pos + Vector2(0, spessore).rotated(rot))
	ci.draw_colored_polygon(meta, Color(tono.lerp(PILLOLA_ACCESA, ap), 0.75 * s.a))

	var contorno := corpo.duplicate()
	contorno.append(corpo[0])
	ci.draw_polyline(contorno, Color(tono, s.a), 3.0, true)

	var dir := Vector2(0, spessore).rotated(rot)   # linea che divide le due metà
	ci.draw_line(pos - dir, pos + dir, Color(tono, s.a), 3.0, true)
