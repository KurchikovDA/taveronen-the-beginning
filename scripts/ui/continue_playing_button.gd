extends Button

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	# Just hide the victory screen and let the player keep enjoying the tavern
	get_parent().get_parent().visible = false
	GameManager.stop_victory_theme()
	GameManager.resume_tavern_theme()
	# Records that the player has actually continued past the victory
	# screen at least once - this is the real-world proof that the
	# tavern was fully furnished (the victory screen only appears after
	# every item is bought) AND that the player chose to keep going.
	# This is what gates the "Legend of Gold" gold-milestone easter egg
	# in GameManager - see mark_victory_continued() there for why.
	GameManager.mark_victory_continued()
