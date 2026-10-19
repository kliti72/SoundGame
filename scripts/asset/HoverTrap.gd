class_name HoverTrap
extends Node
# Mettilo come figlio di un Button (o qualsiasi Control) e basta.

@export var hover_scale := Vector2(1.12, 1.12)
@export var hover_rotation := 3.0            # gradi max, random sx/dx
@export var press_scale := Vector2(0.92, 0.92)
@export var durata := 0.15
@export var colore_hover := Color.WHITE      # metti tipo Color.GOLD per il flash colorato

var _target: Control
var _tw: Tween
var _dentro := false


func _ready() -> void:
	_target = get_parent() as Control
	if _target == null:
		push_warning("HoverTrap deve stare sotto un Control")
		return

	_target.resized.connect(_aggiorna_pivot)
	_aggiorna_pivot()

	_target.mouse_entered.connect(_entra)
	_target.mouse_exited.connect(_esci)
	_target.focus_entered.connect(_entra)    # vale anche per tastiera/controller
	_target.focus_exited.connect(_esci)

	if _target is BaseButton:
		_target.button_down.connect(func(): _anima(press_scale, 0.0, colore_hover))
		_target.button_up.connect(func():
			if _dentro: _entra()
			else: _esci())


func _aggiorna_pivot() -> void:
	_target.pivot_offset = _target.size / 2.0


func _entra() -> void:
	_dentro = true
	_anima(hover_scale, randf_range(-hover_rotation, hover_rotation), colore_hover)


func _esci() -> void:
	_dentro = false
	_anima(Vector2.ONE, 0.0, Color.WHITE)


func _anima(sc: Vector2, rot: float, col: Color) -> void:
	if _tw:
		_tw.kill()   # evita tween che si litigano se spammi il mouse
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(_target, "scale", sc, durata) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(_target, "rotation_degrees", rot, durata)
	_tw.tween_property(_target, "modulate", col, durata)


# scorciatoia da codice: HoverTrap.su(bottone)
static func su(c: Control) -> HoverTrap:
	var h := HoverTrap.new()
	c.add_child(h)
	return h
