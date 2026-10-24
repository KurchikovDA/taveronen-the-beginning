extends Panel

# Keeps "Keep Playing" and "Return to Main Menu" at the same font size,
# picking the largest size that fits both - via the same ButtonGroupFitter
# used by the pause menu's buttons. Works on both the Victory screen and
# the Gold Milestone easter-egg screen: the buttons are found by name,
# not by a hardcoded path, since the two screens use differently-named
# card nodes (VictoryCard vs GoldMilestoneCard) but the same button names.

@onready var continue_button: Button = find_child("ContinuePlayingButton", true, false)
@onready var menu_button: Button = find_child("ReturnToMenuButton", true, false)

func _ready() -> void:
	if continue_button == null or menu_button == null:
		return
	continue_button.add_to_group("autofit_exclude")
	menu_button.add_to_group("autofit_exclude")
	_fit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_fit()

func _fit() -> void:
	ButtonGroupFitter.fit([continue_button, menu_button])
