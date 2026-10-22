class_name AvvioDTO
extends RefCounted

const FILE_ID := "user://installazione.cfg"

var id_installazione: String
var primo_avvio: bool
var numero_avvii: int
var versione: String
var piattaforma: String      # Windows, Android, Web...
var lingua: String
var risoluzione: String
var timestamp: int           # unix, UTC

const FILE_PLAYER := "user://player_data.json"

var player: Dictionary = {}      # nickname, monete, canzoni[]


static func cattura() -> AvvioDTO:
	var d := AvvioDTO.new()

	var cfg := ConfigFile.new()
	cfg.load(FILE_ID)   # se non esiste resta vuoto, nessun problema

	var id: String = cfg.get_value("install", "id", "")
	d.primo_avvio = id.is_empty()
	if d.primo_avvio:
		id = Crypto.new().generate_random_bytes(16).hex_encode()
	d.id_installazione = id

	d.numero_avvii = int(cfg.get_value("install", "avvii", 0)) + 1
	cfg.set_value("install", "id", id)
	cfg.set_value("install", "avvii", d.numero_avvii)
	cfg.save(FILE_ID)

	d.versione = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	d.piattaforma = OS.get_name()
	d.lingua = OS.get_locale_language()
	var w := DisplayServer.window_get_size()
	d.risoluzione = "%dx%d" % [w.x, w.y]
	d.timestamp = int(Time.get_unix_time_from_system())
	
	d.player = _leggi_player()
		
	return d

func to_dict() -> Dictionary:
	var r := {
		"id_installazione": id_installazione,
		"primo_avvio": primo_avvio,
		"numero_avvii": numero_avvii,
		"versione": versione,
		"piattaforma": piattaforma,
		"lingua": lingua,
		"risoluzione": risoluzione,
		"timestamp": timestamp,
	}
	if not player.is_empty():
		r["player"] = player
	return r

# fire and forget: se il server è giù il gioco non si accorge di niente
func invia(nodo: Node, url: String) -> void:
	var req := HTTPRequest.new()
	req.timeout = 5.0
	nodo.add_child(req)
	req.request_completed.connect(func(_r, _c, _h, _b): req.queue_free())
	var err := req.request(url, ["Content-Type: application/json"],
		HTTPClient.METHOD_POST, JSON.stringify(to_dict()))
	if err != OK:
		req.queue_free()
		
static func _leggi_player() -> Dictionary:
	if not FileAccess.file_exists(FILE_PLAYER):
		return {}
	var dati = JSON.parse_string(FileAccess.get_file_as_string(FILE_PLAYER))
	return dati if dati is Dictionary else {}
