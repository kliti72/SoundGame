extends Control

signal azione_premuta

@onready var azione_button: Button = $Button

# Vorrei Passargli Cap, (monete), Progress Bar, Quante Note prese su note totali
# La scena che Retry deve effettuare 

func _ready():
	azione_button.pressed.connect(_on_azione_pressed)

func _on_azione_pressed():
	azione_premuta.emit()  # prima il segnale, poi ti levi dai piedi
	Transizione.vai("res://game/CompleteSong.tscn", "gioco", {
		"canzone_suonata": "Darkout.mp3",
		"note_prese": 70,
		"monete_guadagnate" : 100
	})

	queue_free()           # chiude la scena corrente
