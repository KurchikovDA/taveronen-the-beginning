extends Button

func _ready() -> void:
	# In a browser build there is nothing to quit to - get_tree().quit()
	# would just freeze the page on a blank canvas - so the Quit button
	# is hidden entirely on the web and players simply close the tab.
	# On desktop (editor and Windows build) this check is false, so the
	# button works exactly as before.
	if OS.has_feature("web"):
		visible = false
		return

	pressed.connect(_on_pressed)
	mouse_entered.connect(func(): %HoverSound.play())

func _on_pressed() -> void:
	get_tree().quit()
