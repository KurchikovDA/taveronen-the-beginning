extends GutTest # "I am a test file" - GUT (Godot Unit Test) can now find and run me
# Checks saving and loading of the game: save_game, load_game, reset_game and the click bonus data.

# Path of the fake save file used ONLY by these tests.
# user:// = the game's user data folder. The real game uses save.json, so we never touch it.
const TEST_SAVE_PATH: String = "user://test_save.json"

var game_manager: Node # the GameManager under test


# Setup before every test
## WHAT: makes a fresh GameManager and points it to the test save file.
## WHY: so no test can ever read or overwrite the real save.json.
## HOW IT RUNS: GUT calls a function with exactly this name (before_each) automatically before every test in this file. It is not a test, so it has no check inside.
func before_each() -> void: # The name before_each is special, GUT looks for it. It has no test_ at the start on purpose
	game_manager = autofree(load("res://scripts/autoload/game_manager.gd").new()) # fresh object, freed after the test
	game_manager.SAVE_PATH = TEST_SAVE_PATH # swap the real path for the test path
	if FileAccess.file_exists(TEST_SAVE_PATH): # a previous crashed run could leave a file behind
		DirAccess.remove_absolute(TEST_SAVE_PATH) # remove it so every test starts clean


# Cleanup after every test
## WHAT: deletes the test save file.
## WHY: a file made by one test must not leak into the next one.
## HOW IT RUNS: GUT calls a function with exactly this name (after_each) automatically after every test in this file. It is not a test, so it has no check inside.
func after_each() -> void: # The name after_each is special, GUT looks for it. It has no test_ at the start on purpose
	if FileAccess.file_exists(TEST_SAVE_PATH): # only delete if the test created the file
		DirAccess.remove_absolute(TEST_SAVE_PATH) # remove it from disk


# No save file at all
## WHAT: load_game() when there is no save file at all.
## WHY: this is a brand new player, the game must not crash and must not wipe anything.
## PASSES when: values stay as they were and no file appears.
func test_load_game_without_file_keeps_state() -> void: # Name starts with test_ so GUT runs it
	game_manager.gold = 50 # put a known value into the object
	game_manager.purchased_items.append("fireplace") # and a known purchased item

	game_manager.load_game() # no file exists, so this should do nothing

	# Check 1: gold was not changed by loading
	assert_eq(game_manager.gold, 50, "Gold should stay the same when there is no save file")
	# Check 2: the purchased item is still there
	assert_true(game_manager.purchased_items.has("fireplace"), "Purchased items should stay the same when there is no save file")
	# Check 3: load_game must not create a file by itself
	assert_false(FileAccess.file_exists(TEST_SAVE_PATH), "load_game should not create a save file")


# Save, then load into a new object
## WHAT: save_game() followed by load_game() into a brand new GameManager.
## WHY: the whole point of a save is that progress comes back after restarting the game.
## PASSES when: every field has the same value after loading as it had before saving.
func test_save_then_load_restores_all_fields() -> void: # Name starts with test_ so GUT runs it
	game_manager.gold = 123 # not the default 0
	game_manager.purchased_items.append("fireplace") # first purchased item
	game_manager.purchased_items.append("chair") # second purchased item
	game_manager.language_index = 2 # not the default 0
	game_manager.music_volume = 40.0 # not the default 100.0
	game_manager.sfx_volume = 70.0 # not the default 100.0
	game_manager.game_started = true # not the default false
	game_manager.item_purchase_progress["fireplace"] = 25 # seconds waited so far
	game_manager.item_bonus_threshold["fireplace"] = 100 # seconds needed for the bonus
	game_manager.gold_milestone_seen = true # not the default false
	game_manager.victory_continued = true # not the default false

	game_manager.save_game() # write everything to the test file

	var loaded: Node = autofree(load("res://scripts/autoload/game_manager.gd").new()) # a NEW object with default values
	loaded.SAVE_PATH = TEST_SAVE_PATH # make it read the same test file
	loaded.load_game() # read the file into the new object

	# Check 1: save_game really created the file
	assert_true(FileAccess.file_exists(TEST_SAVE_PATH), "save_game should create the save file")
	# Check 2: gold came back
	assert_eq(loaded.gold, 123, "Gold should be restored from the file")
	# Check 3: both purchased items came back (size first, then each id)
	assert_eq(loaded.purchased_items.size(), 2, "Two purchased items should be restored")
	# Check 4: first item id is there
	assert_true(loaded.purchased_items.has("fireplace"), "fireplace should be restored in purchased items")
	# Check 5: second item id is there
	assert_true(loaded.purchased_items.has("chair"), "chair should be restored in purchased items")
	# Check 6: language came back
	assert_eq(loaded.language_index, 2, "Language index should be restored from the file")
	# Check 7: music volume came back
	assert_eq(loaded.music_volume, 40.0, "Music volume should be restored from the file")
	# Check 8: sound effects volume came back
	assert_eq(loaded.sfx_volume, 70.0, "Sound effects volume should be restored from the file")
	# Check 9: the flag "a game is in progress" came back
	assert_true(loaded.game_started, "game_started should be restored from the file")
	# Check 10: bonus waiting time came back as a whole number
	assert_eq(loaded.item_purchase_progress.get("fireplace", -1), 25, "Bonus progress should be restored from the file")
	# Check 11: bonus threshold came back as a whole number
	assert_eq(loaded.item_bonus_threshold.get("fireplace", -1), 100, "Bonus threshold should be restored from the file")
	# Check 12: milestone flag came back
	assert_true(loaded.gold_milestone_seen, "gold_milestone_seen should be restored from the file")
	# Check 13: victory flag came back
	assert_true(loaded.victory_continued, "victory_continued should be restored from the file")


