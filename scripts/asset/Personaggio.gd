class_name Personaggio
extends Control

signal finito

@export var dimensione_personaggio := Vector2(320, 380)
#320x380, 480x570

@export var texture: Texture2D
@export var id_dialogo := ""                      # es. "benvenuto"
@export var righe: Array[String] = []             # testo di default (opzionale)
@export var parla_all_avvio := false
@export var secondi_per_carattere := 0.03
@export var usa_teppistello := true

@onready var _tep: Teppistello


var _sprite := TextureRect.new()
@export var font: Font                      # trascina qui il .ttf
@export var dimensione_font := 24
@export var colore_testo := Color("ecebf5")

var _in_corso := false
var _scrivendo := false
var _tween: Tween

@export_group("Dialogo")
@export var fumetto: Fumetto;

signal _avanza


func _ready() -> void:
	custom_minimum_size = dimensione_personaggio

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)

	if texture == null and usa_teppistello:
		_tep = Teppistello.new()
		_tep.dimensione = dimensione_personaggio
		centro.add_child(_tep)
	else:
		_sprite.texture = texture
		_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		centro.add_child(_sprite)

	if fumetto:
		fumetto.scrittura_iniziata.connect(func(): if _tep: _tep.parlando = true)
		fumetto.scrittura_finita.connect(func(): if _tep: _tep.parlando = false)
		fumetto.finito.connect(func(): finito.emit())

	if parla_all_avvio:
		await get_tree().process_frame
		parla()


# await personaggio.parla("benvenuto", ["Yo!", "Benvenuto fra."])
func parla(id: String = "", testi: Array[String] = [], forza := false, fuggire := true, have_next := false) -> bool:
	if fumetto == null:
		push_warning("Personaggio: nessun Fumetto assegnato")
		return false
	if id == "":
		id = id_dialogo
	if testi.is_empty():
		testi = righe
	return await fumetto.parla(id, testi, forza, fuggire, have_next)

func fuggi(durata := 2.5, direzione := 1.0) -> void:
	if _tep:
		await _tep.fuggi(durata, direzione)

func torna() -> void:
	if _tep: _tep.torna()

func segui_musica(attiva := true, bpm := 0.0, bus := "Master") -> void:
	if _tep: _tep.segui_musica(attiva, bpm, bus)
