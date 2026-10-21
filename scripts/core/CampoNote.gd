class_name CampoNote
extends Node2D
## Gestisce le note: caricamento dal JSON, timing, input, ingresso dai bordi e disegno.
## NON conosce punteggio, combo, scene: comunica col gioco solo tramite i segnali.

signal colpita(nota: Dictionary)
signal mancata(pos: Vector2)

const RAGGIO := 65.0
const APPROCCIO := 1.0       # da quanto prima appare la nota (ed è già cliccabile)
const TOLLERANZA := 0.15     # quanto dopo t la nota resta cliccabile prima del miss
const MARGINE := RAGGIO * 1.5   # quanto fuori dallo schermo parte il simbolo
# Frazione di APPROCCIO alla quale il simbolo è arrivato; il resto è "assestamento" (ali/occhi, rimbalzo)
const ATTERRAGGIO := {"bordo": 0.75, "caduta": 0.85}
const LETTERE := "ASDFGHJKLQPWOEIRUTYMZNXCBV"
const TONI := [Color(0.92, 0.92, 0.92), Color(0.55, 0.55, 0.55), Color(0.30, 0.30, 0.30)]
var mostra_lettere := not Piattaforma.is_mobile

var simbolo_default: String = SimboliNote.DEFAULT   # per le note senza "simbolo" nel JSON
var note: Array = []
var totali := 0
var tempo := 0.0

var _musica: AudioStreamPlayer
var _onde: Array = []


func _ready() -> void:
	
	set_process(false)
	set_process_input(false)


## Carica le note della canzone e avvia l'elaborazione. Ritorna false se il JSON non va.
func carica(musica: AudioStreamPlayer, canzone: String) -> bool:
	_musica = musica
	var dati = JSON.parse_string(FileAccess.get_file_as_string("res://data/song_data.json"))
	if dati == null:
		push_error("song_data.json mancante o non valido")
		return false

	for voce in dati["canzoni"]:
		if voce["file"] != canzone:
			continue
		var recenti: Array = []
		var punti: Array = voce["note"]
		for i in punti.size():
			var p: Dictionary = punti[i]
			var lettera: String = p.get("lettera", "")
			if lettera == "":
				lettera = _lettera_casuale(recenti)
			recenti.append(lettera)
			if recenti.size() > 4:
				recenti.pop_front()
			var pos := Vector2(p["x"], p["y"])
			var simbolo: String = p.get("simbolo", simbolo_default)
			var ingresso: String = p.get("ingresso", SimboliNote.INGRESSO.get(simbolo, "bordo"))
			note.append({
				"t": p["t"],
				"pos": pos,
				"origine": _origine(pos, ingresso),
				"ingresso": ingresso,
				"tono": i % 3,
				"lettera": lettera,
				"simbolo": simbolo,
				"fase": randf() * TAU,
			})
	totali = note.size()
	set_process(true)
	set_process_input(true)
	return true


func ferma() -> void:
	set_process(false)
	set_process_input(false)


## Aggiunge le onde che si espandono quando una nota viene colpita
func onda(n: Dictionary, colore: Color) -> void:
	_onde.append({"pos": n.pos, "nascita": _ora(), "colore": colore})


# --- Logica ------------------------------------------------------------------

func _process(_delta: float) -> void:
	tempo = _musica.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()

	for i in range(note.size() - 1, -1, -1):
		if tempo > note[i].t + TOLLERANZA:
			mancata.emit(note[i].pos)
			note.remove_at(i)

	_onde = _onde.filter(func(o): return _ora() - o.nascita < 0.8)
	queue_redraw()


func _input(event: InputEvent) -> void:
	# Tastiera: lettera della nota cliccabile più vicina nel tempo
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_A and event.keycode <= KEY_Z:
			_prova_tasto(char(event.keycode))
		return

	# Mouse/touch: click sul punto di arrivo (dove si stringe l'anello)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse := get_global_mouse_position()
		for n in note:
			if _cliccabile(n) and mouse.distance_to(n.pos) <= RAGGIO * 1.15:
				_colpisci(n)
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
		_colpisci(migliore)


const VIBRAZIONE_MS := 20   # corta, sennò con le note veloci ti trema il telefono
var vibrazione_attiva := true   # collegabile a un'opzione nelle impostazioni

func _colpisci(n: Dictionary) -> void:
	note.erase(n)
	_vibra()
	colpita.emit(n)

func _vibra() -> void:
	if vibrazione_attiva and OS.has_feature("mobile"):
		Input.vibrate_handheld(VIBRAZIONE_MS)