# Helper function (not a test: the name does not start with test_, so GUT does not run it by itself).
# Writes the given text into the test save file. Several tests need a hand-made file, so we do not repeat these lines.
func _write_test_file(text: String) -> void: # Gets a text and puts it into the test save file
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE) # create the file for writing
	file.store_string(text) # put the text inside
	file.close() # finish writing


# Broken save file
## WHAT: load_game() when the save file contains garbage instead of JSON.
## WHY: a file can get damaged (game closed while saving, manual edit). The game must not crash or lose data.
## PASSES when: the values stay as they were before loading.
func test_load_game_with_broken_file_keeps_state() -> void: # Name starts with test_ so GUT runs it
	game_manager.gold = 50 # put a known value into the object
	game_manager.purchased_items.append("fireplace") # and a known purchased item
	_write_test_file("this is not json {{{") # a file that is NOT valid JSON

	game_manager.load_game() # must survive the garbage and change nothing

	# Check 1: gold was not changed by the broken file
	assert_eq(game_manager.gold, 50, "Gold should stay the same when the save file is broken")
	# Check 2: the purchased item is still there
	assert_true(game_manager.purchased_items.has("fireplace"), "Purchased items should stay the same when the save file is broken")
	# Check 3: Godot writes an engine error when it cannot parse the JSON. We expect it, so we mark it as handled
	assert_engine_error("error != Error::OK", "A broken file should make the engine report a JSON parse error")


# Old save file with only gold
## WHAT: load_game() with an old save file that contains only gold.
## WHY: players with saves from older game versions must still be able to continue.
## PASSES when: gold is read from the file and every missing field has its default value.
func test_load_game_with_old_save_uses_defaults_for_missing_fields() -> void: # Name starts with test_ so GUT runs it
	_write_test_file('{"gold": 77}') # an "old" file: only one field inside

	game_manager.load_game() # read the old file

	# Check 1: the only field in the file was loaded
	assert_eq(game_manager.gold, 77, "Gold should be read from the old save")
	# Check 2: language was missing, so it should be the default 0
	assert_eq(game_manager.language_index, 0, "Missing language_index should be the default 0")
	# Check 3: music volume was missing, so it should be the default 100.0
	assert_eq(game_manager.music_volume, 100.0, "Missing music_volume should be the default 100.0")
	# Check 4: sound effects volume was missing, so it should be the default 100.0
	assert_eq(game_manager.sfx_volume, 100.0, "Missing sfx_volume should be the default 100.0")
	# Check 5: game_started was missing, so it should be false
	assert_false(game_manager.game_started, "Missing game_started should be false")
	# Check 6: no purchased items in the old file
	assert_true(game_manager.purchased_items.is_empty(), "Missing purchased_items should be an empty list")
	# Check 7: no bonus progress in the old file
	assert_true(game_manager.item_purchase_progress.is_empty(), "Missing item_purchase_progress should be an empty dictionary")
	# Check 8: no bonus thresholds in the old file
	assert_true(game_manager.item_bonus_threshold.is_empty(), "Missing item_bonus_threshold should be an empty dictionary")
	# Check 9: milestone flag was missing, so it should be false
	assert_false(game_manager.gold_milestone_seen, "Missing gold_milestone_seen should be false")
	# Check 10: victory flag was missing, so it should be false
	assert_false(game_manager.victory_continued, "Missing victory_continued should be false")


