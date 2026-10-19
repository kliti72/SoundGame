extends Node

# Parametri della scena di gioco
var canzone_suonata := ""
var note_prese := 0
var monete_guadagnate := 0

# Dettagli di questa scena
@onready var monete_label : Label = $BoxContainer/HBoxContainer/VBoxContainer2/MarginContainer/MoneteGuadagnate
@onready var progress_bar : ProgressBar = $BoxContainer/HBoxContainer/VBoxContainer/MarginContainer/ProgressBar

# Iterazioni di questa scena
@onready var retry_button: Button = $BoxContainer/HBoxContainer/RetryButton
@onready var menu_button: Button = $BoxContainer/HBoxContainer/GoToMenu

# Altro
@onready var music_background : backgroundGlitchMonitor = $SceneGlitchMonitorTheme

# Scene di navigazione
@export_file("*.tscn") var scena_gioco := "res://game/core.tscn"
@export_file("*.tscn") var scena_menu := "res://game/GameSongSelectorPage.tscn"
func _ready() -> void:
	# Musica e Background
	MusicaGlobale.start(3)
	music_background.segui_musica(MusicaGlobale.player)

	# Registrare monete e record per il Player
	Player.aggiungi_monete(monete_guadagnate)
	Player.registra_punteggio(canzone_suonata, note_prese)

	# UI: parte da zero, ci pensa l'animazione a riempirla
	# (max_value PRIMA di value, sennò il valore si clampa a 100)
	var punteggio: int = Player.canzone(canzone_suonata).punteggio
	progress_bar.max_value = SongDB.note_di(canzone_suonata).size()
	progress_bar.value = 0
	monete_label.text = "0"

	# Retry e menu
	retry_button.pressed.connect(
		func(): Transizione.vai(scena_gioco, "gioco", {"canzone": canzone_suonata}))
	menu_button.pressed.connect(
		func(): Transizione.vai(scena_menu, "menu"))

	_hover_trap(retry_button)
	_hover_trap(menu_button)
	_anima_ingresso(punteggio)


# ---------- ANIMAZIONI TRAP ----------

func _anima_ingresso(punteggio: int) -> void:
	await get_tree().process_frame   # aspetto il layout, sennò size = 0

	var elementi: Array[Control] = [progress_bar, monete_label, retry_button, menu_button]
	for c in elementi:
		c.pivot_offset = c.size / 2.0
		c.modulate.a = 0.0
		c.scale = Vector2(0.3, 0.3)
		c.rotation_degrees = randf_range(-8.0, 8.0)

	# pop a cascata, uno dopo l'altro
	var tw := create_tween().set_parallel(true)
	for i in elementi.size():
		var c := elementi[i]
		var d := i * 0.12
		tw.tween_property(c, "modulate:a", 1.0, 0.2).set_delay(d)
		tw.tween_property(c, "scale", Vector2.ONE, 0.5).set_delay(d) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "rotation_degrees", 0.0, 0.5).set_delay(d) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await tw.finished

	# barra che sale e monete che contano insieme
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(progress_bar, "value", float(punteggio), 1.0) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw2.tween_method(
		func(v: float): monete_label.text = str(int(v)),
		0.0, float(monete_guadagnate), 1.0
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await tw2.finished

	_slam(monete_label)


# colpo secco: si ingrandisce di botto, flash oro, torna normale
func _slam(c: Control) -> void:
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2(1.7, 1.7)
	c.rotation_degrees = randf_range(-6.0, 6.0)
	c.modulate = Color.RED
	var tw := create_tween().set_parallel(true)
	tw.tween_property(c, "scale", Vector2.ONE, 0.5) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "rotation_degrees", 0.0, 0.5) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate", Color.WHITE, 0.6)




# bottoni: ingrandiscono in hover, punch quando premi
func _hover_trap(b: Button) -> void:
	b.mouse_entered.connect(func():
		b.pivot_offset = b.size / 2.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(b, "scale", Vector2(1.12, 1.12), 0.15) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "rotation_degrees", randf_range(-3.0, 3.0), 0.15))
	b.mouse_exited.connect(func():
		var tw := create_tween().set_parallel(true)
		tw.tween_property(b, "scale", Vector2.ONE, 0.15)
		tw.tween_property(b, "rotation_degrees", 0.0, 0.15))
	b.button_down.connect(func():
		create_tween().tween_property(b, "scale", Vector2(0.92, 0.92), 0.06))
