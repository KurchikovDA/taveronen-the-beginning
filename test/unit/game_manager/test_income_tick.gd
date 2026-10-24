extends GutTest # "I am a test file" - GUT (Godot Unit Test) can now find and run me
# Checks the passive income timer (_on_tick) and shows the test doubles: stub, spy, mock, partial double and full double.

# The cases of the parameterized test below. Every inner list is one case:
# [case name, count income by the real clock, milliseconds since the last payout, expected seconds paid]
const TICK_CASES: Array = [
	["editor mode: one tick is one second", false, 0, 1], # case 1: the clock is ignored, one tick = 1 second
	["real clock: 1 second passed", true, 1000, 1], # case 2: normal desktop play
	["real clock: 5 seconds passed", true, 5000, 5], # case 3: the browser tab was in the background, so we catch up
]

var game_manager: Node # the GameManager under test (a partial double, see before_each)


# Setup before every test and every case
## WHAT: makes a fresh GameManager partial double and stubs _is_income_active to answer true (also runs before every case of a parameterized test).
## WHY: _on_tick asks _is_income_active(), which looks for the tavern scene. A test has no scene, so we answer "yes" ourselves.
## HOW IT RUNS: GUT calls a function with exactly this name (before_each) automatically before every test in this file, and before every case of a parameterized test. It is not a test, so it has no check inside.
func before_each() -> void: # The name before_each is special, GUT looks for it. It has no test_ at the start on purpose
	game_manager = autofree(partial_double(load("res://scripts/autoload/game_manager.gd")).new()) # a copy of GameManager: all functions are real
	stub(game_manager, "_is_income_active").to_return(true) # ...except this one, it always answers true (the tavern is open)


# Income tick pays the passed seconds (3 cases)
## WHAT: _on_tick() once, in three situations (editor tick, real clock 1 second, real clock 5 seconds).
## WHY: passive income and click-bonus timers must pay exactly the seconds that passed, also after a hidden browser tab.
## PASSES when: gold and the bonus progress both grew by the expected number of seconds.
func test_tick_pays_gold_and_bonus_time_for_passed_seconds(params = use_parameters(TICK_CASES)) -> void: # Name starts with test_ so GUT runs it
	var case_name: String = params[0] # the name of this case, used in messages
	game_manager.count_income_by_real_clock = params[1] # which way to count seconds
	game_manager._last_tick_msec = Time.get_ticks_msec() - params[2] # pretend the last payout was params[2] milliseconds ago
	game_manager.gold = 0 # start from zero gold, so gold equals the paid seconds
	game_manager.purchased_items.append("fireplace") # one bought item, so its bonus timer can run
	game_manager.item_purchase_progress["fireplace"] = 10 # it has waited 10 seconds
	game_manager.item_bonus_threshold["fireplace"] = 100 # and needs 100, so it is not ready and keeps counting

	game_manager._on_tick() # the timer fires once

	# Check 1: gold grew by the expected seconds (gold_per_second is 1)
	assert_eq(game_manager.gold, params[3], case_name + ": wrong gold after the tick")
	# Check 2: the bonus timer caught up by the same seconds
	assert_eq(game_manager.item_purchase_progress.get("fireplace", -1), 10 + params[3], case_name + ": wrong bonus progress after the tick")


# Income tick while the tavern is closed
## WHAT: _on_tick() while the tavern is closed (main menu, intro, victory screen), with the real clock showing 5 seconds passed.
## WHY: time spent outside the tavern must never be paid, neither now nor later when the tavern opens again.
## PASSES when: gold and bonus progress did not change, add_gold and _tick_bonus_progress were never called, and the clock moved forward.
func test_tick_pays_nothing_when_tavern_is_closed() -> void: # Name starts with test_ so GUT runs it
	stub(game_manager, "_is_income_active").to_return(false) # the newest stub wins: now the tavern is closed
	game_manager.count_income_by_real_clock = true # count by the real clock, so 5 seconds WOULD be paid if the tavern were open
	var old_clock: int = Time.get_ticks_msec() - 5000 # the last payout was 5 seconds ago (msec = milliseconds)
	game_manager._last_tick_msec = old_clock # put that time into the object
	game_manager.gold = 50 # known gold before the tick
	game_manager.purchased_items.append("fireplace") # one bought item, so its bonus timer exists
	game_manager.item_purchase_progress["fireplace"] = 10 # it has waited 10 seconds
	game_manager.item_bonus_threshold["fireplace"] = 100 # and needs 100, so it is not ready

	game_manager._on_tick() # the timer fires once

	# Check 1: gold did not change
	assert_eq(game_manager.gold, 50, "Gold should stay the same when the tavern is closed")
	# Check 2: the bonus timer did not move
	assert_eq(game_manager.item_purchase_progress.get("fireplace", -1), 10, "Bonus progress should stay the same when the tavern is closed")
	# Check 3: spy, add_gold was never called (even add_gold(0) would be caught)
	assert_not_called(game_manager, "add_gold")
	# Check 4: spy, the bonus timers were never asked to count
	assert_not_called(game_manager, "_tick_bonus_progress")
	# Check 5: the clock moved forward, so the missed 5 seconds will never be paid later (gte = greater than or equal)
	assert_gte(game_manager._last_tick_msec, old_clock + 5000, "The clock should move to now, so the closed time is never paid later")


