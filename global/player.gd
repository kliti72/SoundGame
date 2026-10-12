extends Node

const FILE_PLAYER := "user://player_data.json"

var nickname: String = "Player"
var canzoni: Array[SongData] = []
var completate: Array[String] = []   # file delle canzoni prese al 100% delle note


func _ready() -> void:
	carica()
	sincronizza()


# aggiunge le canzoni nuove trovate in cartella: la prima parte sbloccata, le altre bloccate
func sincronizza() -> void:
	var cambiato := false
	for f in SongDB.file_musicali():
		if canzone(f) != null:
			continue
		var titolo: String = SongDB.trova(f).get("titolo", f.get_basename())
		var i := canzoni.size()
		canzoni.append(SongData.new(f, titolo, 0, i > 0))   # 0 = prezzo, non usato più
		cambiato = true
	if cambiato:
		salva()


func canzone(file: String) -> SongData:
	for s in canzoni:
		if s.file == file:
			return s
	return null


# da chiamare a fine canzone con le note prese.
# Se le prende tutte, la canzone risulta completata e si sblocca la successiva.
func registra_risultato(file: String, note_prese: int, note_totali := -1) -> void:
	var s := canzone(file)
	if s == null:
		return
	if note_totali < 0:
		note_totali = SongDB.note_di(file).size()
	if note_totali <= 0 or note_prese < note_totali:
		return
	if not completate.has(file):
		completate.append(file)
	var i := canzoni.find(s)
	if i >= 0 and i + 1 < canzoni.size():
		canzoni[i + 1].lock = false
	salva()


func completata(file: String) -> bool:
	return completate.has(file)


# salva se batte il record
func registra_punteggio(file: String, punti: int) -> void:
	var s := canzone(file)
	if s != null and punti > s.punteggio:
		s.punteggio = punti
		salva()


func salva() -> bool:
	var lista := []
	for s in canzoni:
		lista.append(s.to_dict())
	var f := FileAccess.open(FILE_PLAYER, FileAccess.WRITE)
	if f == null:
		push_error("player_data.json: non riesco a scrivere")
		return false
	f.store_string(JSON.stringify({"nickname": nickname, "canzoni": lista, "completate": completate}, "\t"))
	f.close()
	return true

func canzone_per_titolo(titolo: String) -> SongData:
	for s in canzoni:
		if s.titolo.to_lower() == titolo.to_lower():
			return s
	return null

func carica() -> void:
	if not FileAccess.file_exists(FILE_PLAYER):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(FILE_PLAYER)) != OK or not (json.data is Dictionary):
		push_warning("player_data.json rotto, riparto da zero")
		return
	nickname = json.data.get("nickname", "Player")
	canzoni.clear()
	for d in json.data.get("canzoni", []):
		canzoni.append(SongData.from_dict(d))
	completate.clear()
	for f in json.data.get("completate", []):
		completate.append(str(f))


# true = sbloccata, false = bloccata (o titolo non trovato)
func verifica_lock(titolo: String) -> bool:
	for s in canzoni:
		if s.titolo.to_lower() == titolo.to_lower():
			return not s.lock
	return false
