extends Panel

@onready var settings_sub_panel: Panel = $EscapeMenuCard/SettingsPanel
@onready var resume_button: Button = $EscapeMenuCard/ResumeButton
@onready var settings_button: Button = $EscapeMenuCard/EscapeSettingsButton
@onready var main_menu_button: Button = $EscapeMenuCard/MainMenuButton
@onready var quit_button: Button = $EscapeMenuCard/EscapeQuitButton

func _ready() -> void:
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Take these buttons out of the global auto-fit system so
	# ButtonGroupFitter is the only thing setting their font size.
	resume_button.add_to_group("autofit_exclude")
	settings_button.add_to_group("autofit_exclude")
	main_menu_button.add_to_group("autofit_exclude")
	quit_button.add_to_group("autofit_exclude")

	# In a browser build there is nothing to quit to (see quit_button.gd),
	# so the Quit button is hidden on the web. The remaining three buttons
	# are then shifted down by half a row, so the shorter column stays
	# vertically centred on the card instead of leaving a gap at the bottom.
	# On desktop (editor and Windows build) this check is false, so the
	# menu keeps all four buttons in their original positions.
	if OS.has_feature("web"):
		quit_button.visible = false
		var half_step: float = (quit_button.position.y - main_menu_button.position.y) / 2.0
		for button in [resume_button, settings_button, main_menu_button]:
			button.position.y += half_step

	_fit_menu_buttons()

func _notification(what: int) -> void:
	# Guard against this firing before @onready vars are set (it can arrive
	# before _ready() runs, while resume_button etc. are still null).
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_fit_menu_buttons()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	# Don't let the pause menu pop open on top of the victory or gold
	# milestone screens - those are their own full-screen overlays with
	# their own "Return to Main Menu" button, and stacking the pause menu
	# on top of them is a confusing, unintended state rather than a real
	# use case. Closing the pause menu (if it's somehow already open) is
	# always still allowed - this only blocks opening a new one.
	if not visible and _is_victory_screen_showing():
		return

	_toggle_menu()

# Whether either the normal victory screen or the hidden gold-milestone
# easter-egg screen is currently up. Both are unique-named siblings of
# this panel under the same CanvasLayer (see tavern.tscn).
func _is_victory_screen_showing() -> bool:
	return %VictoryPanel.visible or %GoldMilestonePanel.visible

func _toggle_menu() -> void:
	visible = not visible
	settings_sub_panel.visible = false

func _fit_menu_buttons() -> void:
	# A hidden Quit button (web build) is left out, so its text can't
	# shrink the shared font size of the buttons that are actually shown.
	var buttons: Array[Button] = [resume_button, settings_button, main_menu_button]
	if quit_button.visible:
		buttons.append(quit_button)
	ButtonGroupFitter.fit(buttons)

func _on_resume_pressed() -> void:
	visible = false
	settings_sub_panel.visible = false

func _on_settings_pressed() -> void:
	settings_sub_panel.visible = true

func _on_main_menu_pressed() -> void:
	GameManager.stop_tavern_theme()
	_go_to_main_menu() # Open the main menu (the scene change lives in its own function below)

# Opens the main menu scene.
# Kept as a separate function so a test can replace it: a real scene change would destroy the test runner.
func _go_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn") # Swap the whole current scene for the main menu

func _on_quit_pressed() -> void:
	get_tree().quit()
