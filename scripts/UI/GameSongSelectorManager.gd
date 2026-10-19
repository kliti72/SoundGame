extends Node
## Selezione canzone: pagine con effetto "fuoco", acquisto/sblocco, avvio del gioco.

# Header Info Player
@onready var player_cap = $Control/MarginContainer/VBoxContainer/Monete

# Visualizzazioni della canzone
@onready var titolo_canzone: Label = $Control/VBoxContainer/CenterContainer/VBoxContainer/HBoxContainer2/MarginContainer/SongTitle

# Pulsanti Scena
@onready var start_trap_song: Button = $Control/VBoxContainer/CenterContainer/VBoxContainer/MarginContainer/StartTrapSong

# Animazioni
@onready var vinile: Vinile = $Control/VBoxContainer/CenterContainer/VBoxContainer/ImageReact/TextureRect

# Action Visualizzioni
@onready var canzone_precedente: Button = $Control/VBoxContainer/CanzonePrecedente
@onready var prossima_canzone: Button = $Control/VBoxContainer/ProssimaCanzone
# @onready var barra_progresso: ProgressBar = $Control/VBoxContainer/CenterContainer/VBoxContainer/ProgressBar

# Visualizzazioni da cambiare al cambio di canzoni
@onready var difficolta = $Control/VBoxContainer/CenterContainer/VBoxContainer/HBoxContainer2/Teschi
@onready var rombi_rating: Control = $Control/VBoxContainer/CenterContainer/VBoxContainer/HBoxContainer/MarginContainer/RombiRating

# NPC
@onready var _npc: Personaggio = $Teppistello/Control/MarginContainer/Personaggio

const DURATA := 0.35


var canzoni_disponibili: Array[String] = []
var nomi_file: Array[String] = []
var page_counter := 0

var _animando := false


func _ready() -> void:
	_carica_canzoni()
	# Load Header Game Menu
	player_cap.text = "%s" % Player.monete
	
	# Registra Action Pagina
	start_trap_song.pressed.connect(_on_play_song_button)
	prossima_canzone.pressed.connect(_on_next_song_pressed)
	canzone_precedente.pressed.connect(_on_before_song_pressed)
	

	aggiorna_pagina()
	await _intro_npc()


func _carica_canzoni() -> void:
	var dati = JSON.parse_string(FileAccess.get_file_as_string("res://data/song_data.json"))
	for c in dati["canzoni"]:
		canzoni_disponibili.append(c["titolo"])
		nomi_file.append(c["file"])


func _intro_npc() -> void:
	await _npc.parla("benvenuto_song", [
		"Ecco qui bro.",
		"Qua puoi ascoltare le mie basi.",
		"Ci ho messo tutto me stesso fratello",
		"Non sono un beatmatker, passo le giornate a sparare ai miei ops.",
		"Ti faccio vedere un altra canzone",
	], false, false, true)

	_on_next_song_pressed()

	await _npc.parla("benvenuto_song_buy", [
		"Come vedi, questa me la devi pagare fratello!",
		".. IN CAP.",
		"E non provare a far mancare nemmeno un CAP FRATELLo",
		"...",
		"Che potrei lasciarti un REGALO.",
		"...",
		"Ora fratello, Play Musica ti fa sentire la canzone che vuoi",
		"Ora piano piano ti faccio vedere come si gioca",
		"...",
		"Puoi ascoltare per ora solo mio primo beat",
		"....",
	], false, false, true)

	_on_before_song_pressed()

	await _npc.parla("benvenuto_song_buy2", [
		"Ti lascio qui fratello, premi start e divertiti",
	], false, false, false)


func aggiorna_pagina() -> void:
	if canzoni_disponibili.is_empty():
		titolo_canzone.text = "Nessuna canzone"
		return

	var titolo := canzoni_disponibili[page_counter]
	var s := Player.canzone_per_titolo(titolo)

	vinile.texture = load("res://resource/images/Tunnel_%d.png" % page_counter)
	titolo_canzone.text = titolo

	var sbloccata := s != null and not s.lock
	start_trap_song.text = "Start Song" if sbloccata else "Bloccata %s" % s.price

	# Rombi: record di note prese / note totali, riportato sul numero di rombi
	var rombi := 0
	if s != null:
		var totali := SongDB.note_di(s.file).size()
		if totali > 0:
			rombi = floori(float(mini(s.punteggio, totali) * rombi_rating.totale) / totali)
	rombi_rating.visible = true
	rombi_rating.riempi(rombi)
	
	difficolta.livello = "%s" % SongDB.difficolta_di(s.file)


func _on_next_song_pressed() -> void:
	if page_counter < canzoni_disponibili.size() - 1:
		await _cambia(page_counter + 1)


func _on_before_song_pressed() -> void:
	if page_counter <= 0:
		Transizione.vai("res://InitStartGame.tscn")
		return
	await _cambia(page_counter - 1)


var _cooldown := false

func _on_play_song_button() -> void:
	# Canzone bloccata: il tasto serve ad acquistarla
	if not Player.verifica_lock(canzoni_disponibili[page_counter]):
		if _cooldown:
			return
		_cooldown = true

		var titolo := canzoni_disponibili[page_counter]
		var s := Player.canzone_per_titolo(titolo)

		if Player.puo_permettersi(SongDB.prezzo_di(nomi_file[page_counter])):
			if Player.sblocca_lock(titolo):
				Player.spendi_monete(s.price)
				Notifica.mostra("Canzone Sbloccata", "La canzone %s ora è disponibile nella tua libreria." % nomi_file[page_counter])
			else:
				Notifica.mostra("Already Unlocked", "The song is already unlocked")
		else:
			Notifica.mostra("NO CAP", "Non hai abbastanza CAP, ne hai solo [wave][color=gold]%s[/color][/wave]" % Player.monete)

		aggiorna_pagina()
		await get_tree().create_timer(0.6).timeout
		_cooldown = false
		return

	titolo_canzone.text = "Cambio Scena"
	var file := nomi_file[page_counter]
	Transizione.vai("res://game/core.tscn", "gioco", {
		"canzone": file,
		"sfondo_uso": SongDB.sfondo_di(file),
	})
	get_tree().current_scene.queue_free()
	
	
# Vinile Animation
func _set_progress(v: float) -> void:
	vinile.set_fuoco(v)

func _cambia(nuova: int) -> void:
	if _animando:
		return
	_animando = true

	# 1) brucia la vecchia
	var t := create_tween().set_parallel()
	t.tween_method(_set_progress, 0.0, 1.0, DURATA).set_ease(Tween.EASE_IN)
	t.tween_property(titolo_canzone, "modulate:a", 0.0, DURATA)
	await t.finished

	# 2) swap
	page_counter = nuova
	aggiorna_pagina()

	# 3) rinasce la nuova
	t = create_tween().set_parallel()
	t.tween_method(_set_progress, 1.0, 0.0, DURATA).set_ease(Tween.EASE_OUT)
	t.tween_property(titolo_canzone, "modulate:a", 1.0, DURATA)
	await t.finished
	_animando = false
