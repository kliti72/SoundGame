extends Node2D

@onready var musica: AudioStreamPlayer = $AudioStreamPlayer

const RAGGIO := 50.0
const APPROCCIO := 1.0
const VELOCITA := [1.0, 0.5, 0.25]

var scelta := OptionButton.new()
var sfondo_spin := SpinBox.new()
var prezzo_spin := SpinBox.new()
var canzoni: Array[String] = []
var file_canzone := ""
var note: Array = []
var sfondo := 1
var prezzo := 0   # PREZZO
var modificato := false
var indice_velocita := 0
var tempo := 0.0
var conferma := ConfirmationDialog.new()


func _ready() -> void:
	canzoni = SongDB.file_musicali()
	if canzoni.is_empty():
		push_error("Nessuna canzone in " + SongDB.CARTELLA)
		return

	# menu canzoni
	scelta.focus_mode = Control.FOCUS_NONE
	scelta.position = Vector2(20, 50)
	for i in canzoni.size():
		scelta.add_item(_etichetta(i))
	scelta.item_selected.connect(_apri)
	add_child(scelta)

	# bottone reset
	var reset := Button.new()
	reset.text = "Reset note"
	reset.focus_mode = Control.FOCUS_NONE
	reset.position = Vector2(300, 50)
	reset.pressed.connect(conferma.popup_centered)
	add_child(reset)

	# selettore sfondo 1-10
	var lbl := Label.new()
	lbl.text = "Sfondo:"
	lbl.position = Vector2(420, 54)
	add_child(lbl)

	sfondo_spin.min_value = 1
	sfondo_spin.max_value = 10
	sfondo_spin.step = 1
	sfondo_spin.rounded = true
	sfondo_spin.value = 1
	sfondo_spin.position = Vector2(490, 50)
	sfondo_spin.get_line_edit().focus_mode = Control.FOCUS_NONE   # spazio non lo tocca
	sfondo_spin.value_changed.connect(_sfondo_cambiato)
	add_child(sfondo_spin)

	# PREZZO: selettore 0-100000 (0 = gratis)
	var lbl_prezzo := Label.new()
	lbl_prezzo.text = "Prezzo:"
	lbl_prezzo.position = Vector2(720, 54)
	add_child(lbl_prezzo)

	prezzo_spin.min_value = 0
	prezzo_spin.max_value = 100000
	prezzo_spin.step = 1
	prezzo_spin.rounded = true
	prezzo_spin.value = 0
	prezzo_spin.position = Vector2(790, 50)
	prezzo_spin.get_line_edit().focus_mode = Control.FOCUS_NONE   # spazio non lo tocca
	prezzo_spin.value_changed.connect(_prezzo_cambiato)
	add_child(prezzo_spin)

	conferma.dialog_text = "Cancello tutte le note di questa canzone?"
	conferma.confirmed.connect(_reset)
	add_child(conferma)

	musica.finished.connect(_salva)
	_apri(0)


func _sfondo_cambiato(v: float) -> void:
	sfondo = int(v)
	modificato = true


func _prezzo_cambiato(v: float) -> void:   # PREZZO
	prezzo = int(v)
	modificato = true


func _etichetta(i: int) -> String:
	var n := SongDB.note_di(canzoni[i]).size()
	return ("● %s (%d)" % [canzoni[i], n]) if n > 0 else ("○ %s" % canzoni[i])


func _reset() -> void:
	note.clear()
	modificato = true
	_salva()


func _apri(i: int) -> void:
	_salva()
	scelta.select(i)
	file_canzone = canzoni[i]
	note = SongDB.note_di(file_canzone)
	sfondo = SongDB.sfondo_di(file_canzone)
	sfondo_spin.set_value_no_signal(sfondo)   # non segna "modificato" al caricamento
	prezzo = SongDB.prezzo_di(file_canzone)   # PREZZO
	prezzo_spin.set_value_no_signal(prezzo)   # PREZZO
	modificato = false
	musica.pitch_scale = VELOCITA[indice_velocita]
	musica.stream = load(SongDB.CARTELLA + file_canzone)
	musica.play()


func _salva() -> void:
	if not modificato or file_canzone == "":
		return
	var titolo: String = SongDB.trova(file_canzone).get("titolo", file_canzone.get_basename())
	if SongDB.salva(file_canzone, titolo, note, sfondo, prezzo):   # PREZZO
		modificato = false
		var i := canzoni.find(file_canzone)
		scelta.set_item_text(i, _etichetta(i))
		print("Salvata '%s': %d note, sfondo %d, prezzo %d" % [titolo, note.size(), sfondo, prezzo])


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_salva()   # chiudi la finestra, non perdi niente


func _process(_d: float) -> void:
	tempo = musica.get_playback_position()
	queue_redraw()


func _unhandled_input(e: InputEvent) -> void:   # i click sul menu non arrivano qua
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_LEFT:
			note.append({"t": tempo, "pos": e.position})
			modificato = true
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			for i in range(note.size() - 1, -1, -1):
				if _visibile(note[i]) and e.position.distance_to(note[i].pos) <= RAGGIO:
					note.remove_at(i)
					modificato = true
					break
	elif e is InputEventKey and e.pressed:
		match e.keycode:
			KEY_SPACE: musica.stream_paused = not musica.stream_paused
			KEY_LEFT: musica.seek(max(0.0, tempo - 2.0))
			KEY_RIGHT: musica.seek(tempo + 2.0)
			KEY_Z:
				if note.size() > 0:
					note.pop_back()
					modificato = true
			KEY_V:
				indice_velocita = (indice_velocita + 1) % VELOCITA.size()
				musica.pitch_scale = VELOCITA[indice_velocita]
			KEY_S: _salva()   # salvataggio manuale se vuoi


func _visibile(n: Dictionary) -> bool:
	return tempo >= n.t - APPROCCIO and tempo <= n.t + 0.5


func _draw() -> void:
	for n in note:
		if not _visibile(n):
			continue
		draw_circle(n.pos, RAGGIO, Color(1, 0.4, 0.7, 0.35))
		draw_arc(n.pos, RAGGIO, 0, TAU, 64, Color.WHITE, 3.0)
	var info := "t=%.2f | x%s | note: %d%s" % [tempo, VELOCITA[indice_velocita], note.size(), " *" if modificato else ""]
	draw_string(ThemeDB.fallback_font, Vector2(20, 30), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
