extends Label # This script is attached to a Label node, so "self" is a Label

# Shows the game version (like "v1.0.7") in the main menu.
# Why: the number is read from the project settings, so it is written in one place and the player always sees the real version.
func _ready() -> void: # Godot calls this once, when the label appears in the scene
	var version: String = str(ProjectSettings.get_setting("application/config/version", "")) # Read Project Settings > Application > Config > Version. If it is not set, we get an empty text
	if version.is_empty(): # No version in the settings
		text = "" # Show nothing, so the player never sees a broken text like "v"
		return # Stop here
	text = "v" + version # Show the version with a "v" in front, for example "v1.0.7"
