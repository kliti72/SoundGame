extends Control

signal azione_premuta

@onready var azione_button: Button = $BoxContainer/HBoxContainer/AzioneButton

func _ready():
	azione_button.pressed.connect(_on_azione_pressed)

func _on_azione_pressed():
	azione_premuta.emit()  # prima il segnale, poi ti levi dai piedi
	Transizione.vai("res://game/GameSongSelectorPage.tscn")
	queue_free()           # chiude la scena corrente
