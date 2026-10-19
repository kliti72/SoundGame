extends Node

# Parametri impostati da Transizione.vai(..., {"file_canzone": ..., "note_prese": ..., "note_totali": ...})
var file_canzone := ""
var note_prese := 0
var note_totali := 0

@export_file("*.tscn") var scena_gioco := "res://game/core.tscn"
@export_file("*.tscn") var scena_menu := "res://game/GameSongSelectorPage.tscn"

@onready var messaggio: Label = $BoxContainer/HBoxContainer/VBoxContainer/ProgressBarMessage
@onready var retry_button: Button = $BoxContainer/HBoxContainer/RetryButton
@onready var menu_button: Button = $BoxContainer/HBoxContainer/GoToMenu
@onready var music_background : backgroundGlitchMonitor = $SceneGlitchMonitorTheme

func _ready() -> void:
	_sfondo()

	MusicaGlobale.start(3)
	music_background.segui_musica(MusicaGlobale.player)
	
	if note_totali <= 0:
		note_totali = SongDB.note_di(file_canzone).size()
	note_prese = clampi(note_prese, 0, maxi(note_totali, 0))

	# Se il risultato è già registrato nella scena di gioco, rimuovi queste due righe
	Player.registra_punteggio(file_canzone, note_prese)
	Player.registra_risultato(file_canzone, note_prese, note_totali)

	var completata := note_totali > 0 and note_prese >= note_totali
	messaggio.text = "%d / %d" % [note_prese, note_totali]
	if completata:
		messaggio.text += "   LIVELLO COMPLETATO"

	retry_button.text = "RETRY"
	menu_button.text = "MENU"
	retry_button.pressed.connect(func(): Transizione.vai(scena_gioco, "gioco", {"canzone": file_canzone}))
	menu_button.pressed.connect(func(): Transizione.vai(scena_menu, "menu"))


# Sfondo a tutto schermo su un CanvasLayer dietro l'interfaccia
func _sfondo() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	add_child(layer)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
