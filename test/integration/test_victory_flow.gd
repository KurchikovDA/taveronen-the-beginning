extends GutTest # "I am a test file" - GUT (Godot Unit Test) can now find and run me
# Checks the whole ending on the real tavern scene: the victory screen, its music and its buttons.

# Path of the fake save file used ONLY by these tests.
# user:// = the game's user data folder. The real game uses save.json, so we never touch it.
const TEST_SAVE_PATH: String = "user://test_integration_save.json"

var real_save_path: String # the real save path of the running game, put back in after_each
var real_state: Dictionary # a copy of the real GameManager values, put back in after_each


# Setup before every test
## WHAT: remembers the real GameManager values, points it to the test save file and starts from a clean game.
## WHY: these tests use the REAL GameManager (the autoload of the game, not a new object), so everything the tests change would otherwise end up in the real save.json.
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
	GameManager.SAVE_PATH = TEST_SAVE_PATH # from this line on, every save goes to the test file
	GameManager.reset_game() # a clean game: no gold, nothing bought (it writes the TEST file, not the real one)


# Cleanup after every test
## WHAT: puts every real GameManager value back and deletes the test save file.
## WHY: the next test (and the real game running next to the tests) must see the same GameManager as before.
## HOW IT RUNS: GUT calls a function with exactly this name (after_each) automatically after every test in this file. It is not a test, so it has no check inside.
func after_each() -> void: # The name after_each is special, GUT looks for it. It has no test_ at the start on purpose
	GameManager.stop_victory_theme() # stop the victory music if the test started it
	GameManager.stop_tavern_theme() # stop the tavern music if the test started it
	GameManager.resume_tavern_theme() # take the tavern player off pause (the victory screen pauses it)
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
	GameManager.SAVE_PATH = real_save_path # LAST: only now saves go to the real file again
	if FileAccess.file_exists(TEST_SAVE_PATH): # only delete if the test created the file
		DirAccess.remove_absolute(TEST_SAVE_PATH) # remove it from disk


# Victory after the last purchase
## WHAT: gives 1800 gold, opens the real tavern, presses the button of every shop item one by one and waits for the victory screen.
## WHY: the unit tests check the pieces (prices, gold, saving). This test checks the whole ending together: the last purchase, the delay, the victory screen and the music switch.
## PASSES when: all 7 items are bought, the victory screen is hidden right after the last purchase, appears after the 5 second delay, the victory music plays and the tavern music is paused. FAILS when any of these does not happen.
func test_buying_all_items_shows_victory_screen_and_music() -> void: # Name starts with test_ so GUT runs it
	GameManager.gold = 1800 # all 7 prices add up to 1800, set BEFORE the scene opens so the shop draws every button as affordable
	GameManager.play_tavern_theme() # start the tavern music, like the game does, so Check 2 and Check 7 have something to check
	var tavern: Node = add_child_autoqfree(load("res://scenes/tavern.tscn").instantiate()) # the real tavern scene, placed into the test and removed after it
	await wait_process_frames(2) # let the scene finish its _ready and its first frames (await = wait here, then go on)
	var shop: Node = tavern.get_node("CanvasLayer/ShopPanel") # the real shop panel, its script holds the list of items
	var victory_panel: Panel = tavern.get_node("%VictoryPanel") # % finds a node by its unique name: the victory screen

	# Check 1: before any purchase the victory screen is hidden
	assert_false(victory_panel.visible, "The victory screen should be hidden before the purchases")
	# Check 2: before any purchase the tavern music is playing
	assert_true(GameManager.tavern_music.playing, "The tavern music should be playing before the victory")

	for item in shop.items: # Runs the lines below once per shop item. "item" is the current item (one dictionary)
		var button: Button = tavern.get_node("CanvasLayer/ShopPanel/ItemList/" + item["id"]) # the real button of this item, its name is the item id
		button.pressed.emit() # press the button, like a click of the player

	await wait_process_frames(2) # the bought buttons are removed at the end of the frame

	# Check 3: every item of the shop is bought
	assert_eq(GameManager.purchased_items.size(), shop.items.size(), "Every shop item should be bought")
	# Check 4: right after the last purchase the victory screen is not there yet, the game waits first
	assert_false(victory_panel.visible, "The victory screen should wait for its delay after the last purchase")

	await wait_seconds(5.5) # the game waits 5 seconds (VICTORY_DELAY_SECONDS in shop_panel.gd), we wait a bit longer

	# Check 5: after the delay the victory screen is shown
	assert_true(victory_panel.visible, "The victory screen should appear after the delay")
	# Check 6: the victory music is playing
	assert_true(GameManager.victory_music.playing, "The victory music should be playing on the victory screen")
	# Check 7: the tavern music is paused, not stopped (it must continue after "Keep Playing")
	assert_true(GameManager.tavern_music.stream_paused, "The tavern music should be paused on the victory screen")
	# Check 8: the player has not pressed anything yet, so the victory is not marked as continued
	assert_false(GameManager.victory_continued, "The victory should not be marked as continued before a button is pressed")


