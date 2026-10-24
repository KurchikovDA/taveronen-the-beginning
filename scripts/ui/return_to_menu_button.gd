extends Button

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	# Leaving the victory screen through this button counts as having moved
	# past it, exactly like "Keep Playing" - so the next Continue opens the
	# finished tavern directly instead of showing the victory screen again
	# (see ShopPanel._check_for_victory), and the gold-milestone easter egg
	# can still be reached later. The flag is set directly rather than via
	# GameManager.mark_victory_continued(), so the milestone check is not
	# run on the way out to the Main Menu (where the easter-egg screen does
	# not exist); it runs on the next gold tick back in the tavern instead.
	# On the gold-milestone screen (which reuses this script) the flag is
	# already set, so this does nothing there.
	if not GameManager.victory_continued:
		GameManager.victory_continued = true
		GameManager.save_game()
	GameManager.stop_victory_theme()
	GameManager.stop_tavern_theme()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
