extends Button

func _ready() -> void:
	pressed.connect(_on_pressed)
	GameManager.play_tavern_theme()

func _on_pressed() -> void:
	_go_to_tavern() # Open the tavern (the scene change lives in its own function below)

# Opens the tavern scene.
# Kept as a separate function so a test can replace it: a real scene change would destroy the test runner.
func _go_to_tavern() -> void:
	get_tree().change_scene_to_file("res://scenes/tavern.tscn") # Swap the whole current scene for the tavern
