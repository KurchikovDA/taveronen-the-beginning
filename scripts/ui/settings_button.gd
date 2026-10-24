extends Button

func _ready() -> void:
	pressed.connect(_on_pressed)
	mouse_entered.connect(func(): %HoverSound.play())

func _on_pressed() -> void:
	%SettingsPanel.visible = true