# Keep Playing button
## WHAT: opens the real tavern, shows the victory screen with its music, then presses the real "Keep Playing" button.
## WHY: this button must close the victory screen, switch the music back to the tavern theme and remember the victory, otherwise the player loses progress or hears the wrong music.
## PASSES when: the screen is hidden, the victory music stops, the tavern music plays again, the victory is marked as continued and saved in the file. FAILS when any of these does not happen.
func test_keep_playing_button_closes_victory_screen_and_resumes_tavern_music() -> void: # Name starts with test_ so GUT runs it
	GameManager.play_tavern_theme() # start the tavern music, like the game does
	var tavern: Node = add_child_autoqfree(load("res://scenes/tavern.tscn").instantiate()) # the real tavern scene, placed into the test and removed after it
	await wait_process_frames(2) # let the scene finish its _ready and its first frames
	var victory_panel: Panel = tavern.get_node("%VictoryPanel") # % finds a node by its unique name: the victory screen
	var button: Button = tavern.get_node("CanvasLayer/VictoryPanel/VictoryCard/ContinuePlayingButton") # the real button (the full path is needed, the gold milestone screen has a button with the same name)

	GameManager.play_victory_theme() # the same call the game makes when the victory screen opens: it pauses the tavern music and plays the victory music
	victory_panel.visible = true # show the victory screen, as if the player had just bought the last item

	# Check 1: before the press the victory is not marked as continued
	assert_false(GameManager.victory_continued, "The victory should not be marked as continued before the button is pressed")

	button.pressed.emit() # press the button, like a click of the player

	# Check 2: the victory screen is hidden after the press
	assert_false(victory_panel.visible, "The victory screen should be hidden after pressing Keep Playing")
	# Check 3: the victory music is stopped
	assert_false(GameManager.victory_music.playing, "The victory music should stop after pressing Keep Playing")
	# Check 4: the tavern music is playing again, not paused
	assert_true(GameManager.tavern_music.playing and not GameManager.tavern_music.stream_paused, "The tavern music should play again after pressing Keep Playing") # "and not" = both must be true: it plays AND it is not paused
	# Check 5: the victory is marked as continued
	assert_true(GameManager.victory_continued, "The victory should be marked as continued after pressing Keep Playing")

	var file_text: String = FileAccess.get_file_as_string(TEST_SAVE_PATH) # read the whole test save file as text
	var saved: Dictionary = JSON.parse_string(file_text) # turn the JSON (JavaScript Object Notation) text into a dictionary
	# Check 6: the continued victory is written into the save file
	assert_true(saved.get("victory_continued", false), "victory_continued should be saved in the file") # get(key, default) gives false if the key is missing


