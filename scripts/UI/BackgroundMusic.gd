extends Node

@onready var npc: Personaggio = $CanvasLayer/Control/MarginContainer/Personaggio
@onready var _tep : Personaggio = $CanvasLayer/Control/MarginContainer/Personaggio

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	MusicaGlobale.start(2.5)
	_tep.segui_musica(true, 140, MusicaGlobale.bus)
	await npc.parla(
	"benvenuto_ok", [
		"Yo! Fra!, Che ci fai da queste parti?", 
		"......", 
		"Ah quindi vuoi sentire della TR3P?", 
		"Hai con te delle cuffie?", 
		"... ok",
		"Staremo insieme per poco, la TRAPPOLA chiama.",
		"....",
		"Ecco come mai staremo insieme poco, stanno arrivando fratm ciro, ci vediamo dentro",
		"Non mi avrete mai!"],
	)

	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
