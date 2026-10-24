extends Button

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	# Hide the whole Settings panel by walking up two levels
	# (SettingsBackButton -> SettingsCard -> SettingsPanel), instead of using
	# %SettingsPanel. This button lives inside the reusable settings_panel.tscn,
	# which gets instanced in different scenes (Main Menu, Escape Menu), and the
	# scene-unique-name lookup does not reliably resolve across those different
	# instancing contexts - a relative path always works regardless of where
	# this scene is instanced.
	get_parent().get_parent().visible = false