# New Game keeps the settings
## WHAT: reset_game() after the player had real progress and custom settings.
## WHY: "New Game" must wipe progress, but language and volume are settings and must stay.
## PASSES when: progress fields are back to defaults and settings keep their values.
func test_reset_game_clears_progress_but_keeps_settings() -> void: # Name starts with test_ so GUT runs it
	game_manager.gold = 50 # progress: not the default 0
	game_manager.purchased_items.append("fireplace") # progress: one purchased item
	game_manager.item_purchase_progress["fireplace"] = 25 # progress: seconds waited
	game_manager.item_bonus_threshold["fireplace"] = 100 # progress: seconds needed for the bonus
	game_manager.gold_milestone_seen = true # progress: not the default false
	game_manager.victory_continued = true # progress: not the default false
	game_manager.game_started = true # progress: a game is in progress
	game_manager.language_index = 2 # setting: not the default 0
	game_manager.music_volume = 40.0 # setting: not the default 100.0
	game_manager.sfx_volume = 70.0 # setting: not the default 100.0
	game_manager.save_game() # a save file exists before the reset, like in a real game

	game_manager.reset_game() # press "New Game"

	# Check 1: gold is back to 0
	assert_eq(game_manager.gold, 0, "Gold should be 0 after reset")
	# Check 2: no purchased items
	assert_true(game_manager.purchased_items.is_empty(), "Purchased items should be empty after reset")
	# Check 3: no bonus progress
	assert_true(game_manager.item_purchase_progress.is_empty(), "Bonus progress should be empty after reset")
	# Check 4: no bonus thresholds
	assert_true(game_manager.item_bonus_threshold.is_empty(), "Bonus threshold should be empty after reset")
	# Check 5: milestone flag is cleared
	assert_false(game_manager.gold_milestone_seen, "gold_milestone_seen should be false after reset")
	# Check 6: victory flag is cleared
	assert_false(game_manager.victory_continued, "victory_continued should be false after reset")
	# Check 7: no game in progress, so Continue stays off
	assert_false(game_manager.game_started, "game_started should be false after reset")
	# Check 8: language is a setting, it must stay
	assert_eq(game_manager.language_index, 2, "Language should stay after reset")
	# Check 9: music volume is a setting, it must stay
	assert_eq(game_manager.music_volume, 40.0, "Music volume should stay after reset")
	# Check 10: sound effects volume is a setting, it must stay
	assert_eq(game_manager.sfx_volume, 70.0, "Sound effects volume should stay after reset")


# New Game leaves a clean file on disk
## WHAT: the save file on disk after reset_game(), read by a brand new GameManager.
## WHY: after "New Game" the player may close and reopen the game. Old progress must not come back.
## PASSES when: the file exists, has clean progress, and still has the settings.
func test_reset_game_leaves_clean_save_file_on_disk() -> void: # Name starts with test_ so GUT runs it
	game_manager.gold = 500 # progress: not the default 0
	game_manager.purchased_items.append("fireplace") # progress: one purchased item
	game_manager.game_started = true # progress: a game is in progress
	game_manager.victory_continued = true # progress: not the default false
	game_manager.language_index = 2 # setting: not the default 0
	game_manager.music_volume = 40.0 # setting: not the default 100.0
	game_manager.save_game() # a save file with old progress exists

	game_manager.reset_game() # press "New Game"

	var loaded: Node = autofree(load("res://scripts/autoload/game_manager.gd").new()) # a NEW object with default values
	loaded.SAVE_PATH = TEST_SAVE_PATH # make it read the same test file
	loaded.load_game() # read what reset_game left on the disk

	# Check 1: the file exists again, because reset_game ends with save_game()
	assert_true(FileAccess.file_exists(TEST_SAVE_PATH), "A save file should exist after reset")
	# Check 2: old gold did not come back
	assert_eq(loaded.gold, 0, "Gold in the file should be 0 after reset")
	# Check 3: old purchases did not come back
	assert_true(loaded.purchased_items.is_empty(), "Purchased items in the file should be empty after reset")
	# Check 4: no game in progress, so Continue stays off after a restart
	assert_false(loaded.game_started, "game_started in the file should be false after reset")
	# Check 5: old victory flag did not come back
	assert_false(loaded.victory_continued, "victory_continued in the file should be false after reset")
	# Check 6: language setting survived in the file
	assert_eq(loaded.language_index, 2, "Language in the file should stay after reset")
	# Check 7: music volume setting survived in the file
	assert_eq(loaded.music_volume, 40.0, "Music volume in the file should stay after reset")


