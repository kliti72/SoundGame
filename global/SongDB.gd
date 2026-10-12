class_name SongDB

const CARTELLA := "res://resource/musica/"
const FILE_DATI := "res://data/song_data.json"
const ESTENSIONI := ["mp3", "ogg", "wav"]
const SFONDO_MIN := 1
const SFONDO_MAX := 10


static func file_musicali() -> Array[String]:
	var r: Array[String] = []
	for f in DirAccess.get_files_at(CARTELLA):
		var nome := f.trim_suffix(".import")
		if nome.get_extension().to_lower() in ESTENSIONI and nome not in r:
			r.append(nome)
	r.sort()
	return r


# dizionario del file, null se il json è rotto
static func leggi() -> Variant:
	var vuoto := {"canzoni": []}
	if not FileAccess.file_exists(FILE_DATI):
		return vuoto
	var testo := FileAccess.get_file_as_string(FILE_DATI).strip_edges()
	if testo.is_empty():
		return vuoto
	var json := JSON.new()
	if json.parse(testo) != OK or not (json.data is Dictionary) or not (json.data.get("canzoni") is Array):
		push_warning("song_data.json rotto")
		return null
	return json.data


static func trova(file: String) -> Dictionary:
	var dati = leggi()
	if dati == null:
		return {}
	for v in dati["canzoni"]:
		if v.get("file", "") == file:
			return v
	return {}


static func note_di(file: String) -> Array:
	var r := []
	for d in trova(file).get("note", []):
		var n := {"t": d["t"], "pos": Vector2(d["x"], d["y"])}
		var lettera: String = d.get("lettera", "")
		if lettera != "":
			n["lettera"] = lettera
		r.append(n)
	return r


static func sfondo_di(file: String) -> int:
	return clampi(int(trova(file).get("sfondo", SFONDO_MIN)), SFONDO_MIN, SFONDO_MAX)


static func salva(file: String, titolo: String, note: Array, sfondo: int = SFONDO_MIN) -> bool:
	var dati = leggi()
	if dati == null:
		push_error("Salvataggio annullato: json rotto, perderesti le altre canzoni")
		return false

	sfondo = clampi(sfondo, SFONDO_MIN, SFONDO_MAX)

	var ordinate := note.duplicate()
	ordinate.sort_custom(func(a, b): return a.t < b.t)
	var punti := []
	for n in ordinate:
		var p := {"t": snappedf(n.t, 0.001), "x": int(n.pos.x), "y": int(n.pos.y)}
		if n.get("lettera", "") != "":
			p["lettera"] = n["lettera"]
		punti.append(p)

	var presente := false
	for voce in dati["canzoni"]:
		if voce.get("file", "") == file:
			voce["titolo"] = titolo
			voce["note"] = punti
			voce["sfondo"] = sfondo
			presente = true
			break
	if not presente:
		dati["canzoni"].append({"file": file, "titolo": titolo, "note": punti, "sfondo": sfondo})

	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open(FILE_DATI, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(dati, "\t"))
	f.close()
	return true
