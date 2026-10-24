extends GutTest # "I am a test file" - GUT (Godot Unit Test) can now find and run me
# Checks the real settings screen: pressing the language button changes the real game language and saves it.

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


# Switching to the next language
## WHAT: opens the real settings screen with English selected and presses the button "next language" (">").
## WHY: the unit tests check the language lists. This test checks the whole chain: the click, the language number, the language of the engine, the text of the switcher and the saved number.
## PASSES when: the language number is 1 (Russian), the engine language is ru, the switcher shows its name, and the test save file has number 1.
func test_pressing_next_language_button_switches_language_and_saves() -> void: # Name starts with test_ so GUT runs it
	GameManager.language_index = 0 # English is position 0, set BEFORE the screen opens so it starts in English
	var settings: Node = add_child_autoqfree(load("res://scenes/settings_panel.tscn").instantiate()) # the real settings screen, placed into the test and removed after it
	await wait_process_frames(2) # let the screen finish its _ready (await = wait here, then go on)
	var next_button: Button = settings.get_node("%LanguageNextButton") # % finds a node by its unique name: the button ">"
	var value_label: Label = settings.get_node("%LanguageValueLabel") # the text between the two buttons, it shows the language name

	# Check 1: before the click the engine language is English
	assert_eq(TranslationServer.get_locale(), "en", "The engine language should be en before the click")
	# Check 2: before the click the switcher shows ENGLISH
	assert_eq(value_label.text, "ENGLISH", "The switcher should show ENGLISH before the click")

	next_button.pressed.emit() # press the button, like a click of the player
	await wait_process_frames(2) # let the screen finish reacting to the click

	var loaded: Node = autofree(load("res://scripts/autoload/game_manager.gd").new()) # a NEW object with default values
	loaded.SAVE_PATH = TEST_SAVE_PATH # make it read the same test file
	loaded.load_game() # read what the language change saved

	# Check 3: the language number moved from 0 to 1
	assert_eq(GameManager.language_index, 1, "The language number should be 1 after the click")
	# Check 4: the engine really switched to Russian
	assert_eq(TranslationServer.get_locale(), "ru", "The engine language should be ru after the click")
	# Check 5: the switcher shows the name of the new language (the keys of ui.csv give the same name in every language)
	assert_eq(value_label.text, "РУССКИЙ", "The switcher should show РУССКИЙ after the click")
	# Check 6: the new language number was saved to the test file
	assert_eq(loaded.language_index, 1, "Language number should be in the saved file")
