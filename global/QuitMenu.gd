extends CanvasLayer

const MENU := "res://game/GameSongSelectorPage.tscn"
const QUIT_MENU := preload("res://game/QuitMenu.tscn") 

var radice: CanvasLayer


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS   # funziona anche a gioco in pausa

	radice = QUIT_MENU.instantiate()
	radice.visible = false
	add_child(radice)

	# i bottoni li cerco per nome unico (% = Unique Name nella scena)
	var go_menu: Button = radice.find_child("GoMenuButton", true, false)
	var restart: Button = radice.find_child("RestartLevelButton", true, false)

	go_menu.pressed.connect(torna_al_menu)

	restart.visible = false   # per ora vuoto e nascosto
	# restart.pressed.connect(riavvia_livello)  # lo colleghi quando lo implementi


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") and not _siamo_nel_menu():
		_mostra(not radice.visible)
		get_viewport().set_input_as_handled()


func _mostra(si: bool) -> void:
	radice.visible = si
	get_tree().paused = si   # musica e gioco in pausa mentre il menu è aperto


func _siamo_nel_menu() -> bool:
	var s := get_tree().current_scene
	return s != null and s.scene_file_path == MENU


func torna_al_menu() -> void:
	radice.visible = false
	get_tree().paused = false
	await Transizione.vai(MENU)
