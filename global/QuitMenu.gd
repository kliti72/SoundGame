extends CanvasLayer


var canzone_suonata := ""
var show_restart = true;


# SCene dove rimanda
@export_file("*.tscn") var scena_gioco := "res://game/core.tscn"

# Scene dove non si apre
const MENU := "res://game/GameSongSelectorPage.tscn"
const HOME := "res://game/InitStartGame.tscn"
const COMPLETE_SONG := "res://game/CompleteSong.tscnn"

const CURRENT_SCENE := "res://game/CompleteSong.tscnn"


var radice: CanvasLayer


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS   # funziona anche a gioco in pausa

	#radice = QUIT_MENU.instantiate()
	radice.visible = false
	add_child(radice)

	# i bottoni li cerco per nome unico (% = Unique Name nella scena)
	var go_menu: Button = radice.find_child("GoMenuButton", true, false)
	var restart: Button = radice.find_child("RestartLevelButton", true, false)

	go_menu.pressed.connect(torna_al_menu)

	restart.pressed.connect(
			func(): Transizione.vai(scena_gioco, "gioco", {"canzone": canzone_suonata}))


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") and not _siamo_nel_menu() and not _siamo_nell_home() and not _siamo_nel_complete_song():
		_mostra(not radice.visible)
		get_viewport().set_input_as_handled()


func _mostra(si: bool) -> void:		
	radice.visible = si
	get_tree().paused = si   # musica e gioco in pausa mentre il menu è aperto


func _siamo_nel_menu() -> bool:
	var s := get_tree().current_scene
	return s != null and s.scene_file_path == MENU

func _siamo_nell_home() -> bool:
	var s := get_tree().current_scene
	return s != null and s.scene_file_path == HOME
	
func _siamo_nel_complete_song() -> bool:
	var s := get_tree().current_scene
	return s != null and s.scene_file_path == COMPLETE_SONG

func torna_al_menu() -> void:
	radice.visible = false
	get_tree().paused = false
	await Transizione.vai(MENU)
