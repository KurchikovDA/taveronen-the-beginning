extends Button

func _ready() -> void:
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	# On a brand new install there's no save yet, so Continue has nothing
	# to continue - keep it disabled until the player starts a game at
	# least once via New Game.
	disabled = not GameManager.has_save()

func _on_mouse_entered() -> void:
	# Skip the hover sound while disabled - a muted, unclickable button
	# shouldn't give interactive audio feedback that suggests otherwise.
	if not disabled:
		%HoverSound.play()

func _on_pressed() -> void:
	# Just go straight into the tavern - GameManager already loads
	# whatever save exists (or starts fresh at 0 gold if there isn't one)
	GameManager.play_tavern_theme()
	_go_to_tavern() # Open the tavern (the scene change lives in its own function below)

# Opens the tavern scene.
# Kept as a separate function so a test can replace it: a real scene change would destroy the test runner.
func _go_to_tavern() -> void:
	get_tree().change_scene_to_file("res://scenes/tavern.tscn") # Swap the whole current scene for the tavern
