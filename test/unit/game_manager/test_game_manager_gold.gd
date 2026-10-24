extends GutTest # "I am a test file" - GUT (Godot Unit Test) can now find and run me
# Checks how GameManager adds and spends gold.

var game_manager: Node # Declared once for the whole file (outside any function), so before_each and every test can see it. At the start it holds nothing (null)


# Setup before every test
## WHAT: creates a fresh GameManager and puts it into the shared variable game_manager.
## WHY: all tests below need the same starting point, and each test needs its own new object, so gold from one test cannot leak into the next one.
## HOW IT RUNS: GUT calls a function with exactly this name (before_each) automatically before every test in this file. It is not a test, so it has no check inside.
func before_each() -> void: # The name before_each is special, GUT looks for it. It has no test_ at the start on purpose
	game_manager = autofree(load("res://scripts/autoload/game_manager.gd").new()) # A fresh GameManager in memory. It is not added to the game, so _ready() does not run: no timers, no music, your real save file is not touched. autofree asks GUT to delete it after the test


# Enough gold
## WHAT: gives the player 100 gold by hand, then spends 60 of it.
## WHY: buying things in the shop depends on spend_gold: it must take the gold away and answer "yes".
## PASSES when: spend_gold answers true and 40 gold is left. FAILS when it refuses, or the leftover is not 40.
func test_spend_gold_when_player_has_enough() -> void: # Name starts with test_ so GUT runs it
	game_manager.gold = 100 # Put 100 gold into its pocket by hand

	var was_spent: bool = game_manager.spend_gold(60) # Try to spend 60. The function answers true (done) or false (not enough gold)

	# Check 1: spending 60 of 100 gold is allowed, spend_gold answers true
	assert_true(was_spent, "Spending 60 of 100 gold should succeed") # assert_true(value, msg) passes when value is true
	# Check 2: the price was taken: 100 minus 60 leaves 40 gold
	assert_eq(game_manager.gold, 40, "40 gold should be left after spending 60 of 100") # Actual value first, expected second


# Not enough gold
## WHAT: gives the player only 50 gold by hand, then tries to spend 60.
## WHY: the player must not be able to buy something they cannot afford, and must not lose any gold by trying.
## PASSES when: spend_gold answers false and the player still has 50 gold. FAILS when it says yes, or the gold changes.
func test_spend_gold_when_player_has_not_enough() -> void: # Name starts with test_ so GUT runs it
	game_manager.gold = 50 # Put only 50 gold in by hand

	var was_spent: bool = game_manager.spend_gold(60) # Try to spend 60, which is more than the player has

	# Check 1: spending 60 of 50 gold is refused, spend_gold answers false
	assert_false(was_spent, "Spending 60 of 50 gold should be refused")
	# Check 2: a refused purchase takes nothing, the gold stays 50
	assert_eq(game_manager.gold, 50, "Gold should stay at 50 after a refused purchase")


# Add gold
## WHAT: gives the player 10 gold by hand, then adds 25 more.
## WHY: all income in the game (ticks, bonuses) goes through add_gold: it must put the new gold on top of what the player has.
## PASSES when: the player has 35 gold. FAILS when the total is anything else.
func test_add_gold_adds_to_current_gold() -> void: # Name starts with test_ so GUT runs it
	game_manager.gold = 10 # Put 10 gold in by hand

	game_manager.add_gold(25) # Add 25 gold. This function returns nothing, so there is no answer to keep

	# Check 1: add_gold puts the new gold on top of the old gold: 10 + 25 = 35
	assert_eq(game_manager.gold, 35, "10 gold plus 25 gold should be 35") # Actual value first, expected second


# Signal when gold is added
## WHAT: gives the player 10 gold by hand, starts watching the signals, then adds 25 more.
## WHY: the gold number on the screen updates from the gold_changed signal. If add_gold forgets to send it, the screen shows old gold.
## PASSES when: gold_changed was sent exactly once and carried the new total, 35. FAILS when it was not sent, sent twice, or carried another number.
func test_add_gold_emits_gold_changed_with_new_amount() -> void: # Name starts with test_ so GUT runs it
	game_manager.gold = 10 # Put 10 gold in by hand. No signal is sent for this, we only set the variable

	watch_signals(game_manager) # Start watching ALL signals of game_manager. It must come BEFORE the action, because GUT only records what happens after this line

	game_manager.add_gold(25) # Add 25 gold. Inside, the function sends gold_changed with the new total

	# Check 1: add_gold sent the gold_changed signal at least once
	assert_signal_emitted(game_manager, "gold_changed", "add_gold should send gold_changed") # The signal name goes in quotes as text
	# Check 2: the signal was sent exactly 1 time, not 0 and not 2
	assert_signal_emit_count(game_manager, "gold_changed", 1, "gold_changed should be sent exactly once")
	# Check 3: the signal carried the new total: 10 + 25 = 35
	assert_signal_emitted_with_parameters(game_manager, "gold_changed", [35]) # The values go in square brackets, as a list, because a signal can carry several values


# Signal when gold is spent
## WHAT: gives the player 100 gold by hand, starts watching the signals, then spends 60.
## WHY: after a purchase the shop redraws its buttons from the gold_changed signal. If spend_gold forgets to send it, the buttons keep the old state.
## PASSES when: gold_changed was sent exactly once and carried the gold left, 40. FAILS when it was not sent, sent twice, or carried another number.
func test_spend_gold_emits_gold_changed_with_new_amount() -> void: # Name starts with test_ so GUT runs it
	game_manager.gold = 100 # Put 100 gold in by hand. No signal is sent for this, we only set the variable

	watch_signals(game_manager) # Start watching ALL signals of game_manager. It must come BEFORE the action, because GUT only records what happens after this line

	game_manager.spend_gold(60) # Spend 60 gold. We do not keep the answer (true or false) here, this test only looks at the signal

	# Check 1: spend_gold sent the gold_changed signal at least once
	assert_signal_emitted(game_manager, "gold_changed", "spend_gold should send gold_changed")
	# Check 2: the signal was sent exactly 1 time, not 0 and not 2
	assert_signal_emit_count(game_manager, "gold_changed", 1, "gold_changed should be sent exactly once")
	# Check 3: the signal carried the gold that is left: 100 - 60 = 40
	assert_signal_emitted_with_parameters(game_manager, "gold_changed", [40]) # The value goes in square brackets, as a list


# No signal when spending is refused
## WHAT: gives the player only 50 gold by hand, starts watching the signals, then tries to spend 60.
## WHY: a refused purchase changes nothing, so the game must not be told that gold changed. A false gold_changed signal makes the shop redraw its buttons for no reason.
## PASSES when: gold_changed was NOT sent at all. FAILS when the signal comes even once.
func test_refused_spend_does_not_emit_gold_changed() -> void: # Name starts with test_ so GUT runs it
	game_manager.gold = 50 # Put only 50 gold in by hand. No signal is sent for this, we only set the variable

	watch_signals(game_manager) # Start watching ALL signals of game_manager. It must come BEFORE the action, because GUT only records what happens after this line

	game_manager.spend_gold(60) # Try to spend 60, which is more than the player has. We do not keep the answer, this test only looks at the signal

	# Check 1: a refused spend does not send the gold_changed signal at all
	assert_signal_not_emitted(game_manager, "gold_changed", "A refused spend should not send gold_changed") # assert_signal_not_emitted passes when there was no signal at all
