@tool
class_name ArmadioVinili
extends Control
## ============================================================
## LOGICA DELL'ARMADIO: dati + layout, zero estetica.
## Non sa di colori o forme: delega tutto a `stile` (ArmadioStile).
##
## API pubblica:
##   aggiungi_vinile(titolo, artista, colore, copertina)
##   svuota()
##
## Formato di un vinile (Dictionary):
##   { titolo: String, artista: String, colore: Color,
##     copertina: Texture2D o null }
##
## Layout: l'area dell'armadio è il Control meno stile.margine.
## È divisa in `righe` x `colonne` celle. Ogni vinile sta nella sua
## cella, poggiato sul ripiano. Oltre righe*colonne non si disegna.
## ============================================================

@export var stile: ArmadioStile:
	set(v):
		if stile != null and stile.changed.is_connected(queue_redraw):
			stile.changed.disconnect(queue_redraw)
		stile = v
		if stile != null:
			stile.changed.connect(queue_redraw)
		queue_redraw()

@export var righe: int = 3:
	set(v):
		righe = maxi(1, v)
		queue_redraw()

@export var colonne: int = 4:
	set(v):
		colonne = maxi(1, v)
		queue_redraw()

var vinili: Array[Dictionary] = []


func _ready() -> void:
	resized.connect(queue_redraw)
	if stile == null:
		stile = ArmadioStile.new()
	if vinili.is_empty():
		_esempi()


func _esempi() -> void:
	aggiungi_vinile("BLOOD MONEY", "LIL SPIKE", Color("c4001a"))
	aggiungi_vinile("NIGHT TRAP", "DJ OPS", Color("7a00ff"))
	aggiungi_vinile("ZERO CAP", "FRATE X", Color("00c8a0"))


func aggiungi_vinile(titolo: String, artista: String = "", colore: Color = Color("c4001a"), copertina: Texture2D = null) -> void:
	vinili.append({
		"titolo": titolo,
		"artista": artista,
		"colore": colore,
		"copertina": copertina,
	})
	queue_redraw()


func svuota() -> void:
	vinili.clear()
	queue_redraw()


func _area_armadio() -> Rect2:
	var m := stile.margine
	return Rect2(m, m, size.x - m * 2.0, size.y - m * 2.0)


func _draw() -> void:
	if stile == null:
		return

	stile.disegna_muro(self, size)

	var area := _area_armadio()
	stile.disegna_armadio(self, area, righe)

	var cell_w := area.size.x / colonne
	var h_riga := area.size.y / righe
	var lato := minf(cell_w, h_riga) * stile.scala_vinile

	for i in vinili.size():
		var riga: int = floori(float(i) / colonne)
		if riga >= righe:
			break  # armadio pieno
		var col: int = i % colonne

		var base_y := area.position.y + (riga + 1) * h_riga - stile.spessore_ripiano
		var x := area.position.x + col * cell_w + (cell_w - lato) * 0.5
		var y := base_y - lato

		stile.disegna_vinile(self, Rect2(x, y, lato, lato), vinili[i])