# First purchase of an item
## WHAT: mark_purchased() for an item the player has not bought yet.
## WHY: a purchase must be remembered, and the item must start its first bonus wait.
## PASSES when: the item is listed, its progress is 0, its threshold is 60-300, and the file has it.
func test_mark_purchased_adds_item_and_starts_bonus_wait() -> void: # Name starts with test_ so GUT runs it
	game_manager.mark_purchased("fireplace") # the player buys the fireplace

	var loaded: Node = autofree(load("res://scripts/autoload/game_manager.gd").new()) # a NEW object with default values
	loaded.SAVE_PATH = TEST_SAVE_PATH # make it read the same test file
	loaded.load_game() # read what mark_purchased saved

	# Check 1: the item is in the purchased list
	assert_true(game_manager.purchased_items.has("fireplace"), "fireplace should be in purchased items")
	# Check 2: the first bonus wait starts from 0 seconds
	assert_eq(game_manager.item_purchase_progress.get("fireplace", -1), 0, "Bonus progress should start at 0")
	# Check 3: the random wait is not shorter than 60 seconds and not longer than 300
	assert_between(game_manager.item_bonus_threshold.get("fireplace", -1), 60, 300, "Bonus threshold should be 60-300 seconds")
	# Check 4: the purchase was saved to the file
	assert_true(loaded.purchased_items.has("fireplace"), "fireplace should be in the saved file")
	# Check 5: the same random threshold was saved, not a different one
	assert_eq(loaded.item_bonus_threshold.get("fireplace", -1), game_manager.item_bonus_threshold["fireplace"], "The saved threshold should match the current one")


# Random threshold for 200 items
## WHAT: mark_purchased() called for 200 different items, checking every random threshold.
## WHY: one random number proves little, many numbers show that the range is really respected.
## PASSES when: all 200 items are listed and even the lowest and highest thresholds are within 60-300.
func test_mark_purchased_threshold_stays_in_range_for_many_items() -> void: # Name starts with test_ so GUT runs it
	var lowest: int = 1000 # start above the maximum, so any real threshold is lower than this
	var highest: int = 0 # start below the minimum, so any real threshold is higher than this

	for i in 200: # repeat 200 times, i goes 0, 1, 2 ... 199
		var item_id: String = "item_" + str(i) # make a unique id: item_0, item_1, item_2 ...
		game_manager.mark_purchased(item_id) # "buy" it, this rolls a random threshold
		var threshold: int = game_manager.item_bonus_threshold[item_id] # read the number that was rolled
		lowest = mini(lowest, threshold) # mini = the smaller of two integers, keep the lowest seen so far
		highest = maxi(highest, threshold) # maxi = the bigger of two integers, keep the highest seen so far

	# Check 1: every item was added to the purchased list
	assert_eq(game_manager.purchased_items.size(), 200, "All 200 items should be in purchased items")
	# Check 2: the lowest threshold is still inside 60-300
	assert_between(lowest, 60, 300, "The lowest threshold should be 60-300 seconds")
	# Check 3: the highest threshold is still inside 60-300
	assert_between(highest, 60, 300, "The highest threshold should be 60-300 seconds")


