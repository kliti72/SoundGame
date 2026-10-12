extends CanvasLayer

const MENU := "res://game/GameSongSelectorPage.tscn"
const TEMA := "res://theme/Trapur.tres"

var radice := Control.new()


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS   # funziona anche a gioco in pausa

	radice.set_anchors_preset(Control.PRESET_FULL_RECT)
	radice.theme = load(TEMA)
	radice.visible = false

	# fondo scuro, blocca anche i click sulla scena sotto
	var sfondo := ColorRect.new()
	sfondo.color = Color(0, 0, 0, 0.75)
	sfondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	radice.add_child(sfondo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)

	var pannello := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)

	var continua := Button.new()
	continua.text = "Continua"
	continua.pressed.connect(_mostra.bind(false))

	var menu := Button.new()
	menu.text = "Torna al menu"
	menu.pressed.connect(torna_al_menu)

	box.add_child(continua)
	box.add_child(menu)
	pannello.add_child(box)
	centro.add_child(pannello)
	radice.add_child(centro)
	add_child(radice)


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") and not _siamo_nel_menu():
		_mostra(not radice.visible)
		get_viewport().set_input_as_handled()


func _mostra(si: bool) -> void:
	radice.visible = si
	get_tree().paused = si   # musica e gioco in pausa mentre il pannello è aperto


func _siamo_nel_menu() -> bool:
	var s := get_tree().current_scene
	return s != null and s.scene_file_path == MENU


func torna_al_menu() -> void:
	radice.visible = false
	get_tree().paused = false
	await Transizione.vai(MENU)
