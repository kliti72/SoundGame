extends Control
# Riordina le canzoni (sequenza del gioco) e imposta la difficoltà di ognuna.

var _voci: Array = []   # {file, titolo, note, diff}
var _lista := VBoxContainer.new()
var _info := Label.new()
var _modificato := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margine := MarginContainer.new()
	margine.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lato in ["left", "top", "right", "bottom"]:
		margine.add_theme_constant_override("margin_" + lato, 20)
	add_child(margine)

	var root := VBoxContainer.new()
	margine.add_child(root)

	var barra := HBoxContainer.new()
	root.add_child(barra)
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.add_child(_info)
	_bottone(barra, "A-Z", _ordina_az)
	_bottone(barra, "Per difficoltà", _ordina_diff)
	_bottone(barra, "Salva", _salva)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_lista)

	for f in SongDB.file_musicali():
		var voce := SongDB.trova(f)
		_voci.append({
			"file": f,
			"titolo": voce.get("titolo", f.get_basename()),
			"note": SongDB.note_di(f).size(),
			"diff": SongDB.difficolta_di(f),
		})
	_ricostruisci()


func _bottone(parent: Node, testo: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = testo
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _ricostruisci() -> void:
	for c in _lista.get_children():
		_lista.remove_child(c)
		c.queue_free()

	for i in _voci.size():
		var v: Dictionary = _voci[i]
		var riga := HBoxContainer.new()

		var num := Label.new()
		num.text = "%02d" % (i + 1)
		num.custom_minimum_size.x = 30
		riga.add_child(num)

		var nome := Label.new()
		nome.text = "%s  (%d note)" % [v.titolo, v.note]
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		riga.add_child(nome)

		var lbl := Label.new()
		lbl.text = "difficoltà"
		riga.add_child(lbl)

		var diff := SpinBox.new()
		diff.min_value = SongDB.DIFF_MIN
		diff.max_value = SongDB.DIFF_MAX
		diff.step = 1
		diff.rounded = true
		diff.set_value_no_signal(v.diff)
		diff.value_changed.connect(_diff_cambiata.bind(i))
		riga.add_child(diff)

		var su := _bottone(riga, "▲", _sposta.bind(i, -1))
		su.disabled = i == 0
		var giu := _bottone(riga, "▼", _sposta.bind(i, 1))
		giu.disabled = i == _voci.size() - 1

		_lista.add_child(riga)
	_aggiorna_info()


func _aggiorna_info() -> void:
	_info.text = "Ordine canzoni (%d)%s" % [_voci.size(), " *" if _modificato else ""]


func _diff_cambiata(valore: float, i: int) -> void:
	_voci[i]["diff"] = int(valore)
	_modificato = true
	_aggiorna_info()


func _sposta(i: int, d: int) -> void:
	var j := i + d
	if j < 0 or j >= _voci.size():
		return
	var tmp = _voci[i]
	_voci[i] = _voci[j]
	_voci[j] = tmp
	_modificato = true
	_ricostruisci()


func _ordina_az() -> void:
	_voci.sort_custom(func(a, b): return a.titolo.to_lower() < b.titolo.to_lower())
	_modificato = true
	_ricostruisci()


# dalla più facile alla più dura; a parità resta l'ordine che hai già
func _ordina_diff() -> void:
	for i in _voci.size():
		_voci[i]["idx"] = i
	_voci.sort_custom(func(a, b):
		if a.diff != b.diff:
			return a.diff < b.diff
		return a.idx < b.idx)
	_modificato = true
	_ricostruisci()


func _salva() -> void:
	var lista := []
	for v in _voci:
		lista.append({"file": v.file, "difficolta": v.diff})
	if SongDB.salva_ordine(lista):
		_modificato = false
		_aggiorna_info()
		print("Ordine e difficoltà salvati: %d canzoni" % lista.size())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _modificato:
		_salva()
