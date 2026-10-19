extends Node

signal monete_cambiate(nuove: int)

const FILE_PLAYER := "user://player_data.json"
const LIVELLO_MAX := 5                                  # 5 livelli = uno ogni 20%
const RANK := ["-", "D", "C", "B", "A", "S"]            # indice = livello
const BONUS_COMPLETAMENTO := 50                         # monete alla prima volta che prendi il 100%

var nickname: String = "Player"
var monete: int = 0
var canzoni: Array[SongData] = []
var completate: Array[String] = []    # file delle canzoni prese al 100% delle note
var record_note: Dictionary = {}      # file -> max note prese


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


# ---------- RISULTATI / RECORD / LEVEL ----------

# da chiamare a fine canzone con le note prese.
# Aggiorna il record, e se le prende tutte: completata, sblocca la successiva, bonus monete.
func registra_risultato(file: String, note_prese: int, note_totali := -1) -> void:
	var s := canzone(file)
	if s == null:
		return
	if note_totali < 0:
		note_totali = SongDB.note_di(file).size()

	var cambiato := false

	if note_prese > record_note.get(file, 0):
		record_note[file] = note_prese
		cambiato = true

	if note_totali > 0 and note_prese >= note_totali and not completate.has(file):
		completate.append(file)
		var i := canzoni.find(s)
		if i >= 0 and i + 1 < canzoni.size():
			canzoni[i + 1].lock = false
		cambiato = true
		aggiungi_monete(BONUS_COMPLETAMENTO)   # salva da solo
		return

	var ordine := SongDB.file_musicali()
	canzoni.sort_custom(func(a, b):
		var ia := ordine.find(a.file)
		var ib := ordine.find(b.file)
		return (ia if ia >= 0 else 9999) < (ib if ib >= 0 else 9999))
		
	if cambiato:
		salva()


func completata(file: String) -> bool:
	return completate.has(file)


# record di note prese per quella canzone
func record(file: String) -> int:
	return int(record_note.get(file, 0))


# percentuale del record sulle note totali: 0.0 - 1.0
func percentuale(file: String) -> float:
	var totali := SongDB.note_di(file).size()
	if totali <= 0:
		return 0.0
	return clampf(float(record(file)) / float(totali), 0.0, 1.0)


# LEVEL 0-5: ogni 20% un livello (80% = 4, 100% = 5)
func livello(file: String) -> int:
	var totali := SongDB.note_di(file).size()
	if totali <= 0:
		return 0
	return clampi(floori(float(record(file) * LIVELLO_MAX) / float(totali)), 0, LIVELLO_MAX)


# lettera del rank in base al level (-, D, C, B, A, S)
func rank(file: String) -> String:
	return RANK[livello(file)]


# stesse cose ma partendo dal titolo (comodo nel menu)
func livello_per_titolo(titolo: String) -> int:
	var s := canzone_per_titolo(titolo)
	return livello(s.file) if s != null else 0


# salva se batte il record
func registra_punteggio(file: String, punti: int) -> void:
	var s := canzone(file)
	if s != null and punti > s.punteggio:
		s.punteggio = punti
		salva()


# true = sbloccata, false = bloccata (o titolo non trovato)
func verifica_lock(titolo: String) -> bool:
	for s in canzoni:
		if s.titolo.to_lower() == titolo.to_lower():
			return not s.lock
	return false


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
		"completate": completate,
		"record_note": record_note,
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
	completate.clear()
	for f in json.data.get("completate", []):
		completate.append(str(f))
	record_note.clear()
	var rn = json.data.get("record_note", {})
	if rn is Dictionary:
		for k in rn:
			record_note[str(k)] = int(rn[k])   # il JSON ridà float, qui li sistemo
