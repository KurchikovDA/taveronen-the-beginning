extends GutTest # "I am a test file" - GUT (Godot Unit Test) can now find and run me
# Checks the "Legend of Gold" easter egg: the signal that fires when gold reaches 10000 or more.

# Path of the fake save file used ONLY by these tests.
# user:// = the game's user data folder. The real game uses save.json, so we never touch it.
const TEST_SAVE_PATH: String = "user://test_save.json"

# The cases of the parameterized test below. Every inner list is one case:
# [name, victory_continued, seen_before, expected_signals, expected_seen_after]
const MILESTONE_CASES: Array = [
	["victory passed, first time", true, false, 1, true], # case 1: the egg should fire
	["victory not passed yet", false, false, 0, false], # case 2: the egg should stay silent
	["egg was already seen", true, true, 0, true], # case 3: the egg should not fire a second time
]

var game_manager: Node # the GameManager under test


# Setup before every test and every case
## WHAT: makes a fresh GameManager and points it to the test save file (also runs before every case of a parameterized test).
## WHY: so no test can ever read or overwrite the real save.json.
## HOW IT RUNS: GUT calls a function with exactly this name (before_each) automatically before every test in this file, and before every case of a parameterized test. It is not a test, so it has no check inside.
func before_each() -> void: # The name before_each is special, GUT looks for it. It has no test_ at the start on purpose
	game_manager = autofree(load("res://scripts/autoload/game_manager.gd").new()) # fresh object, freed after the test
	game_manager.SAVE_PATH = TEST_SAVE_PATH # swap the real path for the test path
	if FileAccess.file_exists(TEST_SAVE_PATH): # a previous crashed run could leave a file behind
		DirAccess.remove_absolute(TEST_SAVE_PATH) # remove it so every test starts clean


# Cleanup after every test and every case
## WHAT: deletes the test save file.
## WHY: a file made by one case must not leak into the next one.
## HOW IT RUNS: GUT calls a function with exactly this name (after_each) automatically after every test in this file, and after every case of a parameterized test. It is not a test, so it has no check inside.
func after_each() -> void: # The name after_each is special, GUT looks for it. It has no test_ at the start on purpose
	if FileAccess.file_exists(TEST_SAVE_PATH): # only delete if the test created the file
		DirAccess.remove_absolute(TEST_SAVE_PATH) # remove it from disk


# Easter egg at exactly 10000 gold (3 cases)
## WHAT: add_gold() that brings gold to exactly 10000, in three situations (a parameterized test: one function, run once per case).
## WHY: the "Legend of Gold" easter egg must fire once, only after the victory screen, and never again.
## PASSES when: the signal count and the saved flag match the expected values of each case.
func test_gold_milestone_signal_depends_on_victory_and_seen_flag(params = use_parameters(MILESTONE_CASES)) -> void: # Name starts with test_ so GUT runs it
	var case_name: String = params[0] # the name of this case, used in messages
	game_manager.victory_continued = params[1] # did the player pass the victory screen
	game_manager.gold_milestone_seen = params[2] # was the egg shown before
	game_manager.gold = 9999 # one gold short of the milestone
	watch_signals(game_manager) # start listening to the signals of this object

	game_manager.add_gold(1) # gold becomes exactly 10000

	# Check 1: the signal gold_milestone_reached came once in case 1 and did not come in cases 2 and 3
	assert_signal_emit_count(game_manager, "gold_milestone_reached", params[3], case_name + ": wrong number of gold_milestone_reached signals")
	# Check 2: gold_milestone_seen is true after the egg fired or was seen before (cases 1 and 3), and stays false when the victory was not passed (case 2)
	assert_eq(game_manager.gold_milestone_seen, params[4], case_name + ": wrong value of gold_milestone_seen")
	# Check 3: only when the egg fired, the flag must also be in the saved file
	if params[3] == 1: # this check makes sense only for the case where the egg fires
		var loaded: Node = autofree(load("res://scripts/autoload/game_manager.gd").new()) # a NEW object with default values
		loaded.SAVE_PATH = TEST_SAVE_PATH # make it read the same test file
		loaded.load_game() # read the file into the new object
		assert_true(loaded.gold_milestone_seen, case_name + ": gold_milestone_seen should be saved in the file")
