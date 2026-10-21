extends Node

const PATH := "user://dialoghi2.json"
var _stato: Dictionary = {}
var demo : bool = false;

func _ready() -> void:
	_carica()


func gia_detto(id: String) -> bool:
	return _stato.get(id, false)


func segna_detto(id: String) -> void:
	if demo: return 
	_stato[id] = true
	_salva()


func resetta(id: String = "") -> void:
	# senza id cancella tutto (utile per i test)
	if id == "":
		_stato.clear()
	else:
		_stato.erase(id)
	_salva()


func _salva() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_stato))


func _carica() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	var dati = JSON.parse_string(f.get_as_text())
	if dati is Dictionary:
		_stato = dati
