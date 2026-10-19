extends Node2D

@export var canzone := "Boombap.mp3"
@export_range(0, 3) var sfondo_uso := 0


@onready var musica: AudioStreamPlayer = $AudioStreamPlayer
@onready var sfondi: Array = [$SceneGlitchMonitorTheme, $BackgroundCity, $BackgroundRedWaterScene, $BackgroundForestRain, $BackgroundGraffitiWall]
@onready var label_punteggio : Label = $CanvasLayer/GameHeader/MarginContainer/VBoxContainer/HBoxContainer/Punteggio
@onready var game_header : Control = $CanvasLayer/GameHeader
@onready var _npc : Personaggio = $ManagerTeppistello/Control/MarginContainer/Personaggio
@onready var manager_tep : CanvasLayer = $ManagerTeppistello

const VELOCITA := [0.5, 0.3, 3.0, 0.5, 0.5]   # una per sfondo, nello stesso ordine
const LETTERE := "QWERTYUIOPASDFGHJKLZXCVBNM"
const RAGGIO := 65.0
const APPROCCIO := 1.0          # da quanto prima appare la nota (ed è già cliccabile)
const TOLLERANZA := 0.15        # quanto dopo t la nota resta cliccabile prima del miss
const TONI := [Color(0.92, 0.92, 0.92), Color(0.55, 0.55, 0.55), Color(0.30, 0.30, 0.30)]
const PALETTE := [Color(1.0, 0.1, 0.15), Color(0.6, 0.2, 1.0), Color(0.1, 0.9, 1.0)]

# --- SIMBOLI ---------------------------------------------------------------
# Simbolo usato quando la nota nel JSON non ha il campo "simbolo".
# Per tornare al vecchio cerchio a moduli usa "cerchio".
const SIMBOLO_DEFAULT := "pipistrello"
# Elenco dei simboli disponibili: utile anche per l'editor note (menu / tasti).
# Quando ne aggiungi uno nuovo, scrivilo qui e crea il caso nel match di _disegna_simbolo().
const SIMBOLI := ["pipistrello", "cerchio"]   # prossimi: "pillola", "capsula"
const VELOCITA_ALI := 6.0       # velocità del battito d'ali del pipistrello


var sfondo
var note: Array = []
var onde: Array = []
var tempo := 0.0
var punteggio := 0
var combo := 0
var serie := 0
var soglia := randi_range(3, 5)
var note_prese := 0
var note_totali := 0

var cam: Camera2D
var label: Label

# Sagoma del pipistrello in coordinate unitarie (larghezza circa da -1 a 1), calcolata una volta
var _bat_unit := PackedVector2Array()


func _ready() -> void:
	_prepara_pipistrello()

	MusicaGlobale.stop(0.5)

	var scelta := sfondo_uso - 1 if sfondo_uso > 0 else randi() % sfondi.size()
	sfondo = sfondi[scelta]
	for i in sfondi.size():
		if i != scelta:
			sfondi[i].queue_free()
	sfondo.velocita = VELOCITA[scelta]

	var dati = JSON.parse_string(FileAccess.get_file_as_string("res://data/song_data.json"))
	if dati == null:
		push_error("song_data.json mancante o non valido")
		return
	for voce in dati["canzoni"]:
		if voce["file"] == canzone:
			var punti: Array = voce["note"]
			var recenti: Array = []
			for i in punti.size():
				var lettera: String = punti[i].get("lettera", "")
				if lettera == "":
					lettera = _lettera_casuale(recenti)
				recenti.append(lettera)
				if recenti.size() > 4:
					recenti.pop_front()
				note.append({
					"t": punti[i]["t"],
					"pos": Vector2(punti[i]["x"], punti[i]["y"]),
					"tono": i % 3,
					"lettera": lettera,
					"simbolo": punti[i].get("simbolo", SIMBOLO_DEFAULT),   # forma della nota
					"lobi": 5 + (i % 3),          # numero di "petali" dell'onda
					"fase": randf() * TAU,        # ogni nota ondeggia in modo diverso
				})
	note_totali = note.size()

	_crea_ui()
	sfondo.segui_musica(musica)
	musica.finished.connect(_fine_canzone)
	musica.stream = load("res://resource/musica/" + canzone)
	musica.play()
	manager_tep.visible = false;


