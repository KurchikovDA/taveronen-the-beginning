extends Button

func _ready() -> void:
	pressed.connect(_on_pressed)
	GameManager.play_tavern_theme()

func _on_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/tavern.tscn")
