extends SceneTree # This script IS the scene tree of the game, so a real scene change cannot destroy it (GUT tests live inside the tree and can)
# Smoke test (a quick check that the game comes alive): presses the buttons that change the scene and checks that the right scene opens.
# It is NOT a GUT test: the file name has no test_ at the start, so GUT does not run it.
# Run it from the command line (see the CI file), the exit code says the result: 0 = all fine, 1 = something failed.

const MENU_SCENE: String = "res://scenes/main_menu.tscn" # path of the main menu scene
const INTRO_SCENE: String = "res://scenes/intro.tscn" # path of the intro scene (the story before the game)
const TAVERN_SCENE: String = "res://scenes/tavern.tscn" # path of the tavern scene (the game itself)

# Path of the fake save file used ONLY by this smoke test.
# user:// = the game's user data folder. The real game uses save.json, so we never touch it.
const TEST_SAVE_PATH: String = "user://smoke_test_save.json" # the path of the test save file, used instead of the real one

var game_manager: Node # the real GameManager of the game (an autoload), found by its name in _initialize
var real_save_path: String # the real save path, remembered to put it back at the end
var failures: int = 0 # how many checks failed, the exit code is made from it


# Start of the script
## WHAT: GameManager is not a global name in this kind of script, so we start the whole run from here.
## WHY: _initialize is the function that Godot calls once when it starts this script. It cannot wait for frames itself, so it only starts _run (a function that can wait).
func _initialize() -> void: # The name _initialize is special, Godot calls it by itself
	_run() # start the run, it waits for frames inside


# The whole smoke run
## WHAT: protects the real save, presses the buttons one by one and prints the result of every check.
## WHY: only a real scene change shows that a button leads to a scene that exists and loads. GUT tests replace this change with a stub, so nobody checked it.
## PASSES when: every check prints "SMOKE ok" and the exit code is 0. FAILS when any scene is not the expected one, then the exit code is 1.
func _run() -> void: # It starts with _ and has no test_ at the start, only _initialize starts it
	game_manager = root.get_node("GameManager") # root = the top of the tree, the autoload GameManager lives right under it
	real_save_path = game_manager.SAVE_PATH # remember the real save path first
	game_manager.SAVE_PATH = TEST_SAVE_PATH # from this line on, every save goes to the test file
	_remove_test_save() # start without any save file, like a player who just installed the game

	# Check 1: New Game without a save goes straight to the intro (no question is asked)
	await _open_scene(MENU_SCENE) # open the main menu and wait until it is ready (await = wait here, then go on)
	_press_button("NewGameButton") # press the button with the signal, the real scene change starts
	await _wait_frames() # the scene change finishes at the end of the frame, so we wait a little
	_check_scene(INTRO_SCENE, "New Game (no save) opens the intro") # the check: the intro must be the open scene now, the text goes to the log

	# Check 2: the Continue button of the intro opens the tavern
	_press_button("ContinueButton") # the intro is open now, press its Continue button (the button is right under the scene root)
	await _wait_frames() # wait until the scene change is done
	_check_scene(TAVERN_SCENE, "Intro Continue opens the tavern") # the check: the tavern must be the open scene now

	# Check 3: the Main Menu button of the pause menu opens the main menu
	_press_button("CanvasLayer/EscapeMenuPanel/EscapeMenuCard/MainMenuButton") # the tavern is open now, press the Main Menu button inside its pause menu (the menu stays hidden, the signal does not need it visible)
	await _wait_frames() # wait until the scene change is done
	_check_scene(MENU_SCENE, "Pause menu Main Menu opens the main menu") # the check: the main menu must be the open scene now

	# Check 4: the Continue button of the main menu opens the tavern when a save exists
	game_manager.save_game() # write a save file (to the test path), now the game has progress to continue
	await _open_scene(MENU_SCENE) # open the main menu again, so its Continue button sees the new save file
	_press_button("ContinueButton") # press the Continue button of the main menu (it has the same name as the intro one, but this is another scene)
	await _wait_frames() # wait until the scene change is done
	_check_scene(TAVERN_SCENE, "Menu Continue (with a save) opens the tavern") # the check: the tavern must be the open scene now

	# Check 5: the Return to Menu button of the victory screen opens the main menu
	_press_button("CanvasLayer/VictoryPanel/VictoryCard/ReturnToMenuButton") # the tavern is open now, press the button of the victory screen (the screen stays hidden, the signal does not need it visible)
	await _wait_frames() # wait until the scene change is done
	_check_scene(MENU_SCENE, "Victory Return to Menu opens the main menu") # the check: the main menu must be the open scene now

	# Check 6: New Game with a save does NOT leave the main menu at once, it asks first
	_press_button("NewGameButton") # the main menu is open and the test save still exists, press New Game
	await _wait_frames() # wait a little, in case a scene change starts by mistake
	_check_scene(MENU_SCENE, "New Game (with a save) stays in the menu and asks first") # the check: the main menu must still be the open scene, the confirmation panel is shown instead

	# Check 7: the Yes button of the confirmation panel opens the intro
	_press_button("ConfirmNewGamePanel/ConfirmCard/ConfirmYesButton") # press Yes inside the confirmation panel, the new game starts
	await _wait_frames() # wait until the scene change is done
	_check_scene(INTRO_SCENE, "Confirm Yes (new game) opens the intro") # the check: the intro must be the open scene now

	game_manager.SAVE_PATH = real_save_path # put the real save path back
	_remove_test_save() # delete the test file if it was created
	print("SMOKE: ", failures, " failure(s)") # one summary line for the log
	quit(1 if failures > 0 else 0) # leave with exit code 1 if something failed, otherwise 0 (CI = continuous integration, the automatic check on GitHub, reads this code)