func npc_interaction(note_prese) -> void:
	if note_prese == 3:
		manager_tep.visible = true
		manager_tep.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().paused = true
		await _npc.parla(
			"benvenuto_song_2", [
			"...",
			"Fratello Sei Fast, hai già capito come ascoltare le mie basi",
			"...",
			"Bravo fratello hai già capito la wave da solo sono le tue prime 3 Note.",
			"....",
			"Ogni nota GUADAGNI CAP",
			"...",
			"Oggi niente OPS per me. Che fortuna"
			],
		)
		manager_tep.visible = false
		get_tree().paused = false
	else: return


# Lettera casuale diversa dalle ultime usate, così note vicine non hanno lo stesso tasto
func _lettera_casuale(escluse: Array) -> String:
	var pool: Array = []
	for c in LETTERE:
		if c not in escluse:
			pool.append(c)
	return pool.pick_random()


func _crea_ui() -> void:
	cam = Camera2D.new()
	cam.position = get_viewport_rect().size / 2.0
	add_child(cam)

	var layer := CanvasLayer.new()
	layer.layer = 5
	label = Label.new()
	label.position = Vector2(20, 20)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	layer.add_child(label)
	add_child(layer)


func _process(_delta: float) -> void:
	tempo = musica.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()

	for i in range(note.size() - 1, -1, -1):
		if tempo > note[i].t + TOLLERANZA:
			_miss(note[i].pos)
			note.remove_at(i)

	var ora := Time.get_ticks_msec() / 1000.0
	onde = onde.filter(func(o): return ora - o.nascita < 0.8)

	queue_redraw()


# Una nota è cliccabile appena appare, fino alla tolleranza dopo t
func _cliccabile(n: Dictionary) -> bool:
	var resta: float = n.t - tempo
	return resta <= APPROCCIO and resta >= -TOLLERANZA


func _input(event: InputEvent) -> void:
	# Tastiera: lettera della nota visibile più vicina nel tempo
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_A and event.keycode <= KEY_Z:
			_prova_tasto(char(event.keycode))
		return

	# Mouse / touch: click sul simbolo (la prima nota in lista è la più vicina nel tempo)
	# L'area di click resta circolare, qualunque sia il simbolo disegnato
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse := get_global_mouse_position()
		for n in note:
			if _cliccabile(n) and mouse.distance_to(n.pos) <= RAGGIO * 1.15:
				_colpita(n)
				break


func _prova_tasto(lettera: String) -> void:
	var migliore = null
	var errore_min := INF
	for n in note:
		if n.lettera != lettera or not _cliccabile(n):
			continue
		var errore := absf(tempo - n.t)
		if errore < errore_min:
			migliore = n
			errore_min = errore
	if migliore:
		_colpita(migliore)

func _colpita(n: Dictionary) -> void:
	note.erase(n)
	note_prese += 1
	combo += 1
	serie += 1

	var guadagno: int = 100 * (1 + floori(combo / 10.0))
	punteggio += guadagno

	var colore: Color = Color.WHITE
	var burst := serie >= soglia
	if burst:
		serie = 0
		soglia = randi_range(3, 5)
		colore = PALETTE.pick_random()
		sfondo.burst_colore(colore)

	_esplosione(n.pos, colore, 44 if burst else 26)
	onde.append({
		"pos": n.pos,
		"nascita": Time.get_ticks_msec() / 1000.0,
		"colore": colore,
		"lobi": n.lobi,
		"fase": n.fase,
	})
	_popup(n.pos, "HIT", colore)
	sfondo.pulse()
	_shake(6.0 if burst else 2.5)

	game_header.aggiorna_combo(combo)
	game_header.aggiorna_punteggio(punteggio, guadagno)
	print("note prese", note_prese)
	npc_interaction(note_prese)

func _miss(pos: Vector2) -> void:
	combo = 0
	serie = 0
	_popup(pos, "MISS", Color(0.4, 0.4, 0.4))


func _esplosione(pos: Vector2, colore: Color, quante: int) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = quante
	p.lifetime = 0.55
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 150.0
	p.initial_velocity_max = 420.0
	p.damping_min = 200.0
	p.damping_max = 340.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 8.0
	var g := Gradient.new()
	g.set_color(0, colore)
	g.set_color(1, Color(colore, 0.0))
	p.color_ramp = g
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


func _popup(pos: Vector2, testo: String, colore: Color) -> void:
	var l := Label.new()
	l.text = testo
	l.position = pos + Vector2(-28, -RAGGIO * 1.5)
	l.modulate = colore
	l.add_theme_font_size_override("font_size", 24)
	add_child(l)
	var tw := create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 40.0, 0.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(l.queue_free)


