extends CanvasLayer

# Autoload "Transizione": chiusura a cerchio (iris) sull'ultimo click/tap, stile Looney Tunes.
# Uso:  Transizione.vai("res://scene/gioco.tscn", "gioco")
#       Transizione.vai("res://scene/gioco.tscn", "gioco", {"canzone": "Boombap.mp3", "sfondo_uso": 3})
#       Transizione.vai("res://scene/gioco.tscn", "gioco", {}, Vector2(200, 300))  # punto forzato
# Segnali: coperta (schermo tutto nero, scena già cambiata), finita (cerchio aperto)

signal coperta
signal finita

@export var sempre_al_centro := true   # true = il cerchio si chiude sempre in mezzo allo schermo

# una config per tipo: durate (secondi), colore di riempimento, suono
const TIPI := {
	"menu": {
		"dentro": 0.7, "fuori": 0.7,
		"colore": Color(0.0, 0.0, 0.0),
		"suono": "res://resource/sfx/tunnel_menu.mp3",
	},
	"gioco": {
		"dentro": 0.9, "fuori": 0.8,
		"colore": Color(0.0, 0.0, 0.0),
		"suono": "res://resource/sfx/tunnel_gioco.mp3",
	},
}

const SHADER := """
shader_type canvas_item;

uniform vec2 dimensione = vec2(1280.0, 720.0);  // dimensione del viewport
uniform vec2 centro = vec2(640.0, 360.0);       // punto dell'ultimo click
uniform float raggio = 2000.0;                  // raggio del cerchio ancora visibile
uniform float morbidezza = 1.5;                 // sfumatura del bordo in pixel
uniform vec4 colore : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	float d = distance(UV * dimensione, centro);
	float a = smoothstep(raggio - morbidezza, raggio + morbidezza, d);
	// a raggio 0 lo schermo deve essere completamente coperto
	a = mix(a, 1.0, step(raggio, 0.001));
	COLOR = vec4(colore.rgb, a);
}
"""

var in_corso := false
var rect: ColorRect
var mat: ShaderMaterial
var audio: AudioStreamPlayer
var ultimo_click := Vector2(-1, -1)   # (-1,-1) = nessun click ancora: si usa il centro schermo


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS   # funziona anche con il gioco in pausa

	rect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_STOP   # blocca i click sulla UI durante la transizione
	rect.visible = false
	var sh := Shader.new()
	sh.code = SHADER
	mat = ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	audio = AudioStreamPlayer.new()
	add_child(audio)


# _input arriva prima della UI, quindi vede anche i click sui bottoni.
# Tocco e mouse sono tracciati entrambi: su mobile Godot può emulare il mouse dal tocco,
# ma la posizione è la stessa.
func _input(event: InputEvent) -> void:
	if in_corso:
		return
	if event is InputEventScreenTouch and event.pressed:
		ultimo_click = event.position
	elif event is InputEventMouseButton and event.pressed:
		ultimo_click = event.position


func vai(path: String, tipo := "menu", params := {}, punto := Vector2(-1, -1)) -> void:
	if in_corso:
		return
	if not ResourceLoader.exists(path):
		push_error("Transizione: scena non trovata: " + path)
		return

	var cfg: Dictionary = TIPI.get(tipo, TIPI["menu"])
	in_corso = true

	# punto di chiusura: quello passato, altrimenti l'ultimo click, altrimenti il centro
	var dim := get_viewport().get_visible_rect().size
	var centro := dim * 0.5
	if not sempre_al_centro:
		centro = punto if punto.x >= 0.0 else ultimo_click
		if centro.x < 0.0:
			centro = dim * 0.5
	centro = centro.clamp(Vector2.ZERO, dim)

	# raggio necessario per coprire tutto lo schermo partendo da quel punto
	var r_max := 0.0
	for angolo in [Vector2.ZERO, Vector2(dim.x, 0.0), Vector2(0.0, dim.y), dim]:
		r_max = maxf(r_max, centro.distance_to(angolo))
	r_max += 8.0

	mat.set_shader_parameter("dimensione", dim)
	mat.set_shader_parameter("centro", centro)
	mat.set_shader_parameter("colore", cfg["colore"])
	mat.set_shader_parameter("raggio", r_max)
	rect.visible = true

	# suono (se il file non c'è, resta muto senza errori)
	if ResourceLoader.exists(cfg["suono"]):
		audio.stream = load(cfg["suono"])
		audio.play()

	# la scena si carica in background mentre il cerchio si chiude
	ResourceLoader.load_threaded_request(path)
	await _anima(r_max, 0.0, cfg["dentro"], Tween.EASE_IN)

	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame

	var scena := ResourceLoader.load_threaded_get(path) as PackedScene
	if scena == null:
		push_error("Transizione: caricamento fallito: " + path)
		rect.visible = false
		in_corso = false
		return

	# swap manuale: i parametri vengono impostati PRIMA che parta il _ready della nuova scena
	var nuova: Node = scena.instantiate()
	for chiave in params:
		nuova.set(chiave, params[chiave])
	var vecchia := get_tree().current_scene
	get_tree().root.add_child(nuova)
	get_tree().current_scene = nuova
	if vecchia:
		vecchia.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	coperta.emit()

	await _anima(0.0, r_max, cfg["fuori"], Tween.EASE_OUT)
	rect.visible = false
	in_corso = false
	finita.emit()


func _anima(da: float, a: float, durata: float, easing: Tween.EaseType) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(easing)
	tw.tween_method(func(v): mat.set_shader_parameter("raggio", v), da, a, durata)
	await tw.finished