# Open a scene
## WHAT: changes the current scene to the given one and waits until it is ready.
## WHY: the first scene has to be opened by the script itself, because this script has no main scene.
func _open_scene(scene_path: String) -> void: # scene_path = the path of the scene to open, for example MENU_SCENE
	change_scene_to_file(scene_path) # the real scene change
	await _wait_frames() # wait until the new scene is in the tree and has finished its _ready


# Wait a few frames
## WHAT: waits three frames.
## WHY: change_scene_to_file works at the end of the frame, and a new scene needs a frame or two to finish _ready. Three frames are enough.
func _wait_frames() -> void: # No parameters, it only waits. It has await inside, so the caller must write await before it too
	await process_frame # wait one frame (process_frame = a signal that comes once per frame)
	await process_frame # wait the second frame
	await process_frame # wait the third frame


# Press a button
## WHAT: finds a button in the current scene by its path and presses it with the signal.
## WHY: the smoke test checks where the button leads, not how the mouse hits it (that is the job of the real click tests).
func _press_button(button_path: String) -> void: # button_path = the path of the button inside the current scene, for example "NewGameButton"
	var button: Node = current_scene.get_node_or_null(button_path) # the button inside the current scene, or null if the path is wrong
	if button == null: # no such button: the scene was changed or renamed
		_fail("Button not found: " + button_path) # count it as a failure
		return # nothing to press
	button.pressed.emit() # press the button, like a click of the player


# Check which scene is open
## WHAT: compares the file of the current scene with the expected one and prints the result.
## WHY: this is the check itself, the same as assert_eq in GUT, but written by hand because this script has no GUT.
func _check_scene(expected_path: String, label: String) -> void: # expected_path = the scene that must be open, label = the text for the log
	var actual_path: String = "<no scene>" # the text if there is no current scene at all
	if current_scene != null: # a scene is open
		actual_path = current_scene.scene_file_path # the file the current scene was loaded from
	if actual_path == expected_path: # the right scene is open
		print("SMOKE ok: ", label) # print the good result
	else: # another scene is open
		_fail(label + " (expected " + expected_path + ", got " + actual_path + ")") # count it as a failure and say what happened


# Count a failure
## WHAT: adds one to the failure counter and prints the reason.
func _fail(message: String) -> void: # message = the reason of the failure for the log
	failures += 1 # one more failed check
	print("SMOKE FAIL: ", message) # print the reason


# Delete the test save file
## WHAT: removes the fake save file if it exists.
## WHY: the next run must start clean, and nothing from the test must stay on the disk.
func _remove_test_save() -> void: # It starts with _ and has no test_ at the start, it is a helper of the smoke run
	if FileAccess.file_exists(TEST_SAVE_PATH): # only delete if the file is there
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH)) # remove it from disk (the function needs the full path on the disk, not user://)
