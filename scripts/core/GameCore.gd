extends Node2D

@export var canzone := "Boombap.mp3"
@export_range(0, 3) var sfondo_uso := 0   # 0 = a caso, 1 = glitch, 2 = città luna, 3 = strada rossa

@onready var musica: AudioStreamPlayer = $AudioStreamPlayer
@onready var sfondi: Array = [$SceneGlitchMonitorTheme, $BackgroundCity, $BackgroundRedWaterScene]

const VELOCITA := [0.5, 0.3, 3.0]   # una per sfondo, nello stesso ordine
var sfondo   # quello attivo, senza tipo fisso

const RAGGIO := 26.0
const APPROCCIO := 1.0
const PERFECT := 0.06
const GOOD := 0.15
const TONI := [Color(0.92, 0.92, 0.92), Color(0.55, 0.55, 0.55), Color(0.30, 0.30, 0.30)]
const PALETTE := [Color(1.0, 0.1, 0.15), Color(0.6, 0.2, 1.0), Color(0.1, 0.9, 1.0)]

var note: Array = []
var onde: Array = []
var tempo := 0.0
var punteggio := 0
var combo := 0
var serie := 0
var soglia := randi_range(3, 5)

var cam: Camera2D
var label: Label


var note_prese := 0
var note_totali := 0


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
			for i in punti.size():
				note.append({"t": punti[i]["t"], "pos": Vector2(punti[i]["x"], punti[i]["y"]), "tono": i % 3})

	_crea_ui()
	sfondo.segui_musica(musica)

	musica.finished.connect(func(): Player.registra_punteggio(canzone, punteggio))
	musica.stream = load("res://resource/musica/" + canzone)
	musica.play()
	
	note_totali = note.size()

	_crea_ui()
	sfondo.segui_musica(musica)

	musica.finished.connect(_fine_canzone)
	musica.stream = load("res://resource/musica/" + canzone)
	musica.play()


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
		if tempo > note[i].t + GOOD:
			_miss(note[i].pos)
			note.remove_at(i)

	var ora := Time.get_ticks_msec() / 1000.0
	onde = onde.filter(func(o): return ora - o.nascita < 0.45)

	label.text = "%d   x%d" % [punteggio, combo]
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var mouse := get_global_mouse_position()
	for n in note:
		var errore := absf(tempo - n.t)
		if errore <= GOOD and mouse.distance_to(n.pos) <= RAGGIO * 1.3:
			_colpita(n, errore <= PERFECT)
			break


func _colpita(n: Dictionary, perfetto: bool) -> void:
	note.erase(n)
	note_prese += 1
	combo += 1
	combo += 1
	serie += 1
	punteggio += (300 if perfetto else 100) * (1 + floori(combo / 10.0))

	var colore: Color = Color.WHITE if perfetto else Color(0.6, 0.6, 0.6)
	var burst := serie >= soglia
	if burst:
		serie = 0
		soglia = randi_range(3, 5)
		colore = PALETTE.pick_random()
		sfondo.burst_colore(colore)

	_esplosione(n.pos, colore, 40 if burst else (28 if perfetto else 14))
	onde.append({"pos": n.pos, "nascita": Time.get_ticks_msec() / 1000.0, "colore": colore})
	_popup(n.pos, "PERFECT" if perfetto else "GOOD", colore)
	sfondo.pulse()
	if perfetto:
		_shake(4.0)


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
	p.lifetime = 0.5
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 100.0
	p.initial_velocity_max = 300.0
	p.damping_min = 150.0
	p.damping_max = 250.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
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
	l.position = pos + Vector2(-30, -RAGGIO * 2.0)
	l.modulate = colore
	l.add_theme_font_size_override("font_size", 18)
	add_child(l)
	var tw := create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 30.0, 0.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(l.queue_free)


func _shake(forza: float) -> void:
	var tw := create_tween()
	for i in 4:
		tw.tween_property(cam, "offset", Vector2(randf_range(-forza, forza), randf_range(-forza, forza)), 0.03)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.05)


func _draw() -> void:
	for n in note:
		var resta: float = n.t - tempo
		if resta > APPROCCIO:
			continue
		var a := 1.0 - clampf(resta / APPROCCIO, 0.0, 1.0)
		var tono: Color = TONI[n.tono]
		var r := RAGGIO * lerpf(0.6, 1.0, ease(a, 0.4))
		draw_circle(n.pos, r * 1.5, Color(0, 0, 0, 0.35 * a))
		draw_circle(n.pos, r, Color(0.04, 0.04, 0.04, a))
		draw_arc(n.pos, r, 0.0, TAU, 40, Color(tono, a), 3.0, true)
		draw_circle(n.pos, r * 0.25, Color(tono, a * 0.8))
		draw_arc(n.pos, RAGGIO + maxf(resta, 0.0) / APPROCCIO * RAGGIO * 3.0, 0.0, TAU, 48, Color(1, 1, 1, a * 0.6), 2.0, true)

	var ora := Time.get_ticks_msec() / 1000.0
	for o in onde:
		var k: float = (ora - o.nascita) / 0.45
		draw_arc(o.pos, lerpf(RAGGIO, RAGGIO * 4.0, ease(k, 0.3)), 0.0, TAU, 48, Color(o.colore, 1.0 - k), 3.0, true)
	
func _fine_canzone() -> void:
	set_process(false)
	set_process_input(false)   # niente click durante la transizione
	Transizione.vai("res://game/CompleteSong.tscn", "gioco", {
		"file_canzone": canzone,
		"note_prese": note_prese,
		"note_totali": note_totali,
	})
