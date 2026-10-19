extends Control

@onready var label: Label = $MarginContainer/VBoxContainer/HBoxContainer/Punteggio
@onready var combo_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/Combo

const COLORI_LIVELLO := [
	Color.WHITE,                  # 0-9
	Color.CYAN,                   # 10-19
	Color.SPRING_GREEN,           # 20-29
	Color.YELLOW,                 # 30-39
	Color.ORANGE,                 # 40-49
	Color.RED,                    # 50+ (poi arcobaleno)
]

var combo_tween: Tween
var punteggio_tween: Tween
var colore_combo := Color.WHITE
var combo_attuale := 0


func colore_per_combo(combo: int) -> Color:
	if combo < 10:
		return Color.WHITE
	if combo > 50:
		# oltre 50 il colore gira a ogni colpo
		return Color.from_hsv(fmod(combo * 0.04, 1.0), 0.85, 1.0)
	var idx := mini(combo / 10, COLORI_LIVELLO.size() - 1)
	return COLORI_LIVELLO[idx]


func aggiorna_punteggio(valore: int, aggiunto: int = 0) -> void:
	label.text = str(valore)
	label.pivot_offset = label.size / 2

	if punteggio_tween:
		punteggio_tween.kill()
	punteggio_tween = create_tween()
	label.scale = Vector2(1.5, 1.5)
	punteggio_tween.tween_property(label, "scale", Vector2.ONE, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if aggiunto > 0:
		_mostra_popup_punti(aggiunto)


func aggiorna_combo(combo: int) -> void:
	combo_attuale = combo
	combo_label.text = "x%d" % combo
	combo_label.pivot_offset = combo_label.size / 2
	colore_combo = colore_per_combo(combo)

	if combo_tween:
		combo_tween.kill()
	combo_tween = create_tween().set_parallel(true)

	if combo == 0:
		# combo spezzata: torna tutto spento
		combo_label.scale = Vector2.ONE
		combo_label.rotation = 0.0
		combo_label.modulate = Color.WHITE
		return

	if combo % 5 == 0:
		# milestone: botta grossa, flash oro, wobble, poi si assesta sul colore del livello
		combo_label.scale = Vector2(2.0, 2.0)
		combo_label.rotation = deg_to_rad(-12)
		combo_label.modulate = Color.GOLD
		combo_tween.tween_property(combo_label, "scale", Vector2.ONE, 0.4)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		combo_tween.tween_property(combo_label, "rotation", 0.0, 0.4)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		combo_tween.tween_property(combo_label, "modulate", colore_combo, 0.5)
	else:
		# colpo normale: pop leggero, il colore del livello resta
		combo_label.scale = Vector2(1.25, 1.25)
		combo_label.modulate = colore_combo
		combo_tween.tween_property(combo_label, "scale", Vector2.ONE, 0.15)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _mostra_popup_punti(punti: int) -> void:
	var popup := Label.new()
	popup.text = "+%d" % punti
	popup.modulate = colore_combo
	popup.add_theme_font_size_override("font_size", 28 + mini(combo_attuale, 30))
	popup.add_theme_color_override("font_outline_color", Color.BLACK)
	popup.add_theme_constant_override("outline_size", 6)
	popup.z_index = 10
	add_child(popup)

	# lo piazzo a destra del punteggio, con un po' di random per non sovrapporli
	var start := label.global_position + Vector2(label.size.x + 16 + randf_range(0, 20), randf_range(-6, 6))
	popup.global_position = start
	popup.pivot_offset = popup.size / 2
	popup.scale = Vector2(0.4, 0.4)

	var t := create_tween().set_parallel(true)
	t.tween_property(popup, "scale", Vector2.ONE, 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(popup, "global_position:y", start.y - 70, 0.7)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(popup, "modulate:a", 0.0, 0.4).set_delay(0.35)
	t.chain().tween_callback(popup.queue_free)
