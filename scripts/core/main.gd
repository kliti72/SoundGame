extends Node2D
## Core: musica, sfondo, punteggio/combo, effetti, NPC e cambio scena.
## Le note sono gestite da CampoNote (campo_note.gd), i disegni da SimboliNote.

@export var canzone := "Boombap.mp3"
@export_range(0, 5) var sfondo_uso := 0   # 0 = casuale, 1..5 = sfondo fisso
## Tipo di note (usato per le note senza "simbolo" nel JSON). Tieni allineato con SimboliNote.ELENCO
@export_enum("pipistrello", "cerchio", "pillola") var tipo_note := "pillola"

signal pause_premuto

@onready var musica: AudioStreamPlayer = $AudioStreamPlayer
@onready var sfondi: Array = [$SceneGlitchMonitorTheme, $BackgroundCity, $BackgroundRedWaterScene, $BackgroundForestRain, $BackgroundGraffitiWall]
@onready var game_header: Control = $CanvasLayer/GameHeader
@onready var _npc: Personaggio = $ManagerTeppistello/Control/MarginContainer/Personaggio
@onready var manager_tep: CanvasLayer = $ManagerTeppistello
@onready var pause_button : Button = $CanvasLayer/MarginContainer2/MarginContainer/PauseButton

const VELOCITA := [0.5, 0.3, 3.0, 0.5, 0.5]   # una per sfondo, nello stesso ordine
const PALETTE := [Color(1.0, 0.1, 0.15), Color(0.6, 0.2, 1.0), Color(0.1, 0.9, 1.0)]
const NOTE_NPC := 3                            # alla quale nota parla l'NPC

var sfondo
var campo: CampoNote
var cam: Camera2D
var punteggio := 0
var combo := 0
var serie := 0
var soglia := randi_range(3, 5)
var note_prese := 0


func _ready() -> void:
	MusicaGlobale.stop(0.5)
	_scegli_sfondo()

	campo = CampoNote.new()
	campo.simbolo_default = tipo_note
	add_child(campo)
	if not campo.carica(musica, canzone):
		return
	campo.colpita.connect(_on_colpita)
	campo.mancata.connect(_on_mancata)

	cam = Camera2D.new()
	cam.position = get_viewport_rect().size / 2.0
	add_child(cam)

	sfondo.segui_musica(musica)
	musica.finished.connect(_fine_canzone)
	musica.stream = load("res://resource/musica/" + canzone)
	musica.play()
	manager_tep.visible = false
	
	pause_button.pressed.connect(on_pause_button)

func on_pause_button():
	pause_premuto.emit()  
	Transizione.vai("res://game/GameSongSelectorPage.tscn")
	queue_free()           # chiude la scena corrente



func _scegli_sfondo() -> void:
	var scelta := sfondo_uso - 1 if sfondo_uso > 0 else randi() % sfondi.size()
	sfondo = sfondi[scelta]
	for i in sfondi.size():
		if i != scelta:
			sfondi[i].queue_free()
	sfondo.velocita = VELOCITA[scelta]


# --- Eventi delle note ---------------------------------------------------------

func _on_colpita(n: Dictionary) -> void:
	note_prese += 1
	combo += 1
	serie += 1

	var guadagno: int = 100 * (1 + floori(combo / 10.0))
	punteggio += guadagno

	var colore := Color.WHITE
	var burst := serie >= soglia
	if burst:
		serie = 0
		soglia = randi_range(3, 5)
		colore = PALETTE.pick_random()
		sfondo.burst_colore(colore)

	_esplosione(n.pos, colore, 44 if burst else 26)
	campo.onda(n, colore)
	_popup(n.pos, "HIT", colore)
	sfondo.pulse()
	_shake(6.0 if burst else 2.5)

	game_header.aggiorna_combo(combo)
	game_header.aggiorna_punteggio(punteggio, guadagno)
	if note_prese == NOTE_NPC:
		_dialogo_npc()


func _on_mancata(pos: Vector2) -> void:
	combo = 0
	serie = 0
	_popup(pos, "MISS", Color(0.4, 0.4, 0.4))


func _dialogo_npc() -> void:
	manager_tep.visible = true
	manager_tep.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	await _npc.parla("benvenuto_song_2", [
		"...",
		"Fratello Sei Fast, hai già capito come ascoltare le mie basi",
		"...",
		"Bravo fratello hai già capito la wave da solo sono le tue prime 3 Note.",
		"....",
		"Ogni nota GUADAGNI CAP",
		"...",
		"Oggi niente OPS per me. Che fortuna",
	])
	manager_tep.visible = false
	get_tree().paused = false


func _fine_canzone() -> void:
	campo.ferma()   # niente input durante la transizione
	
	Transizione.vai("res://game/CompleteSong.tscn", "gioco", {
		"canzone_suonata": canzone,
		"note_prese": note_prese,
		"monete_guadagnate" : game_header.label.text.to_int()
	})


# --- Effetti -------------------------------------------------------------------

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
	l.position = pos + Vector2(-28, -CampoNote.RAGGIO * 1.5)
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
