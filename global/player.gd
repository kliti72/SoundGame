extends Node

signal monete_cambiate(nuove: int)

const FILE_PLAYER := "user://player_data.json"
const LIVELLO_MAX := 5                                  # 5 livelli = uno ogni 20%
const RANK := ["-", "D", "C", "B", "A", "S"]            # indice = livello

var nickname: String = "Player"
var monete: int = 0
var canzoni: Array[SongData] = []


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
	for s in canzoni:
		s.price = SongDB.prezzo_di(s.file)
	if cambiato:
		salva()

func canzone(file: String) -> SongData:
	for s in canzoni:
		if s.file == file:
			return s
	return null

func canzone_per_titolo(titolo: String) -> SongData:
	for s in canzoni:
		if s.titolo.to_lower() == titolo.to_lower():
			return s
	return null


# ---------- MONETE ----------

func aggiungi_monete(n: int) -> void:
	if n <= 0:
		return
	monete += n
	monete_cambiate.emit(monete)
	salva()


# true = pagato, false = non hai i soldi
func spendi_monete(n: int) -> bool:
	if n <= 0 or monete < n:
		return false
	monete -= n
	monete_cambiate.emit(monete)
	salva()
	return true


func puo_permettersi(n: int) -> bool:
	return monete >= n


# ----------  RECORD / LEVEL ----------


# lettura, true = sbloccata, false = bloccata (o titolo non trovato)
func verifica_lock(titolo: String) -> bool:
	for s in canzoni:
		if s.titolo.to_lower() == titolo.to_lower():
			return not s.lock
	return false

############# WRITE

# Registra punteggio della canzone
func registra_punteggio(file: String, punti: int) -> void:
	var s := canzone(file)
	if s != null and punti > s.punteggio:
		s.punteggio = punti
		salva()

# Regista sblocco canzone
func sblocca_lock(titolo: String) -> bool:
	for s in canzoni:
		if s.titolo.to_lower() == titolo.to_lower():
			if not s.lock:
				return false # già sbloccata, niente da fare
			s.lock = false
			return true # sbloccata ora
	return false # canzone non trovata

# ---------- SAVE / LOAD ----------

func salva() -> bool:
	var lista := []
	for s in canzoni:
		lista.append(s.to_dict())
	var f := FileAccess.open(FILE_PLAYER, FileAccess.WRITE)
	if f == null:
		push_error("player_data.json: non riesco a scrivere")
		return false
	f.store_string(JSON.stringify({
		"nickname": nickname,
		"monete": monete,
		"canzoni": lista,
	}, "\t"))
	f.close()
	return true


func carica() -> void:
	if not FileAccess.file_exists(FILE_PLAYER):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(FILE_PLAYER)) != OK or not (json.data is Dictionary):
		push_warning("player_data.json rotto, riparto da zero")
		return
	nickname = json.data.get("nickname", "Player")
	monete = int(json.data.get("monete", 0))
	canzoni.clear()
	for d in json.data.get("canzoni", []):
		canzoni.append(SongData.from_dict(d))