# Collecting a ready bonus
## WHAT: collect_bonus() for an item whose bonus wait is over.
## WHY: this is how the player earns click bonuses. Reward, new wait and save must all be right.
## PASSES when: reward is 1-5, gold grows by the reward, the wait restarts, and the file has the new state.
func test_collect_bonus_pays_reward_and_restarts_wait_when_ready() -> void: # Name starts with test_ so GUT runs it
	game_manager.gold = 10 # known gold before the click
	game_manager.purchased_items.append("fireplace") # the item is bought
	game_manager.item_purchase_progress["fireplace"] = 100 # waited 100 seconds
	game_manager.item_bonus_threshold["fireplace"] = 100 # needed 100 seconds, so the bonus is ready

	var amount: int = game_manager.collect_bonus("fireplace") # the player clicks the coin, we keep the reward

	var loaded: Node = autofree(load("res://scripts/autoload/game_manager.gd").new()) # a NEW object with default values
	loaded.SAVE_PATH = TEST_SAVE_PATH # make it read the same test file
	loaded.load_game() # read what collect_bonus saved

	# Check 1: the random reward is from 1 to 5 gold
	assert_between(amount, 1, 5, "The bonus reward should be 1-5 gold")
	# Check 2: gold grew exactly by the reward, not more and not less
	assert_eq(game_manager.gold, 10 + amount, "Gold should grow exactly by the reward")
	# Check 3: the wait starts again from 0 seconds
	assert_eq(game_manager.item_purchase_progress.get("fireplace", -1), 0, "Bonus progress should restart at 0")
	# Check 4: the new random wait is 60-300 seconds
	assert_between(game_manager.item_bonus_threshold.get("fireplace", -1), 60, 300, "The new bonus threshold should be 60-300 seconds")
	# Check 5: the new gold was saved to the file
	assert_eq(loaded.gold, 10 + amount, "The new gold should be in the saved file")
	# Check 6: the restarted wait was saved to the file
	assert_eq(loaded.item_purchase_progress.get("fireplace", -1), 0, "The restarted progress should be in the saved file")


# Repeated purchase of the same item
## WHAT: mark_purchased() called a second time for an item that is already bought.
## WHY: a repeated call must not duplicate the item or restart its bonus wait.
## PASSES when: the item is listed once and its progress and threshold stay as they were.
func test_mark_purchased_twice_does_not_duplicate_or_reset_item() -> void: # Name starts with test_ so GUT runs it
	game_manager.mark_purchased("fireplace") # the first purchase
	game_manager.item_purchase_progress["fireplace"] = 40 # the player has waited 40 seconds
	game_manager.item_bonus_threshold["fireplace"] = 100 # and the wait needs 100 seconds

	game_manager.mark_purchased("fireplace") # the second call for the same item

	# Check 1: the item is in the list only once
	assert_eq(game_manager.purchased_items.size(), 1, "The item should be listed once after two purchases")
	# Check 2: the waited time was not reset
	assert_eq(game_manager.item_purchase_progress.get("fireplace", -1), 40, "Bonus progress should stay 40 after a repeated purchase")
	# Check 3: the needed time was not re-rolled
	assert_eq(game_manager.item_bonus_threshold.get("fireplace", -1), 100, "Bonus threshold should stay 100 after a repeated purchase")


# Old save with a bought item but no threshold
## WHAT: load_game() with an old save that has a purchased item but no bonus threshold.
## WHY: saves from before click bonuses must not crash and must not make the coin ready at once.
## PASSES when: the item gets a new random threshold of 60-300 and its coin is not ready yet.
func test_load_game_gives_threshold_to_purchased_item_in_old_save() -> void: # Name starts with test_ so GUT runs it
	_write_test_file('{"gold": 5, "purchased_items": ["fireplace"]}') # an "old" file: a bought item, no bonus data

	game_manager.load_game() # read the old file

	# Check 1: the bought item is still in the list
	assert_true(game_manager.purchased_items.has("fireplace"), "The purchased item should be loaded from the old save")
	# Check 2: the item got a new random threshold of 60-300 seconds
	assert_between(game_manager.item_bonus_threshold.get("fireplace", -1), 60, 300, "A missing threshold should be replaced with 60-300 seconds")
	# Check 3: the coin is not ready right after loading
	assert_false(game_manager.can_collect_bonus("fireplace"), "The bonus should not be ready right after loading an old save")


# Language number that does not exist
## WHAT: load_game() with a save whose language_index is not a real language number.
## WHY: settings_panel.gd takes LOCALE_CODES[language_index], so a number outside 0-6 breaks language selection.
## PASSES when: the loaded language number is inside 0-6 and the other fields of the file still load.
func test_load_game_with_language_index_out_of_range_uses_valid_language() -> void: # Name starts with test_ so GUT runs it
	_write_test_file('{"gold": 77, "language_index": 99}') # a file with a language number that does not exist

	game_manager.load_game() # read the file

	# Check 1: the language number must be one of the 7 real positions 0-6
	assert_between(game_manager.language_index, 0, 6, "language_index should be a real language position 0-6")
	# Check 2: the bad field must not make the game drop the rest of the file
	assert_eq(game_manager.gold, 77, "Gold should still be loaded when language_index is bad")
