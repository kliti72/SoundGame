extends Node

# Imposta qui il percorso della tua canzone
const PERCORSO_MUSICA := "res://resource/music_game/aurora.mp3"

@export var volume_db := 0.0
@export var bus := "Master"

var player: AudioStreamPlayer
var _tween: Tween


func _ready() -> void:
	# la musica continua anche se il gioco va in pausa
	process_mode = Node.PROCESS_MODE_ALWAYS

	player = AudioStreamPlayer.new()
	player.bus = bus
	player.volume_db = volume_db

	var stream := load(PERCORSO_MUSICA)
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	player.stream = stream

	add_child(player)


func start(fade := 0.0) -> void:
	if player.playing:
		return
	_ferma_tween()
	if fade > 0.0:
		player.volume_db = -60.0
		player.play()
		_tween = create_tween()
		_tween.tween_property(player, "volume_db", volume_db, fade)
	else:
		player.volume_db = volume_db
		player.play()


func stop(fade := 0.0) -> void:
	if not player.playing:
		return
	_ferma_tween()
	if fade > 0.0:
		_tween = create_tween()
		_tween.tween_property(player, "volume_db", -60.0, fade)
		_tween.tween_callback(player.stop)
	else:
		player.stop()


func _ferma_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
