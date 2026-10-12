class_name SongData
extends RefCounted

var file: String
var titolo: String
var punteggio: int = 0
var lock: bool = true
var price: int = 0


func _init(f := "", t := "", p := 0, l := true) -> void:
	file = f
	titolo = t
	price = p
	lock = l


func to_dict() -> Dictionary:
	return {"file": file, "titolo": titolo, "punteggio": punteggio, "lock": lock, "price": price}


static func from_dict(d: Dictionary) -> SongData:
	var s := SongData.new(d.get("file", ""), d.get("titolo", ""), int(d.get("price", 0)), bool(d.get("lock", true)))
	s.punteggio = int(d.get("punteggio", 0))
	return s
