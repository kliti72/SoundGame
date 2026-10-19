class_name LabelRitmo
extends Label

@export var scala_max := 1.35          # quanto si ingrandisce sulla botta
@export var soglia_db_min := -40.0     # sotto questo è silenzio
@export var soglia_db_max := -6.0      # sopra questo è botta piena
@export var attacco := 0.6             # quanto scatta veloce (0-1)
@export var rilascio := 0.12           # quanto torna piano (0-1)
@export var tremolio := 0.0            # rotazione in radianti sulla botta (es. 0.05)

var _bus := 0
var _forza := 0.0


func _ready() -> void:
	# il perno deve stare al centro, sennò zooma verso l'angolo
	resized.connect(_aggiorna_perno)
	_aggiorna_perno()

	var player: AudioStreamPlayer = MusicaGlobale.player
	if player:
		_bus = maxi(AudioServer.get_bus_index(player.bus), 0)


func _aggiorna_perno() -> void:
	pivot_offset = size * 0.5


func _process(_d: float) -> void:
	var player: AudioStreamPlayer = MusicaGlobale.player
	var target := 0.0
	if player and player.playing:
		var db := AudioServer.get_bus_peak_volume_left_db(_bus, 0)
		target = clampf(inverse_lerp(soglia_db_min, soglia_db_max, db), 0.0, 1.0)

	_forza = lerpf(_forza, target, attacco if target > _forza else rilascio)

	var s := 1.0 + (scala_max - 1.0) * _forza
	scale = Vector2(s, s)
	rotation = sin(Time.get_ticks_msec() * 0.03) * tremolio * _forza