func _shake(forza: float) -> void:
	var tw := create_tween()
	for i in 4:
		tw.tween_property(cam, "offset", Vector2(randf_range(-forza, forza), randf_range(-forza, forza)), 0.03)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.05)


func _fine_canzone() -> void:
	set_process(false)
	set_process_input(false)   # niente input durante la transizione
	Transizione.vai("res://game/CompleteSong.tscn", "gioco", {
		"file_canzone": canzone,
		"note_prese": note_prese,
		"note_totali": note_totali,
	})


# =============================================================================
#  FORME E SIMBOLI
# =============================================================================

# Cerchio "a moduli": il raggio ondeggia con sin(angolo * lobi + fase), chiuso su se stesso
func _forma(centro: Vector2, raggio: float, ampiezza: float, lobi: int, fase: float, punti := 72) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in punti + 1:
		var ang := TAU * i / punti
		var r := raggio * (1.0 + ampiezza * sin(ang * lobi + fase))
		pts.append(centro + Vector2(cos(ang), sin(ang)) * r)
	return pts


# Riempie un poligono e ne disegna il contorno chiuso
func _riempi_e_contorna(pts: PackedVector2Array, riempimento: Color, contorno: Color, spessore: float) -> void:
	draw_colored_polygon(pts, riempimento)
	var chiuso := pts.duplicate()
	chiuso.append(pts[0])
	draw_polyline(chiuso, contorno, spessore, true)


# Punto di ingresso: sceglie come disegnare la nota in base a n.simbolo.
# Per aggiungere un simbolo nuovo: 1) scrivi la funzione _simbolo_xxx  2) aggiungi un caso qui
# 3) aggiungi il nome in SIMBOLI.
func _disegna_simbolo(n: Dictionary, r: float, wobble: float, fase: float, a: float, tono: Color) -> void:
	match n.simbolo:
		"pipistrello":
			_simbolo_pipistrello(n.pos, r, fase, a, tono)
		"cerchio":
			_simbolo_cerchio(n, r, wobble, fase, a, tono)
		# "pillola":
		#	_simbolo_pillola(n.pos, r, fase, a, tono)
		# "capsula":
		#	_simbolo_capsula(n.pos, r, fase, a, tono)
		_:
			_simbolo_cerchio(n, r, wobble, fase, a, tono)   # simbolo sconosciuto: cerchio


# --- Cerchio a moduli (la forma originale) -----------------------------------
func _simbolo_cerchio(n: Dictionary, r: float, wobble: float, fase: float, a: float, tono: Color) -> void:
	var corpo := _forma(n.pos, r, wobble, n.lobi, fase)
	draw_polyline(corpo, Color(tono, a), 4.0, true)
	corpo.remove_at(corpo.size() - 1)   # via il punto duplicato per il poligono pieno
	draw_colored_polygon(corpo, Color(0.04, 0.04, 0.04, 0.55 * a))


# --- Pipistrello -----------------------------------------------------------
# Metà destra della sagoma (dalla testa verso l'ala e giù fino alla coda);
# la metà sinistra viene specchiata in _prepara_pipistrello().
func _prepara_pipistrello() -> void:
	var meta: Array[Vector2] = [
		Vector2(0.00, -0.28),   # centro testa
		Vector2(0.10, -0.55),   # punta orecchio
		Vector2(0.20, -0.30),   # base orecchio
		Vector2(0.55, -0.45),   # braccio dell'ala
		Vector2(1.00, -0.65),   # punta dell'ala
		Vector2(0.88, -0.15),   # rientro 1 del bordo ala
		Vector2(0.80, 0.15),    # punta 1 del bordo ala
		Vector2(0.60, 0.00),    # rientro 2
		Vector2(0.48, 0.30),    # punta 2
		Vector2(0.30, 0.10),    # rientro 3
		Vector2(0.14, 0.45),    # coda destra
		Vector2(0.00, 0.38),    # coda centro
	]
	var centra := Vector2(0, 0.1)   # sposta la sagoma verso il centro del cerchio di hit
	_bat_unit = PackedVector2Array()
	for p in meta:
		_bat_unit.append(p + centra)
	for i in range(meta.size() - 2, 0, -1):
		_bat_unit.append(Vector2(-meta[i].x, meta[i].y) + centra)


