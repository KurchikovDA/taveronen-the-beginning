extends GutTest # "I am a test file" - GUT (Godot Unit Test) can now find and run me
# Checks the real tavern scene: pressing a button of the real shop changes the real GameManager.

# Path of the fake save file used ONLY by these tests.
# user:// = the game's user data folder. The real game uses save.json, so we never touch it.
const TEST_SAVE_PATH: String = "user://test_integration_save.json"

var real_save_path: String # the real save path of the running game, put back in after_each
var real_state: Dictionary # a copy of the real GameManager values, put back in after_each


# Setup before every test
## WHAT: remembers the real GameManager values, points it to the test save file and starts from a clean game.
## WHY: this test uses the REAL GameManager (the autoload of the game, not a new object), so everything the test changes would otherwise end up in the real save.json.
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


# Buying the first item with a click
## WHAT: puts 100 gold into the real GameManager, opens the real tavern scene and presses the button of the cheapest item (fireplace, 5 gold) in the real shop.
## WHY: the unit tests check the shop data and GameManager separately. This test checks that they really work together: the click, the payment, the saved purchase and the picture in the room.
## PASSES when: gold is 95, the fireplace is bought and visible, its button is gone, and the test save file has the purchase.
func test_pressing_fireplace_button_buys_item_and_saves() -> void: # Name starts with test_ so GUT runs it
	GameManager.gold = 100 # enough for the fireplace (5 gold), set BEFORE the scene opens so the shop draws the button as affordable
	var tavern: Node = add_child_autoqfree(load("res://scenes/tavern.tscn").instantiate()) # the real tavern scene, placed into the test and removed after it
	await wait_process_frames(2) # let the scene finish its _ready and its first frames (await = wait here, then go on)
	var button: Button = tavern.get_node("CanvasLayer/ShopPanel/ItemList/fireplace") # the real shop button, its name is the item id
	var sprite: Node = tavern.get_node("%FireplaceSprite") # % finds a node by its unique name: the picture of the fireplace in the room

	# Check 1: before the click the shop sees enough gold, so the button is enabled
	assert_false(button.disabled, "The fireplace button should be enabled with 100 gold")
	# Check 2: before the click the fireplace is not in the room yet
	assert_false(sprite.visible, "The fireplace picture should be hidden before the purchase")

	button.pressed.emit() # press the button, like a click of the player
	await wait_process_frames(2) # the button is removed with queue_free, which works at the end of the frame

	var loaded: Node = autofree(load("res://scripts/autoload/game_manager.gd").new()) # a NEW object with default values
	loaded.SAVE_PATH = TEST_SAVE_PATH # make it read the same test file
	loaded.load_game() # read what the purchase saved

	# Check 3: the price was taken, 100 - 5 = 95
	assert_eq(GameManager.gold, 95, "Gold should be 95 after buying the fireplace for 5")
	# Check 4: the fireplace is in the list of purchased items
	assert_true(GameManager.purchased_items.has("fireplace"), "fireplace should be in purchased items")
	# Check 5: the fireplace picture appeared in the room
	assert_true(sprite.visible, "The fireplace picture should be visible after the purchase")
	# Check 6: the button disappeared from the shop (an item can be bought only once)
	assert_null(tavern.get_node_or_null("CanvasLayer/ShopPanel/ItemList/fireplace"), "The fireplace button should be removed after the purchase")
	# Check 7: the purchase was saved to the test file
	assert_true(loaded.purchased_items.has("fireplace"), "fireplace should be in the saved file")
	# Check 8: the gold after the payment was saved too
	assert_eq(loaded.gold, 95, "Gold 95 should be in the saved file")
