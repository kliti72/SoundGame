extends Node

# Parametri della scena di gioco
var canzone_suonata := ""

# Iterazioni di questa scena
@onready var continue_song: Button = $Control/MarginContainer/VBoxContainer/Continue
@onready var retry_button: Button = $Control/MarginContainer/VBoxContainer/RestartLevelButton
@onready var menu_button: Button = $Control/MarginContainer/VBoxContainer/GoMenuButton
@onready var control_pause : Control = $Control


# Altro
#@onready var music_background : backgroundGlitchMonitor = $SceneGlitchMonitorTheme

# Scene di navigazione
@export_file("*.tscn") var scena_gioco := "res://game/core.tscn"
@export_file("*.tscn") var scena_menu := "res://game/GameSongSelectorPage.tscn"


func _ready() -> void:
	# Musica e Background
	MusicaGlobale.start(3)
	#music_background.segui_musica(MusicaGlobale.player)

	continue_song.pressed.connect(_on_continue_pressed)

	# Retry e menu
	retry_button.pressed.connect(__restart_level)
	
	menu_button.pressed.connect(_on_menu)
		
func _on_menu() -> void:
	get_tree().paused = false   # PRIMA di tutto
	Transizione.vai(scena_menu, "menu")

func _on_continue_pressed() -> void:
	get_tree().paused = false
	control_pause.visible = false

func _core() -> Node:
	return owner if owner else get_parent().get_parent()  # il nodo con core.gd

func __restart_level():
	var core = _core()
	# 1. prima ti prendi i dati, poi il core sparisce
	var canzone: String = core.canzone
	var sfondo: int = SongDB.sfondo_di(canzone)

	# 2. sblocchi la strada
	get_tree().paused = false

	# 3. transizione (Transizione è un autoload, quindi sopravvive)
	Transizione.vai(scena_gioco, "gioco", {
		"canzone": canzone,
		"sfondo_uso": sfondo
	})

	# 4. distruggi il core, pausa compresa
	core.queue_free()
	
