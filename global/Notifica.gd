extends CanvasLayer
# Notifica globale stile achievement. Uso: Notifica.mostra("Titolo", "testo", 3.0)

const FONT_PATH := "res://fonts/Traptur.otf"   # cambia col tuo font (se non esiste usa quello di default)
const LARGHEZZA_TESTO := 520.0
const MARGINE := 24.0
const DURATA_DEFAULT := 3.0

var _box := PanelContainer.new()
var _titolo := Label.new()
var _testo := RichTextLabel.new()
var _suono := AudioStreamPlayer.new()
var _coda: Array[Dictionary] = []
var _occupata := false
var _corrente := ""

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS   # funziona anche col gioco in pausa

	# stile trap: nero secco, bordo bianco, spigoli vivi
	var stile := StyleBoxFlat.new()
	stile.bg_color = Color(0.03, 0.03, 0.03, 0.97)
	stile.border_color = Color.WHITE
	stile.set_border_width_all(3)
	stile.set_content_margin_all(16)
	_box.add_theme_stylebox_override("panel", stile)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE   # non blocca i click sotto
	_box.z_index = 4096
	_box.hide()
	add_child(_box)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_box.add_child(v)

	_titolo.add_theme_font_size_override("font_size", 45)
	_titolo.add_theme_color_override("font_color", Color.WHITE)
	v.add_child(_titolo)

	var linea := ColorRect.new()
	linea.color = Color.WHITE
	linea.custom_minimum_size.y = 2
	v.add_child(linea)

	_testo.bbcode_enabled = true
	_testo.fit_content = true
	_testo.scroll_active = false
	_testo.add_theme_font_size_override("normal_font_size", 25)
	_testo.add_theme_color_override("default_color", Color(0.75, 0.75, 0.75))
	_testo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_testo.custom_minimum_size.x = LARGHEZZA_TESTO
	v.add_child(_testo)
	v.add_child(_testo)

	if ResourceLoader.exists(FONT_PATH):
		var font: Font = load(FONT_PATH)
		_titolo.add_theme_font_override("font", font)
		_testo.add_theme_font_override("normal_font", font)

	_suono.stream = _crea_suono()
	_suono.volume_db = -4.0
	add_child(_suono)


# ---------- API ----------

func mostra(titolo: String, testo := "", durata := DURATA_DEFAULT) -> void:
	var chiave := titolo + "|" + testo
	# stessa notifica già a schermo o in coda? ignora
	if chiave == _corrente:
		return
	for n in _coda:
		if n.chiave == chiave:
			return
	_coda.append({"titolo": titolo, "testo": testo, "durata": durata, "chiave": chiave})
	if not _occupata:
		_prossima()


# ---------- ANIMAZIONE ----------

func _prossima() -> void:
	
	if _coda.is_empty():
		_occupata = false
		return
	_occupata = true

	var n: Dictionary = _coda.pop_front()
	_corrente = n.chiave
	_titolo.text = n.titolo.to_upper()
	_testo.text = n.testo
	_testo.visible = n.testo != ""

	# lo mostro fuori schermo un frame, così prende la sua dimensione vera
	_box.position = Vector2(0, -2000)
	_box.show()
	_box.reset_size()
	await get_tree().process_frame

	var w := get_viewport().get_visible_rect().size.x
	var fuori := -_box.size.y - 20.0
	_box.position = Vector2((w - _box.size.x) / 2.0, fuori)

	_suono.play()
	var tw := create_tween()
	tw.tween_property(_box, "position:y", MARGINE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(n.durata)
	tw.tween_property(_box, "position:y", fuori, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw.finished

	_box.hide()
	_corrente = ""
	_prossima()   # se ce n'è un'altra in coda parte subito


# ---------- SUONO HARDCODATO ----------
# colpo di 808: sinusoide che scende da ~200 a 50 Hz + click acuto iniziale

func _crea_suono() -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * 0.45)
	var dati := PackedByteArray()
	dati.resize(n * 2)
	var fase := 0.0
	for i in n:
		var t := float(i) / rate
		var freq := 50.0 + 150.0 * exp(-t * 14.0)
		fase += TAU * freq / rate
		var s := sin(fase) * exp(-t * 6.0) * 0.8
		s += sin(TAU * 1800.0 * t) * exp(-t * 60.0) * 0.3
		dati.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = dati
	return w