# Gold milestone easter egg
## WHAT: opens the real tavern after a finished victory, adds gold up to the 10000 milestone and watches the hidden "Legend of Gold" screen.
## WHY: the easter egg must appear exactly once the player has finished the tavern and earned 10000 gold, with the victory music, and it must be remembered in the save so it never shows twice.
## PASSES when: the screen is hidden below 10000 gold, shown at 10000, the victory music plays, the tavern music is paused and the milestone is saved in the file. FAILS when any of these does not happen.
func test_reaching_10000_gold_after_victory_shows_easter_egg_with_music() -> void: # Name starts with test_ so GUT runs it
	GameManager.victory_continued = true # the player has already finished the tavern and pressed Keep Playing (without it the easter egg is locked)
	GameManager.gold = 9000 # far enough from 10000: the game adds 1 gold per second while the test runs, so we keep a safe distance
	GameManager.play_tavern_theme() # start the tavern music, like the game does
	var tavern: Node = add_child_autoqfree(load("res://scenes/tavern.tscn").instantiate()) # the real tavern scene, placed into the test and removed after it
	await wait_process_frames(2) # let the scene finish its _ready and its first frames
	var milestone_panel: Panel = tavern.get_node("%GoldMilestonePanel") # % finds a node by its unique name: the easter egg screen

	# Check 1: before the milestone the easter egg screen is hidden
	assert_false(milestone_panel.visible, "The easter egg screen should be hidden at the start")

	GameManager.add_gold(500) # 9000 + 500 = 9500, still below the milestone

	# Check 2: below 10000 gold the easter egg screen stays hidden
	assert_false(milestone_panel.visible, "The easter egg screen should stay hidden below 10000 gold")
	# Check 3: below 10000 gold the easter egg is not marked as seen
	assert_false(GameManager.gold_milestone_seen, "The easter egg should not be marked as seen below 10000 gold")

	GameManager.add_gold(500) # 9500 + 500 = 10000, the milestone is reached

	# Check 4: at 10000 gold the easter egg screen is shown
	assert_true(milestone_panel.visible, "The easter egg screen should appear at 10000 gold")
	# Check 5: the victory music is playing on the easter egg screen
	assert_true(GameManager.victory_music.playing, "The victory music should play on the easter egg screen")
	# Check 6: the tavern music is paused, not stopped (it must continue after "Keep Playing")
	assert_true(GameManager.tavern_music.stream_paused, "The tavern music should be paused on the easter egg screen")
	# Check 7: the easter egg is marked as seen, so it can never show twice
	assert_true(GameManager.gold_milestone_seen, "The easter egg should be marked as seen after it appeared")

	var file_text: String = FileAccess.get_file_as_string(TEST_SAVE_PATH) # read the whole test save file as text
	var saved: Dictionary = JSON.parse_string(file_text) # turn the JSON text into a dictionary
	# Check 8: the seen flag is written into the save file
	assert_true(saved.get("gold_milestone_seen", false), "gold_milestone_seen should be saved in the file") # get(key, default) gives false if the key is missing


# Keep Playing button on the easter egg screen
## WHAT: brings up the hidden "Legend of Gold" screen, presses its real "Keep Playing" button and then adds more gold.
## WHY: this button uses the same script as the one on the victory screen, but sits in another panel. It must close this screen, bring back the tavern music, and the easter egg must never show a second time.
## PASSES when: the screen is hidden, the victory music stops, the tavern music plays again and the screen stays hidden after more gold is added. FAILS when any of these does not happen.
func test_keep_playing_on_easter_egg_resumes_music_and_egg_never_repeats() -> void: # Name starts with test_ so GUT runs it
	GameManager.victory_continued = true # the player has already finished the tavern and pressed Keep Playing (without it the easter egg is locked)
	GameManager.gold = 9000 # far enough from 10000: the game adds 1 gold per second while the test runs, so we keep a safe distance
	GameManager.play_tavern_theme() # start the tavern music, like the game does
	var tavern: Node = add_child_autoqfree(load("res://scenes/tavern.tscn").instantiate()) # the real tavern scene, placed into the test and removed after it
	await wait_process_frames(2) # let the scene finish its _ready and connect to the milestone signal
	var milestone_panel: Panel = tavern.get_node("%GoldMilestonePanel") # % finds a node by its unique name: the easter egg screen
	var button: Button = tavern.get_node("CanvasLayer/GoldMilestonePanel/GoldMilestoneCard/ContinuePlayingButton") # the real button (the full path is needed, the victory screen has a button with the same name)

	GameManager.add_gold(1000) # 9000 + 1000 = 10000, the milestone is reached and the easter egg screen opens

	# Check 1: before the press the easter egg screen is shown
	assert_true(milestone_panel.visible, "The easter egg screen should be shown before the button is pressed")

	button.pressed.emit() # press the button, like a click of the player

	# Check 2: the easter egg screen is hidden after the press
	assert_false(milestone_panel.visible, "The easter egg screen should be hidden after pressing Keep Playing")
	# Check 3: the victory music is stopped
	assert_false(GameManager.victory_music.playing, "The victory music should stop after pressing Keep Playing")
	# Check 4: the tavern music is playing again, not paused
	assert_true(GameManager.tavern_music.playing and not GameManager.tavern_music.stream_paused, "The tavern music should play again after pressing Keep Playing") # "and not" = both must be true: it plays AND it is not paused

	GameManager.add_gold(1) # more gold after the milestone: the easter egg must not come back

	# Check 5: more gold does not open the easter egg screen a second time
	assert_false(milestone_panel.visible, "The easter egg screen should never show a second time")
