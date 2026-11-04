extends GutTest # "I am a test file" - GUT (Godot Unit Test) can now find and run me
# Checks that the main menu shows the game version in the corner.


# Version in the main menu
## WHAT: opens the real main menu and reads the text of the small version label in the corner.
## WHY: the version is written in the project settings (Project Settings > Application > Config > Version) and the label must show exactly it, so the player and the build always agree. It also protects us from releasing a build with an empty version.
## PASSES when: the project has a version, the label exists and its text is "v" plus that version (for example "v1.0.7"). FAILS when the version is empty, the label is missing or shows another text.
func test_main_menu_shows_project_version() -> void: # Name starts with test_ so GUT runs it
	var version: String = str(ProjectSettings.get_setting("application/config/version", "")) # The version from the project settings. If it is not set, we get an empty text
	var menu: Node = add_child_autoqfree(load("res://scenes/main_menu.tscn").instantiate()) # The real main menu, placed into the test and removed after it
	await wait_process_frames(2) # Let the menu finish its _ready (await = wait here, then go on)
	var version_label: Label = menu.get_node_or_null("VersionLabel") as Label # The small label in the corner. get_node_or_null gives null (nothing) instead of an error if the label is missing

	# Check 1: the project has a version, so the label has something to show
	assert_ne(version, "", "The project settings should have a version (Application > Config > Version)") # assert_ne (ne = not equal): the two values must be different
	# Check 2: the label exists in the main menu
	assert_not_null(version_label, "The main menu should have a label named VersionLabel") # assert_not_null: the value must not be null (null = nothing)
	if version_label == null: # If the label is missing, stop here, the next check would crash
		return # Leave the function

	# Check 3: the label shows "v" plus the version, for example "v1.0.7"
	assert_eq(version_label.text, "v" + version, "The label should show the project version with a v in front") # Actual value first, expected second
