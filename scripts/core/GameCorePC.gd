extends Node2D

@export var canzone := "Boombap.mp3"
@export_range(0, 3) var sfondo_uso := 0   # 0 = a caso, 1 = glitch, 2 = città luna, 3 = strada rossa

@onready var musica: AudioStreamPlayer = $AudioStreamPlayer
@onready var sfondi: Array = [$SceneGlitchMonitorTheme, $BackgroundCity, $BackgroundRedWaterScene, $BackgroundForestRain, $BackgroundGraffitiWall]

const VELOCITA := [0.5, 0.3, 3.0, 0.5, 0.5]   # una per sfondo, nello stesso ordine
const LETTERE := "QWERTYUIOPASDFGHJKLZXCVBNM"
const RAGGIO := 65.0            # era 26 -> x2.5
const APPROCCIO := 1.0          # da quanto prima appare la nota (ed è già cliccabile)
const TOLLERANZA := 0.15        # quanto dopo t la nota resta cliccabile prima del miss
const TONI := [Color(0.92, 0.92, 0.92), Color(0.55, 0.55, 0.55), Color(0.30, 0.30, 0.30)]
const PALETTE := [Color(1.0, 0.1, 0.15), Color(0.6, 0.2, 1.0), Color(0.1, 0.9, 1.0)]

var sfondo   # quello attivo, senza tipo fisso
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


func _ready() -> void:
	MusicaGlobale.stop(0.5)

	var scelta := sfondo_uso - 1 if sfondo_uso > 0 else randi() % sfondi.size()
	sfondo = sfondi[scelta]
	for i in sfondi.size():
		if i != scelta:
			sfondi[i].queue_free()   # gli altri spariscono, niente sovrapposizioni
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
					"lobi": 5 + (i % 3),          # numero di "petali" dell'onda
					"fase": randf() * TAU,        # ogni cerchio ondeggia in modo diverso
				})
	note_totali = note.size()

	_crea_ui()
	sfondo.segui_musica(musica)
	musica.finished.connect(_fine_canzone)
	musica.stream = load("res://resource/musica/" + canzone)
	musica.play()


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
	sfondo.combo = combo

	for i in range(note.size() - 1, -1, -1):
		if tempo > note[i].t + TOLLERANZA:
			_miss(note[i].pos)
			note.remove_at(i)

	var ora := Time.get_ticks_msec() / 1000.0
	onde = onde.filter(func(o): return ora - o.nascita < 0.8)

	label.text = "%d   x%d" % [punteggio, combo]
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

	# Mouse / touch: click sul cerchio (la prima nota in lista è la più vicina nel tempo)
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
	punteggio += 100 * (1 + floori(combo / 10.0))

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


# Cerchio "a moduli": il raggio ondeggia con sin(angolo * lobi + fase), chiuso su se stesso
func _forma(centro: Vector2, raggio: float, ampiezza: float, lobi: int, fase: float, punti := 72) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in punti + 1:
		var ang := TAU * i / punti
		var r := raggio * (1.0 + ampiezza * sin(ang * lobi + fase))
		pts.append(centro + Vector2(cos(ang), sin(ang)) * r)
	return pts


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

		# corpo a moduli, semitrasparente
		var corpo := _forma(n.pos, r, wobble, n.lobi, fase)
		draw_polyline(corpo, Color(tono, a), 4.0, true)
		corpo.remove_at(corpo.size() - 1)   # via il punto duplicato per il poligono pieno
		draw_colored_polygon(corpo, Color(0.04, 0.04, 0.04, 0.55 * a))

		# anello di approccio a onde che si stringe sul cerchio
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