func _simbolo_pipistrello(pos: Vector2, r: float, fase: float, a: float, tono: Color) -> void:
	# Battito d'ali: le punte salgono e scendono, il corpo resta fermo
	var flap := sin(fase * VELOCITA_ALI) * 0.18
	var pts := PackedVector2Array()
	for p in _bat_unit:
		pts.append(pos + Vector2(p.x, p.y - absf(p.x) * flap) * r * 1.1)
	_riempi_e_contorna(pts, Color(0.04, 0.04, 0.04, 0.55 * a), Color(tono, a), 3.0)


# --- Spazio per i prossimi simboli -------------------------------------------
# Helper pronto per pillola e capsula: forma a "stadio" (rettangolo con estremi tondi).
# lung = lunghezza totale, r = raggio degli estremi, rot = rotazione in radianti.
func _punti_capsula(centro: Vector2, lung: float, r: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var meta := lung * 0.5 - r   # distanza dei centri dei due semicerchi dal centro
	for i in 13:
		pts.append(Vector2(meta, 0) + Vector2.from_angle(-PI / 2.0 + PI * i / 12.0) * r)
	for i in 13:
		pts.append(Vector2(-meta, 0) + Vector2.from_angle(PI / 2.0 + PI * i / 12.0) * r)
	for i in pts.size():
		pts[i] = centro + pts[i].rotated(rot)
	return pts

# Esempio di traccia per la pillola (decommenta e adatta quando vuoi usarla):
#
# func _simbolo_pillola(pos: Vector2, r: float, fase: float, a: float, tono: Color) -> void:
#	var rot := -PI / 4.0 + sin(fase) * 0.1
#	var corpo := _punti_capsula(pos, r * 2.0, r * 0.55, rot)
#	_riempi_e_contorna(corpo, Color(0.04, 0.04, 0.04, 0.55 * a), Color(tono, a), 3.0)
#	# linea al centro che divide le due metà
#	var dir := Vector2.from_angle(rot + PI / 2.0) * r * 0.55
#	draw_line(pos - dir, pos + dir, Color(tono, a), 3.0, true)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var dim_font := 52

	for n in note:
		var resta: float = n.t - tempo
		if resta > APPROCCIO:
			continue
		var k := 1.0 - clampf(resta / APPROCCIO, 0.0, 1.0)   # 0 = appena apparsa, 1 = al tempo giusto
		var a := clampf(k * 4.0, 0.0, 1.0)                    # fade-in rapido: subito visibile e cliccabile
		var tono: Color = TONI[n.tono]
		var r := RAGGIO * lerpf(0.7, 1.0, ease(k, 0.4))
		var wobble := 0.05 + 0.12 * (1.0 - ease(k, 0.5))      # appena nata ondeggia tanto, poi si assesta
		var fase: float = n.fase + tempo * 2.0

		# alone morbido
		draw_circle(n.pos, r * 1.35, Color(0, 0, 0, 0.30 * a))

		# simbolo della nota (pipistrello, cerchio, ...)
		_disegna_simbolo(n, r, wobble, fase, a, tono)

		# anello di approccio a onde che si stringe sul simbolo
		var r_app := RAGGIO + (resta / APPROCCIO) * RAGGIO * 2.0
		var anello := _forma(n.pos, maxf(r_app, r), 0.04 + 0.10 * clampf(resta / APPROCCIO, 0.0, 1.0), n.lobi + 2, -fase * 1.5)
		draw_polyline(anello, Color(1, 1, 1, a * 0.5), 2.5, true)

		# lettera centrata, opacizzata
		var w := font.get_string_size(n.lettera, HORIZONTAL_ALIGNMENT_LEFT, -1, dim_font).x
		var y_off := (font.get_ascent(dim_font) - font.get_descent(dim_font)) / 2.0
		draw_string(font, n.pos + Vector2(-w / 2.0, y_off), n.lettera, HORIZONTAL_ALIGNMENT_LEFT, -1, dim_font, Color(1, 1, 1, a * 0.45))

	# Onde alla pressione: 3 anelli a moduli che si espandono sfalsati
	var ora := Time.get_ticks_msec() / 1000.0
	for o in onde:
		for j in 3:
			var k: float = (ora - o.nascita - j * 0.08) / 0.55
			if k <= 0.0 or k >= 1.0:
				continue
			var raggio := lerpf(RAGGIO, RAGGIO * (2.4 + j * 0.5), ease(k, 0.3))
			var forma := _forma(o.pos, raggio, 0.14 * (1.0 - k), o.lobi + j, o.fase + k * 3.0 + j)
			draw_polyline(forma, Color(o.colore, 1.0 - k), lerpf(5.0, 1.0, k), true)
