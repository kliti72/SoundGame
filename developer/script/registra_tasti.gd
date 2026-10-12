extends Node2D

@onready var musica: AudioStreamPlayer = $AudioStreamPlayer

const RAGGIO := 50.0
const APPROCCIO := 1.0
const FINESTRA := 0.35               # tolleranza in secondi per assegnare la lettera
const VELOCITA := [1.0, 0.5, 0.25]

var scelta := OptionButton.new()
var conferma := ConfirmationDialog.new()
var canzoni: Array[String] = []
var file_canzone := ""
var note: Array = []
var modificato := false
var indice_velocita := 0
var tempo := 0.0


func _ready() -> void:
	canzoni = SongDB.file_musicali()
	if canzoni.is_empty():
		push_error("Nessuna canzone in " + SongDB.CARTELLA)
		return

	scelta.focus_mode = Control.FOCUS_NONE
	scelta.position = Vector2(20, 50)
	for i in canzoni.size():
		scelta.add_item(_etichetta(i))
	scelta.item_selected.connect(_apri)
	add_child(scelta)

	var reset := Button.new()
	reset.text = "Cancella lettere"
	reset.focus_mode = Control.FOCUS_NONE
	reset.position = Vector2(300, 50)
	reset.pressed.connect(conferma.popup_centered)
	add_child(reset)

	conferma.dialog_text = "Cancello tutte le lettere di questa canzone?"
	conferma.confirmed.connect(_reset)
	add_child(conferma)

	musica.finished.connect(_salva)
	_apri(0)


# ● tutte le note hanno la lettera, ◐ solo alcune, ○ nessuna
func _etichetta(i: int) -> String:
	var tutte := SongDB.note_di(canzoni[i])
	var con := tutte.filter(func(n): return n.get("lettera", "") != "").size()
	var simbolo := "○" if con == 0 else ("●" if con == tutte.size() else "◐")
	return "%s %s (%d/%d)" % [simbolo, canzoni[i], con, tutte.size()]


func _reset() -> void:
	for n in note:
		n.erase("lettera")
	modificato = true
	_salva()


func _apri(i: int) -> void:
	_salva()
	scelta.select(i)
	file_canzone = canzoni[i]
	note = SongDB.note_di(file_canzone)
	modificato = false
	musica.pitch_scale = VELOCITA[indice_velocita]
	musica.stream = load(SongDB.CARTELLA + file_canzone)
	musica.play()


func _salva() -> void:
	if not modificato or file_canzone == "":
		return
	var titolo: String = SongDB.trova(file_canzone).get("titolo", file_canzone.get_basename())
	if SongDB.salva(file_canzone, titolo, note):
		modificato = false
		var i := canzoni.find(file_canzone)
		scelta.set_item_text(i, _etichetta(i))
		print("Salvata '%s'" % titolo)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_salva()


func _process(_d: float) -> void:
	tempo = musica.get_playback_position()
	queue_redraw()


# Nota più vicina nel tempo entro la finestra (null se non ce ne sono)
func _piu_vicina() -> Variant:
	var migliore = null
	var minimo := FINESTRA
	for n in note:
		var d := absf(tempo - n.t)
		if d <= minimo:
			migliore = n
			minimo = d
	return migliore


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return

	if e.ctrl_pressed and e.keycode == KEY_S:
		_salva()
		return

	# Lettere A-Z: assegnano la lettera alla nota più vicina
	if e.keycode >= KEY_A and e.keycode <= KEY_Z and not e.ctrl_pressed:
		var n = _piu_vicina()
		if n:
			n["lettera"] = char(e.keycode)
			modificato = true
		return

	match e.keycode:
		KEY_SPACE: musica.stream_paused = not musica.stream_paused
		KEY_LEFT: musica.seek(maxf(0.0, tempo - 2.0))
		KEY_RIGHT: musica.seek(tempo + 2.0)
		KEY_BACKSPACE:
			var n = _piu_vicina()
			if n and n.has("lettera"):
				n.erase("lettera")
				modificato = true
		KEY_TAB:
			indice_velocita = (indice_velocita + 1) % VELOCITA.size()
			musica.pitch_scale = VELOCITA[indice_velocita]


func _visibile(n: Dictionary) -> bool:
	return tempo >= n.t - APPROCCIO and tempo <= n.t + 0.5


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var bersaglio = _piu_vicina()

	for n in note:
		if not _visibile(n):
			continue
		var lettera: String = n.get("lettera", "")
		var colore := Color(0.3, 1.0, 0.5) if lettera != "" else Color(1, 0.4, 0.7)
		draw_circle(n.pos, RAGGIO, Color(colore, 0.3))
		draw_arc(n.pos, RAGGIO, 0, TAU, 64, Color.YELLOW if n == bersaglio else colore, 4.0 if n == bersaglio else 3.0)
		if lettera != "":
			var w := font.get_string_size(lettera, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
			draw_string(font, n.pos + Vector2(-w / 2.0, 14), lettera, HORIZONTAL_ALIGNMENT_LEFT, -1, 40)

	var con := note.filter(func(n): return n.get("lettera", "") != "").size()
	var info := "t=%.2f | x%s | lettere: %d/%d%s" % [tempo, VELOCITA[indice_velocita], con, note.size(), " *" if modificato else ""]
	draw_string(font, Vector2(20, 30), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	draw_string(font, Vector2(20, 100), "A-Z assegna | Backspace toglie | Spazio pausa | ←/→ ±2s | Tab velocità | Ctrl+S salva", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.6))
