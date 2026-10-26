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
	_set_gut_screen_visible(true) # safety net: show the GUT result screen again even if a test stopped before it did
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


# Hide or show the GUT result screen
## WHAT: hides or shows the screen where GUT writes its results (a layer of GUT, not a part of the game).
## WHY: when the tests run from the editor, this screen covers the whole game window and catches every mouse click, so a click test could never reach the tavern buttons. On the server (GitHub) the screen is not shown, so nothing changes there.
func _set_gut_screen_visible(should_show: bool) -> void: # It starts with _ and has no test_ at the start, so GUT does not run it as a test
	var gut_layer: CanvasLayer = get_tree().root.find_child("GutLayer", true, false) as CanvasLayer # search the whole scene tree for the node named GutLayer (true = also look inside children, false = do not require an owner)
	if gut_layer != null: # if the layer is not there, there is nothing to hide
		gut_layer.visible = should_show # false hides the whole layer, true shows it


# Buying the first item by pressing the button with a signal
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


# Buying the first item with a real mouse click
## WHAT: puts 100 gold into the real GameManager, opens the real tavern scene and clicks the real fireplace button with a real mouse event, sent to the game at the position of the button.
## WHY: the test above presses the button with a signal, which checks the button logic but not that a mouse click reaches the button. A transparent panel lying over the button, a wrong size or a wrong position would stop the player, and only this test notices it.
## PASSES when: after the mouse click gold is 95, the fireplace is bought and visible, and its button is gone. FAILS when the click does not reach the button.
func test_mouse_click_on_fireplace_button_buys_item() -> void: # Name starts with test_ so GUT runs it
	GameManager.gold = 100 # enough for the fireplace (5 gold), set BEFORE the scene opens so the shop draws the button as affordable
	var tavern: Node = add_child_autoqfree(load("res://scenes/tavern.tscn").instantiate()) # the real tavern scene, placed into the test and removed after it
	await wait_process_frames(4) # the shop sets the button size one frame after _ready, so we wait a little longer than usual
	var button: Button = tavern.get_node("CanvasLayer/ShopPanel/ItemList/fireplace") # the real shop button, its name is the item id
	var sprite: Node = tavern.get_node("%FireplaceSprite") # % finds a node by its unique name: the picture of the fireplace in the room

	var viewport: Viewport = button.get_viewport() # the game window area the button is drawn in
	var button_center: Vector2 = viewport.get_final_transform() * (button.get_global_transform_with_canvas() * (button.size / 2.0)) # the middle of the button as the mouse sees it: first its place in the scene, then the window stretch (the project stretches the picture to the window size)
	var sender := GutInputSender.new(Input) # an object that sends real mouse events to the game, as a real mouse would

	# Check 1: before the click the fireplace is not in the room yet
	assert_false(sprite.visible, "The fireplace picture should be hidden before the click")

	_set_gut_screen_visible(false) # hide the GUT result screen: it lies over the game and would catch the mouse click (see the function at the top)
	sender.mouse_motion(button_center) # move the mouse over the middle of the button
	await wait_process_frames(2) # the game needs a moment to notice what is under the mouse

	# Check 2: the control under the mouse is the fireplace button itself, so nothing lies over it
	assert_eq(viewport.gui_get_hovered_control(), button, "The fireplace button should be the control under the mouse") # gui_get_hovered_control = the control the mouse is over right now

	sender.mouse_left_click_at(button_center) # press and release the left mouse button there (it takes about 16 frames)
	await wait_for_signal(sender.idle, 3) # wait until the sender has sent everything, but not longer than 3 seconds
	await wait_process_frames(2) # the button is removed with queue_free, which works at the end of the frame
	_set_gut_screen_visible(true) # show the GUT result screen again

	# Check 3: the price was taken, 100 - 5 = 95
	assert_eq(GameManager.gold, 95, "Gold should be 95 after clicking the fireplace")
	# Check 4: the fireplace is in the list of purchased items
	assert_true(GameManager.purchased_items.has("fireplace"), "fireplace should be in purchased items after the click")
	# Check 5: the fireplace picture appeared in the room
	assert_true(sprite.visible, "The fireplace picture should be visible after the click")
	# Check 6: the button disappeared from the shop (an item can be bought only once)
	assert_null(tavern.get_node_or_null("CanvasLayer/ShopPanel/ItemList/fireplace"), "The fireplace button should be removed after the click")
