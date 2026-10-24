extends Button

func _ready() -> void:
	pressed.connect(_on_pressed)
	mouse_entered.connect(func(): %HoverSound.play())

	# Buttons of the "Start a new game?" confirmation window
	# (ConfirmNewGamePanel in main_menu.tscn), which only appears when
	# there is real progress that starting over would wipe out.
	%ConfirmYesButton.pressed.connect(_start_new_game)
	%ConfirmNoButton.pressed.connect(_on_confirm_no_pressed)

func _on_pressed() -> void:
	# With a game already in progress (same check that enables the
	# Continue button), ask first - a single misclick on New Game used to
	# silently erase the whole save. With nothing to lose (first launch),
	# skip the question and start right away, exactly as before.
	if GameManager.has_save():
		%ConfirmNewGamePanel.visible = true
	else:
		_start_new_game()

func _on_confirm_no_pressed() -> void:
	# Keep the current progress and simply close the confirmation window.
	%ConfirmNewGamePanel.visible = false

func _start_new_game() -> void:
	# Wipe any existing progress, then show the intro story before the fresh tavern
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://scenes/intro.tscn")
