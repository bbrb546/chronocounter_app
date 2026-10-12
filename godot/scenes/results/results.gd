extends "res://ui/plain_screen.gd"


func _on_back_pressed() -> void:
	Router.goto("main_menu")
