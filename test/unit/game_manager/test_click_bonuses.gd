extends GutTest # "I am a test file" - GUT (Godot Unit Test) can now find and run me
# Checks the click bonuses: the coin that shows up over a bought item after a wait.

var game_manager: Node # Declared once for the whole file (outside any function), so before_each and every test can see it. At the start it holds nothing (null)


# Setup before every test
## WHAT: creates a fresh GameManager and puts it into the shared variable game_manager.
## WHY: every test needs its own new object, so bought items and timers from one test cannot leak into the next one.
## HOW IT RUNS: GUT calls a function with exactly this name (before_each) automatically before every test in this file. It is not a test, so it has no check inside.
func before_each() -> void: # The name before_each is special, GUT looks for it. It has no test_ at the start on purpose
	game_manager = autofree(load("res://scripts/autoload/game_manager.gd").new()) # A fresh GameManager in memory. It is not added to the game, so _ready() does not run: no timers, no music, your real save file is not touched. autofree asks GUT to delete it after the test


# Item that is not bought
## WHAT: asks if the click bonus of "fireplace" can be collected when the player has bought nothing.
## WHY: a coin must never be collectable over an item the player does not own, or free gold could appear from nowhere.
## PASSES when: can_collect_bonus answers false. FAILS when it answers true.
func test_can_collect_bonus_is_false_for_item_that_is_not_purchased() -> void: # Name starts with test_ so GUT runs it
	var can_collect: bool = game_manager.can_collect_bonus("fireplace") # Ask about "fireplace". A fresh GameManager has bought nothing, so the list purchased_items is empty. The function answers true or false

	# Check 1: the bonus of an item that is not bought cannot be collected, can_collect_bonus answers false
	assert_false(can_collect, "A bonus of an item that is not bought should not be collectable") # assert_false(value, msg) passes when value is false


# Bought item that still waits
## WHAT: marks "fireplace" as bought by hand, sets its wait to 100 seconds and its progress to 99, then asks if the bonus can be collected.
## WHY: the coin must not appear one second too early. 99 of 100 is the closest "not ready yet" we can make, so it catches off-by-one mistakes.
## PASSES when: can_collect_bonus answers false. FAILS when it answers true.
func test_can_collect_bonus_is_false_when_item_is_still_waiting() -> void: # Name starts with test_ so GUT runs it
	game_manager.purchased_items.append("fireplace") # Mark "fireplace" as bought by hand. We do not call mark_purchased, because it also saves the real game file
	game_manager.item_bonus_threshold["fireplace"] = 100 # This item must wait 100 seconds. In a dictionary (a table "name -> value") the name in square brackets picks one entry
	game_manager.item_purchase_progress["fireplace"] = 99 # It has already waited 99 seconds, one second short

	var can_collect: bool = game_manager.can_collect_bonus("fireplace") # Ask if the bonus can be collected now. The function answers true or false

	# Check 1: a bonus that waited 99 of 100 seconds is not collectable yet, can_collect_bonus answers false
	assert_false(can_collect, "A bonus that waited 99 of 100 seconds should not be collectable yet")


# Bought item that finished waiting
## WHAT: marks "fireplace" as bought by hand, sets its wait to 100 seconds and its progress to exactly 100, then asks if the bonus can be collected.
## WHY: the coin must appear the very second the wait is over, not one second later. Together with the 99 of 100 test this pins the border from both sides.
## PASSES when: can_collect_bonus answers true. FAILS when it answers false.
func test_can_collect_bonus_is_true_when_item_finished_waiting() -> void: # Name starts with test_ so GUT runs it
	game_manager.purchased_items.append("fireplace") # Mark "fireplace" as bought by hand. We do not call mark_purchased, because it also saves the real game file
	game_manager.item_bonus_threshold["fireplace"] = 100 # This item must wait 100 seconds
	game_manager.item_purchase_progress["fireplace"] = 100 # It has waited exactly 100 seconds, the wait is over

	var can_collect: bool = game_manager.can_collect_bonus("fireplace") # Ask if the bonus can be collected now. The function answers true or false

	# Check 1: a bonus that waited 100 of 100 seconds is collectable, can_collect_bonus answers true
	assert_true(can_collect, "A bonus that waited 100 of 100 seconds should be collectable") # assert_true(value, msg) passes when value is true


# Timer grows by one second
## WHAT: marks "fireplace" as bought by hand, sets its wait to 100 seconds and its progress to 10, then runs one timer tick.
## WHY: every second of play must add exactly 1 to the progress. If it adds 0 or 2, coins would come too late or too early.
## PASSES when: the progress is 11 after one tick. FAILS when it stays 10 or becomes another number.
func test_tick_adds_one_second_to_item_progress() -> void: # Name starts with test_ so GUT runs it
	game_manager.purchased_items.append("fireplace") # Mark "fireplace" as bought by hand. We do not call mark_purchased, because it also saves the real game file
	game_manager.item_bonus_threshold["fireplace"] = 100 # This item must wait 100 seconds, so after one tick it is still far from ready
	game_manager.item_purchase_progress["fireplace"] = 10 # It has already waited 10 seconds

	game_manager._tick_bonus_progress() # Run one tick, as the game does once per second. The name starts with _ (a hint "for the game itself"), but a test may call it. It returns nothing

	# Check 1: one tick adds exactly 1 second to the progress: 10 + 1 = 11
	assert_eq(game_manager.item_purchase_progress["fireplace"], 11, "One tick should add exactly 1 second to the progress") # Actual value first, expected second


