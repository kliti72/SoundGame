extends CanvasLayer
# Pannello debug per modificare i dati di Player. F1 o bottone DBG per aprire/chiudere.

var _panel: PanelContainer
var _nick: LineEdit
var _monete: SpinBox
var _lista: VBoxContainer
var _righe: Array = []   # {file, tot, rec, punti, lock, compl}


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_costruisci()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_F1:
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_carica_ui()


# ---------- UI ----------

func _costruisci() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 30
	_panel.offset_top = 50
	_panel.offset_right = -30
	_panel.offset_bottom = -30
	_panel.hide()
	add_child(_panel)

	var dbg := Button.new()
	dbg.text = "DBG"
	dbg.modulate.a = 0.5
	dbg.pressed.connect(_toggle)
	add_child(dbg)
	dbg.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)

	var root := VBoxContainer.new()
	_panel.add_child(root)

	_nick = LineEdit.new()
	_nick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_riga("Nickname", _nick))

	_monete = SpinBox.new()
	_monete.max_value = 999999999
	root.add_child(_riga("Monete", _monete))

	var rapidi := HBoxContainer.new()
	root.add_child(rapidi)
	_bottone(rapidi, "+100", func(): _monete.value += 100)
	_bottone(rapidi, "+1000", func(): _monete.value += 1000)
	_bottone(rapidi, "Azzera", func(): _monete.value = 0)

	root.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_lista)

	var azioni := HBoxContainer.new()
	root.add_child(azioni)
	_bottone(azioni, "Applica e salva", _applica)
	_bottone(azioni, "Sblocca tutte", _tutte_lock.bind(false))
	_bottone(azioni, "Blocca tutte", _tutte_lock.bind(true))
	_bottone(azioni, "Completa tutte", _completa_tutte)
	_bottone(azioni, "Reset", _reset)
	_bottone(azioni, "Chiudi", _toggle)


func _riga(testo: String, ctrl: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = testo
	l.custom_minimum_size.x = 80
	h.add_child(l)
	h.add_child(ctrl)
	return h


func _bottone(parent: Node, testo: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = testo
	b.pressed.connect(cb)
	parent.add_child(b)


func _carica_ui() -> void:
	_nick.text = Player.nickname
	_monete.value = Player.monete
	for c in _lista.get_children():
		c.queue_free()
	_righe.clear()

	for s in Player.canzoni:
		var tot := SongDB.note_di(s.file).size()

		var nome := Label.new()
		nome.text = s.titolo
		nome.custom_minimum_size.x = 140

		var rec := SpinBox.new()
		rec.max_value = tot
		rec.value = Player.record(s.file)

		var punti := SpinBox.new()
		punti.max_value = 999999999
		punti.value = s.punteggio

		var lock := CheckBox.new()
		lock.text = "lock"
		lock.button_pressed = s.lock

		var compl := CheckBox.new()
		compl.text = "100%"
		compl.button_pressed = Player.completata(s.file)

		var info := Label.new()
		info.text = "lv %d (%s) / %d note" % [Player.livello(s.file), Player.rank(s.file), tot]

		var r := HBoxContainer.new()
		var l1 := Label.new()
		l1.text = "note"
		var l2 := Label.new()
		l2.text = "punti"
		for n in [nome, l1, rec, l2, punti, lock, compl, info]:
			r.add_child(n)
		_lista.add_child(r)

		_righe.append({"file": s.file, "tot": tot, "rec": rec, "punti": punti, "lock": lock, "compl": compl})


# ---------- AZIONI ----------

func _applica() -> void:
	Player.nickname = _nick.text
	Player.monete = int(_monete.value)
	Player.monete_cambiate.emit(Player.monete)
	for r in _righe:
		var s := Player.canzone(r.file)
		if s == null:
			continue
		s.lock = r.lock.button_pressed
		s.punteggio = int(r.punti.value)

		var v := int(r.rec.value)
		if v > 0:
			Player.record_note[r.file] = v
		else:
			Player.record_note.erase(r.file)

		var ha := Player.completate.has(r.file)
		if r.compl.button_pressed and not ha:
			Player.completate.append(r.file)
		elif not r.compl.button_pressed and ha:
			Player.completate.erase(r.file)
	Player.salva()
	_carica_ui()   # ricarica così vedi il level ricalcolato


func _tutte_lock(blocca: bool) -> void:
	for i in _righe.size():
		_righe[i].lock.button_pressed = blocca and i > 0   # la prima resta sempre libera


func _completa_tutte() -> void:
	for r in _righe:
		r.rec.value = r.tot
		r.compl.button_pressed = true


func _reset() -> void:
	Player.nickname = "Player"
	Player.monete = 0
	Player.record_note.clear()
	Player.completate.clear()
	for i in Player.canzoni.size():
		Player.canzoni[i].lock = i > 0
		Player.canzoni[i].punteggio = 0
	Player.monete_cambiate.emit(0)
	Player.salva()
	_carica_ui()
