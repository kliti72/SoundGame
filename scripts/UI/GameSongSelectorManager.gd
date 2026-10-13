extends Node

@onready var canzone_precedente: Button = $Control/VBoxContainer/CanzonePrecedente
@onready var prossima_canzone: Button = $Control/VBoxContainer/ProssimaCanzone
@onready var titolo_canzone: Label = $Control/VBoxContainer/CenterContainer/VBoxContainer/TextureRect/MarginContainer/HBoxContainer/SongTitle
@onready var start_trap_song: Button = $Control/VBoxContainer/CenterContainer/VBoxContainer/StartTrapSong
@onready var image_song : TextureRect = $Control/VBoxContainer/CenterContainer/VBoxContainer/TextureRect
@onready var barra_progresso: ProgressBar = $Control/VBoxContainer/CenterContainer/VBoxContainer/ProgressBar  # adatta il percorso
@onready var rombi_rating : Control = $Control/VBoxContainer/CenterContainer/VBoxContainer/HBoxContainer/MarginContainer/RombiRating

var viaggio := 0.0
var mat_tunnel: ShaderMaterial
var mat_fx: ShaderMaterial


var song_data = FileAccess.get_file_as_string("res://data/song_data.json");

var json_data = JSON.parse_string(song_data);
var canzoni_disponibili = [];
var nomi_file = [];
var page_counter = 0;

#
#@onready var sfondi: Array = [
	#$BackgroundCity, 
	#$SceneGlitchMonitorTheme, 
	#$BackgroundRedWaterScene,
	#$BackgroundForestRain
	#]

var sfondo_attivo := -1
var sfondi_collegati := {}   # per chiamare segui_musica una volta per sfondo


func _ready() -> void:
		
	image_song.texture = load("res://resource/images/Tunnel_%d.png" % page_counter)	# Trova le canzoni Disponibili
	for i in json_data["canzoni"]:
		canzoni_disponibili.append(i["titolo"]);
		nomi_file.append(i["file"])
	
	# Registrazione on click
	start_trap_song.pressed.connect(_on_play_song_button);
	prossima_canzone.pressed.connect(_on_next_song_pressed);
	canzone_precedente.pressed.connect(_on_before_song_pressed);

	aggiorna_pagina()



func aggiorna_pagina() -> void:
	if canzoni_disponibili.is_empty():
		titolo_canzone.text = "Nessuna canzone"
		barra_progresso.visible = false
		return

	image_song.texture = load("res://resource/images/Tunnel_%d.png" % page_counter)
	var titolo: String = canzoni_disponibili[page_counter]
	titolo_canzone.text = titolo

	var s := Player.canzone_per_titolo(titolo)
	var sbloccata := s != null and not s.lock
	if sbloccata:
		start_trap_song.text = "Start Song"
		start_trap_song.disabled = false
	else:
		start_trap_song.text = "Bloccata"
		start_trap_song.disabled = true

	# progresso: record di note prese / note totali della canzone
	var totali := 0
	var record := 0
	if s != null:
		totali = SongDB.note_di(s.file).size()
		record = mini(s.punteggio, totali)
	barra_progresso.visible = false
	barra_progresso.show_percentage = true
	barra_progresso.min_value = 0
	barra_progresso.max_value = maxi(totali, 1)
	barra_progresso.value = record
	# testo_progresso.text = "%d / %d" % [record, totali]
	
	var rombi := 0
	if totali > 0:
		rombi = floori(float(record * rombi_rating.totale) / totali)
	rombi_rating.visible = true
	rombi_rating.riempi(rombi)


	#mostra_sfondo(SongDB.sfondo_di(nomi_file[page_counter]))


#func mostra_sfondo(valore: int) -> void:
	#var idx := valore - 1
	#if idx < 0 or idx >= sfondi.size():
		#idx = 0   # default: il primo
	#if idx == sfondo_attivo:
		#return
	#sfondo_attivo = idx

	#for i in sfondi.size():
		#var nodo: Node = sfondi[i]
		#if i == idx:
			#if nodo.get_parent() == null:
				#add_child(nodo)
				#move_child(nodo, 0)   # dietro all'interfaccia ($Control)
		#elif nodo.get_parent() == self:
			#remove_child(nodo)

	#var scelto: Node = sfondi[idx]
	#if scelto.has_method("segui_musica"):
		#scelto.segui_musica(MusicaGlobale.player)   # a ogni cambio, anche quando rientra
		#
				
func _on_next_song_pressed():
	if page_counter >= canzoni_disponibili.size() -1:
		return;
	
	page_counter += 1;
	image_song.texture = load("res://resource/images/Tunnel_%d.png" % page_counter)
	print("res://resource/images/Tunnel_%d.png" % page_counter)
	titolo_canzone.text = canzoni_disponibili.get(page_counter);
	aggiorna_pagina()
	
func _on_before_song_pressed():
	if page_counter <= 0:
		Transizione.vai("res://InitStartGame.tscn",)
		return;
	
	page_counter -= 1;
	image_song.texture = load("res://resource/images/Tunnel_%d.png" % page_counter)
	titolo_canzone.text = canzoni_disponibili.get(page_counter);
	aggiorna_pagina()
	
	
func _on_play_song_button():
	
	if not Player.verifica_lock(canzoni_disponibili[page_counter]):
		if Player.compra(nomi_file[page_counter]):
			aggiorna_pagina()
		return
		
	titolo_canzone.text = "Cambio Scena"
	var file: String = nomi_file[page_counter]
	Transizione.vai("res://game/core.tscn", "gioco", {
		"canzone": file,
		"sfondo_uso": SongDB.sfondo_di(file),
	})
		
	var vecchia := get_tree().current_scene
	vecchia.queue_free()
