extends Control

signal azione_premuta

@onready var azione_button: Button = $BoxContainer/HBoxContainer/AzioneButton

func _ready():
	azione_button.pressed.connect(_on_azione_pressed)

func _on_azione_pressed():
	get_tree().change_scene_to_file("res://game/GameSongSelectorPage.tscn")
	azione_premuta.emit()