# Timer stops when the bonus is ready
## WHAT: marks "fireplace" as bought by hand, sets its wait to 100 seconds and its progress to exactly 100 (ready), then runs one timer tick.
## WHY: a ready coin waits for the player's click. The timer must not keep counting, or the progress would grow without any limit.
## PASSES when: the progress is still 100 after the tick. FAILS when it becomes 101 or any other number.
func test_tick_does_not_count_further_when_bonus_is_ready() -> void: # Name starts with test_ so GUT runs it
	game_manager.purchased_items.append("fireplace") # Mark "fireplace" as bought by hand. We do not call mark_purchased, because it also saves the real game file
	game_manager.item_bonus_threshold["fireplace"] = 100 # This item must wait 100 seconds
	game_manager.item_purchase_progress["fireplace"] = 100 # It has waited exactly 100 seconds, so the coin is ready and waits for a click

	game_manager._tick_bonus_progress() # Run one tick, as the game does once per second. The item is already ready, so the function should skip it

	# Check 1: a ready bonus does not count further, the progress stays 100
	assert_eq(game_manager.item_purchase_progress["fireplace"], 100, "A ready bonus should stay at 100 and not count further") # Actual value first, expected second


# Signal when the bonus becomes ready
## WHAT: marks "fireplace" as bought by hand, sets its progress to 98 of 100, starts watching the signals, then runs three timer ticks.
## WHY: the tavern scene starts the pulsing coin when it hears bonus_available. The signal must come once, at the moment the wait is over, and name the right item.
## PASSES when: no signal after the first tick, then exactly one bonus_available with "fireplace" after three ticks. FAILS when it comes too early, twice, or for another item.
func test_bonus_available_is_sent_once_when_bonus_becomes_ready() -> void: # Name starts with test_ so GUT runs it
	game_manager.purchased_items.append("fireplace") # Mark "fireplace" as bought by hand. We do not call mark_purchased, because it also saves the real game file
	game_manager.item_bonus_threshold["fireplace"] = 100 # This item must wait 100 seconds
	game_manager.item_purchase_progress["fireplace"] = 98 # It has waited 98 seconds, two seconds are left

	watch_signals(game_manager) # Start watching ALL signals of game_manager. It must come BEFORE the ticks, because GUT only records what happens after this line

	game_manager._tick_bonus_progress() # Tick 1: progress goes from 98 to 99, the coin is not ready yet

	# Check 1: after the first tick the coin is not ready yet, so there is no bonus_available signal
	assert_signal_not_emitted(game_manager, "bonus_available", "bonus_available should not be sent before the wait is over")

	game_manager._tick_bonus_progress() # Tick 2: progress goes from 99 to 100, the coin becomes ready and the signal is sent
	game_manager._tick_bonus_progress() # Tick 3: the item is already ready, so the function skips it and sends nothing

	# Check 2: after all three ticks the signal was sent exactly 1 time, not 2
	assert_signal_emit_count(game_manager, "bonus_available", 1, "bonus_available should be sent exactly once")
	# Check 3: the signal carried the item name "fireplace"
	assert_signal_emitted_with_parameters(game_manager, "bonus_available", ["fireplace"]) # The value goes in square brackets, as a list


# Collecting a bonus that is not ready
## WHAT: marks "fireplace" as bought by hand with 50 of 100 seconds waited and 10 gold in the pocket, then tries to collect its bonus.
## WHY: a coin that is not ready must give nothing. Otherwise a player could get free gold, or reset the wait of a coin that is still counting.
## PASSES when: collect_bonus answers 0, the gold stays 10 and the progress stays 50. FAILS when any of them changes.
func test_collect_bonus_returns_zero_when_bonus_is_not_ready() -> void: # Name starts with test_ so GUT runs it
	game_manager.purchased_items.append("fireplace") # Mark "fireplace" as bought by hand. We do not call mark_purchased, because it also saves the real game file
	game_manager.item_bonus_threshold["fireplace"] = 100 # This item must wait 100 seconds
	game_manager.item_purchase_progress["fireplace"] = 50 # It has waited only 50 seconds, so the coin is not ready
	game_manager.gold = 10 # Put 10 gold in by hand, so we can see if it changes

	var amount: int = game_manager.collect_bonus("fireplace") # Try to collect the bonus. The function answers how much gold was given, or 0 if nothing was given

	# Check 1: a bonus that is not ready gives nothing, collect_bonus answers 0
	assert_eq(amount, 0, "A bonus that is not ready should give 0 gold") # Actual value first, expected second
	# Check 2: the gold did not change, the player still has 10 gold
	assert_eq(game_manager.gold, 10, "Gold should not change when the bonus is not ready")
	# Check 3: the wait was not reset, the progress is still 50
	assert_eq(game_manager.item_purchase_progress["fireplace"], 50, "The wait should not be reset when the bonus is not ready")