func _cliccabile(n: Dictionary) -> bool:
	var resta: float = n.t - tempo
	return resta <= APPROCCIO and resta >= -TOLLERANZA


func _lettera_casuale(escluse: Array) -> String:
	var pool: Array = []
	for c in LETTERE:
		if c not in escluse:
			pool.append(c)
	return pool.pick_random()


func _ora() -> float:
	return Time.get_ticks_msec() / 1000.0


## Da dove parte il simbolo (fuori dallo schermo)
func _origine(pos: Vector2, ingresso: String) -> Vector2:
	if ingresso == "caduta":
		return Vector2(pos.x, -MARGINE)   # sopra di sé, fuori dallo schermo

	# "bordo": punto sul bordo nella direzione centro -> nota
	var meta := get_viewport_rect().size / 2.0
	var dir := (pos - meta).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	var sx := INF if is_zero_approx(dir.x) else (meta.x + MARGINE) / absf(dir.x)
	var sy := INF if is_zero_approx(dir.y) else (meta.y + MARGINE) / absf(dir.y)
	return meta + dir * minf(sx, sy)


## Posizione corrente del simbolo. k: 0 = appena apparso, 1 = al tempo giusto
func _posizione(n: Dictionary, k: float) -> Vector2:
	match n.ingresso:
		"caduta":
			# accelera come in caduta libera, poi un piccolo rimbalzo all'atterraggio
			var att: float = ATTERRAGGIO["caduta"]
			var caduta := clampf(k / att, 0.0, 1.0)
			var u := clampf((k - att) / (1.0 - att), 0.0, 1.0)
			return n.origine.lerp(n.pos, ease(caduta, 2.2)) - Vector2(0, sin(u * PI) * RAGGIO * 0.3)
		_:
			# "bordo": veloce all'inizio, dolce all'arrivo
			return n.origine.lerp(n.pos, ease(k, 0.5))


# --- Disegno -------------------------------------------------------------------

func _draw() -> void:
	var font := ThemeDB.fallback_font
	const DIM_FONT := 52

	for n in note:
		var resta: float = n.t - tempo
		if resta > APPROCCIO:
			continue
		var k := 1.0 - clampf(resta / APPROCCIO, 0.0, 1.0)   # 0 = appena apparsa, 1 = al tempo giusto
		var a := clampf(k * 6.0, 0.0, 1.0)
		var r := RAGGIO * lerpf(0.7, 1.0, ease(k, 0.4))
		var fase: float = n.fase + tempo * 2.0
		var att: float = ATTERRAGGIO.get(n.ingresso, 0.75)
		var pos := _posizione(n, k)

		var s := {
			"r": r,
			"fase": fase,
			"a": a,
			"tono": TONI[n.tono],
			"ali": lerpf(0.40, 0.15, ease(k, 0.5)),                                  # battito ampio in volo, calmo all'arrivo
			"apertura": ease(clampf((k - att) / (1.0 - att), 0.0, 1.0), 0.5),     # 0 = in arrivo, 1 = arrivato
		}

		draw_circle(pos, r * 1.35, Color(0, 0, 0, 0 * a))     # alone
		SimboliNote.disegna(self, n, pos, s)

		# anello di approccio: resta sul punto di arrivo e si stringe
		var r_app := RAGGIO + (resta / APPROCCIO) * RAGGIO * 2.0
		draw_arc(n.pos, maxf(r_app, r), 0.0, TAU, 64, Color(1, 1, 1, a * 0.5), 2.5, true)

		# lettera centrata sul simbolo
		if mostra_lettere:
			var w := font.get_string_size(n.lettera, HORIZONTAL_ALIGNMENT_LEFT, -1, DIM_FONT).x
			var y_off := (font.get_ascent(DIM_FONT) - font.get_descent(DIM_FONT)) / 2.0
			draw_string(font, pos + Vector2(-w / 2.0, y_off), n.lettera, HORIZONTAL_ALIGNMENT_LEFT, -1, DIM_FONT, Color(1, 1, 1, a * 0.45))

	# Onde alla pressione: 3 anelli che si espandono sfalsati
	for o in _onde:
		for j in 3:
			var k: float = (_ora() - o.nascita - j * 0.08) / 0.55
			if k <= 0.0 or k >= 1.0:
				continue
			var raggio := lerpf(RAGGIO, RAGGIO * (2.4 + j * 0.5), ease(k, 0.3))
			draw_arc(o.pos, raggio, 0.0, TAU, 64, Color(o.colore, 1.0 - k), lerpf(5.0, 1.0, k), true)
