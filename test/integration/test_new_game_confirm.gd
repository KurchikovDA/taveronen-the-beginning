extends GutTest # "I am a test file" - GUT (Godot Unit Test) can now find and run me
# Checks the real main menu: the New Game button asks for confirmation, and "No" keeps the progress.

# Path of the fake save file used ONLY by these tests.
# user:// = the game's user data folder. The real game uses save.json, so we never touch it.
const TEST_SAVE_PATH: String = "user://test_integration_save.json"

var real_save_path: String # the real save path of the running game, put back in after_each
var real_state: Dictionary # a copy of the real GameManager values, put back in after_each
var real_locale: String # the real language of the engine (like "en"), put back in after_each
var real_base_font: Font # the real font of the game theme, put back in after_each


# Setup before every test
## WHAT: remembers the real GameManager values, the engine language and the theme font, points GameManager to the test save file and starts from a clean game.
## WHY: this test uses the REAL GameManager and changes two more things shared by the whole game: the engine language (TranslationServer) and the font of the game theme. Without putting them back, other tests would run in another language.
## HOW IT RUNS: GUT calls a function with exactly this name (before_each) automatically before every test in this file. It is not a test, so it has no check inside.
func before_each() -> void: # The name before_each is special, GUT looks for it. It has no test_ at the start on purpose
	real_save_path = GameManager.SAVE_PATH # remember the real path first
	real_state = { # a copy of every value that save_game writes to the file
		"gold": GameManager.gold,
		"purchased_items": GameManager.purchased_items.duplicate(), # duplicate = a separate copy, so later changes do not touch it
		"language_index": GameManager.language_index,
		"music_volume": GameManager.music_volume,
		"sfx_volume": GameManager.sfx_volume,
		"game_started": GameManager.game_started,
		"item_purchase_progress": GameManager.item_purchase_progress.duplicate(),
		"item_bonus_threshold": GameManager.item_bonus_threshold.duplicate(),
		"gold_milestone_seen": GameManager.gold_milestone_seen,
		"victory_continued": GameManager.victory_continued,
	}
	real_locale = TranslationServer.get_locale() # the language the engine uses right now
	var theme_font: FontVariation = load("res://assets/game_theme.tres").default_font as FontVariation # the theme font that the settings screen swaps for Chinese
	real_base_font = theme_font.base_font # remember which font file it uses now
	GameManager.SAVE_PATH = TEST_SAVE_PATH # from this line on, every save goes to the test file
	GameManager.reset_game() # a clean game (it writes the TEST file, not the real one)


# Cleanup after every test
## WHAT: puts every real GameManager value, the engine language and the theme font back, and deletes the test save file.
## WHY: the next test (and the real game running next to the tests) must see the same game as before.
## HOW IT RUNS: GUT calls a function with exactly this name (after_each) automatically after every test in this file. It is not a test, so it has no check inside.
func after_each() -> void: # The name after_each is special, GUT looks for it. It has no test_ at the start on purpose
	GameManager.gold = real_state["gold"] # put the gold back
	GameManager.purchased_items.clear() # empty the list, then fill it with the real items
	GameManager.purchased_items.append_array(real_state["purchased_items"]) # append_array adds all items of another list
	GameManager.language_index = real_state["language_index"] # put the language back
	GameManager.music_volume = real_state["music_volume"] # put the music volume back
	GameManager.sfx_volume = real_state["sfx_volume"] # put the sound effects volume back
	GameManager.game_started = real_state["game_started"] # put the "game in progress" flag back
	GameManager.item_purchase_progress = real_state["item_purchase_progress"] # put the bonus waiting times back
	GameManager.item_bonus_threshold = real_state["item_bonus_threshold"] # put the bonus thresholds back
	GameManager.gold_milestone_seen = real_state["gold_milestone_seen"] # put the milestone flag back
	GameManager.victory_continued = real_state["victory_continued"] # put the victory flag back
	TranslationServer.set_locale(real_locale) # put the engine language back
	var theme_font: FontVariation = load("res://assets/game_theme.tres").default_font as FontVariation # the same theme font as in before_each
	theme_font.base_font = real_base_font # put the real font file back
	GameManager.SAVE_PATH = real_save_path # LAST: only now saves go to the real file again
	if FileAccess.file_exists(TEST_SAVE_PATH): # only delete if the test created the file
		DirAccess.remove_absolute(TEST_SAVE_PATH) # remove it from disk


# New Game with a game in progress
## WHAT: opens the real main menu with a game in progress, presses "New Game" (the question appears), then presses "No" (the question closes).
## WHY: a misclick on New Game used to erase the whole save. This test checks that the question appears first and that "No" keeps all progress.
## PASSES when: the question is hidden before the click, visible after it, hidden after "No"; the gold, the "game in progress" flag and the saved file stay untouched; the scene is not changed.
func test_new_game_button_asks_confirmation_and_no_keeps_progress() -> void: # Name starts with test_ so GUT runs it
	GameManager.gold = 50 # a game in progress: some gold...
	GameManager.game_started = true # ...and the flag that makes has_save() return true. Without it the button would start a new game at once and change the scene!
	GameManager.save_game() # write this progress to the TEST file, so we can check later that it was not erased
	var scene_before: Node = get_tree().current_scene # remember the current scene, to prove later that it did not change
	var menu: Node = add_child_autoqfree(load("res://scenes/main_menu.tscn").instantiate()) # the real main menu, placed into the test and removed after it
	await wait_process_frames(2) # let the menu finish its _ready (await = wait here, then go on)
	var new_game_button: Button = menu.get_node("NewGameButton") # the button "New Game" (a direct child of the menu)
	var confirm_panel: Control = menu.get_node("%ConfirmNewGamePanel") # the question window "Start a new game?"
	var no_button: Button = menu.get_node("%ConfirmNoButton") # the button "No" inside the question window

	# Check 1: before the click the question window is hidden
	assert_false(confirm_panel.visible, "The question window should be hidden before the click")

	new_game_button.pressed.emit() # press "New Game", like a click of the player
	await wait_process_frames(2) # let the menu finish reacting to the click

	# Check 2: after the click the question window is visible
	assert_true(confirm_panel.visible, "The question window should be visible after pressing New Game")
	# Check 3: nothing was erased yet, the gold is still 50
	assert_eq(GameManager.gold, 50, "The gold should be 50 before the answer")

	no_button.pressed.emit() # press "No"
	await wait_process_frames(2) # let the menu finish reacting to the click

	var loaded: Node = autofree(load("res://scripts/autoload/game_manager.gd").new()) # a NEW object with default values
	loaded.SAVE_PATH = TEST_SAVE_PATH # make it read the same test file
	loaded.load_game() # read what is in the test file now

	# Check 4: after "No" the question window is hidden again
	assert_false(confirm_panel.visible, "The question window should be hidden after pressing No")
	# Check 5: the gold is still 50
	assert_eq(GameManager.gold, 50, "The gold should still be 50 after No")
	# Check 6: the game is still marked as in progress
	assert_true(GameManager.game_started, "The game should still be in progress after No")
	# Check 7: the saved file still has the progress (it was not erased)
	assert_eq(loaded.gold, 50, "The saved file should still have 50 gold")
	# Check 8: the scene did not change (nobody pressed "Yes" by accident)
	assert_eq(get_tree().current_scene, scene_before, "The scene should not change after No")