# Income tick after a very long pause
## WHAT: _on_tick() after a very long pause (1000 seconds), counting by the real clock.
## WHY: all seconds must be paid as gold, but the bonus timers are moved at most 300 times (BONUS_MAX_WAIT_SECONDS), because after 300 seconds every coin is ready anyway.
## PASSES when: gold grew by 1000 and _tick_bonus_progress was called exactly 300 times.
func test_tick_moves_bonus_timers_at_most_300_times_after_long_pause() -> void: # Name starts with test_ so GUT runs it
	game_manager.count_income_by_real_clock = true # count by the real clock, so the long pause is counted
	game_manager._last_tick_msec = Time.get_ticks_msec() - 1000000 # the last payout was 1000 seconds ago (msec = milliseconds)
	game_manager.gold = 0 # start from zero gold, so gold equals the paid seconds

	game_manager._on_tick() # the timer fires once, after the long pause

	# Check 1: all 1000 seconds were paid as gold
	assert_eq(game_manager.gold, 1000, "All 1000 seconds should be paid as gold")
	# Check 2: spy, the bonus timer was moved exactly 300 times, not 1000
	assert_called_count(game_manager._tick_bonus_progress, 300)


# Collecting a bonus saves exactly once (mock)
## WHAT: collect_bonus() for a ready bonus, while save_game() is replaced by an empty stub (a mock check: we check the call, not the file).
## WHY: a collected bonus must be saved right away, exactly once. For that we do not need a real file.
## PASSES when: save_game was called exactly once, no file was written, and the gold still grew by the reward.
func test_collect_bonus_calls_save_game_exactly_once() -> void: # Name starts with test_ so GUT runs it
	var fake_path: String = "user://test_mock_never_written.json" # a path that must stay empty
	stub(game_manager, "save_game").to_do_nothing() # the real save_game writes a file, now it does nothing
	game_manager.SAVE_PATH = fake_path # safety: even if the stub failed, the real save.json is not touched
	game_manager.gold = 10 # known gold before the click
	game_manager.purchased_items.append("fireplace") # the item is bought
	game_manager.item_purchase_progress["fireplace"] = 100 # waited 100 seconds
	game_manager.item_bonus_threshold["fireplace"] = 100 # needed 100 seconds, so the bonus is ready

	game_manager.collect_bonus("fireplace") # the player clicks the coin

	# Check 1: mock, save_game was called exactly one time
	assert_called_count(game_manager.save_game, 1)
	# Check 2: no file appeared, so the stub really replaced save_game
	assert_false(FileAccess.file_exists(fake_path), "No file should be written, save_game was replaced by a stub")
	# Check 3: the rest of collect_bonus is real, so gold grew by the reward of 1-5
	assert_between(game_manager.gold, 11, 15, "Gold should grow by the reward of 1-5")
	# Cleanup: remove the file if the stub did not work, so a red run leaves nothing behind
	if FileAccess.file_exists(fake_path): # only if the file exists
		DirAccess.remove_absolute(fake_path) # remove it from disk


# Full double records calls but runs no real code
## WHAT: a FULL double of GameManager (double, not partial_double): every function is empty and only records the call.
## WHY: a teaching example, it shows the difference from the partial double. The game uses GameManager by its global name, so a full double cannot replace it inside other scripts.
## PASSES when: add_gold changed nothing but the call was recorded, and a stubbed function answers what we told it.
func test_full_double_does_not_run_real_code_but_records_calls() -> void: # Name starts with test_ so GUT runs it
	var full_double: Node = autofree(double(load("res://scripts/autoload/game_manager.gd")).new()) # all functions are empty
	stub(full_double, "spend_gold").to_return(true) # the only function that has an answer: always true
	full_double.gold = 10 # a variable is still a normal variable

	full_double.add_gold(5) # the real add_gold would make 15, the empty one does nothing

	# Check 1: the real code did not run, gold is the same
	assert_eq(full_double.gold, 10, "A full double should not run the real add_gold")
	# Check 2: spy, the call was recorded with its parameter
	assert_called(full_double, "add_gold", [5])
	# Check 3: stub, spend_gold answers true, although the real one would refuse 999 gold when we have 10
	assert_true(full_double.spend_gold(999), "The stubbed spend_gold should answer true")
