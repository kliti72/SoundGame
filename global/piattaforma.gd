extends Node

var is_mobile: bool = false


func _ready() -> void:
	is_mobile = OS.has_feature("mobile")
