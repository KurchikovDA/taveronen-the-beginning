extends GutTest # "I am a test file" - GUT (Godot Unit Test) can now find and run me
# Checks the shop item data: count, prices, required fields and unique ids.

var shop: Node # Declared once for the whole file (outside any function), so before_each and every test can see it. At the start it holds nothing (null)


# Setup before every test
## WHAT: creates a fresh shop and puts it into the shared variable shop.
## WHY: every test below reads the shop data, and each test needs its own new shop object, so one test cannot change the data of another.
## HOW IT RUNS: GUT calls a function with exactly this name (before_each) automatically before every test in this file. It is not a test, so it has no check inside.
func before_each() -> void: # The name before_each is special, GUT looks for it. It has no test_ at the start on purpose
	shop = autofree(load("res://scripts/gameplay/shop_panel.gd").new()) # A fresh shop in memory, no game window needed. autofree asks GUT to delete it after the test


# Item count
## WHAT: counts the items in the shop.
## WHY: protects us from deleting or adding an item by accident (the release has exactly 7).
## PASSES when: the shop has 7 items. FAILS when there are more or fewer.
func test_shop_has_seven_items() -> void: # Name starts with test_ so GUT runs it
	# Check 1: the shop has exactly 7 items
	assert_eq(shop.items.size(), 7, "Shop should have 7 items") # Count the items in the shop. If it is not 7, the test fails and shows this message


# Price order
## WHAT: walks through the shop items one by one and compares each price with the previous one.
## WHY: the shop is built so that each next item costs more; a wrong price would break the game balance.
## PASSES when: every item is more expensive than the one before it. FAILS when any price is equal or lower.
func test_shop_prices_are_ascending() -> void: # Name starts with test_ so GUT runs it
	var items: Array = shop.items # Take the shop's list of 7 items and call it "items"

	for i in range(1, items.size()): # Repeat for item number 1, 2, 3 ... 6 (we skip number 0, it has nobody before it)
		var previous_price: int = items[i - 1]["price"] # Price of the item BEFORE this one
		var current_price: int = items[i]["price"] # Price of THIS item

		# Check 1: each item costs more than the one before it
		assert_gt(current_price, previous_price, "Each price should be higher than the previous one") # If not, the test fails and shows this message


# Release prices
## WHAT: collects all prices from the shop into one list and compares it with the list we expect.
## WHY: if someone changes a price by accident (170 becomes 175), the game balance changes without anyone noticing.
## PASSES when: the prices are exactly 5, 60, 100, 170, 280, 460, 725 in this order. FAILS when any price or the order is different.
func test_shop_prices_match_release() -> void: # Name starts with test_ so GUT runs it
	var actual_prices: Array = [] # An empty list. We will put the real prices from the shop in it

	for item in shop.items: # Take the shop items one by one. Each time, "item" is the next item
		actual_prices.append(item["price"]) # Take the price of this item and add it to the end of our list

	var expected_prices: Array = [5, 60, 100, 170, 280, 460, 725] # The prices we EXPECT. This is our reference list from the release

	# Check 1: the prices in the shop are exactly the release prices, in the same order
	assert_eq(actual_prices, expected_prices, "Shop prices should match the release prices") # If not, the test fails and shows both lists


# Total price
## WHAT: adds up the prices of all shop items into one number.
## WHY: the whole game is balanced to take 30 minutes: the player earns 1 gold per second, so all items together must cost 1800 gold (1800 seconds).
## PASSES when: the sum of all prices is exactly 1800. FAILS when any price changes and the sum is different.
func test_shop_prices_add_up_to_30_minutes() -> void: # Name starts with test_ so GUT runs it
	var total_price: int = 0 # A counter that starts at zero. We will add every price to it

	for item in shop.items: # Take the shop items one by one. Each time, "item" is the next item
		total_price += item["price"] # Add the price of this item to the counter. It is the same as: total_price = total_price + price

	# Check 1: all prices together cost exactly 1800 gold (30 minutes at 1 gold per second)
	assert_eq(total_price, 1800, "All prices together should be 1800 gold (30 minutes at 1 gold per second)") # Actual value first, expected second


# Item fields
## WHAT: walks through the shop items one by one and checks that each has an id, a name key and a price above zero.
## WHY: the shop builds its buttons from these fields; a missing field or a zero price would break a button or give an item for free.
## PASSES when: all 7 items have "id", "name_key" and a price above 0. FAILS when any item misses a field or costs 0 or less.
func test_shop_items_have_required_fields() -> void: # Name starts with test_ so GUT runs it
	for item in shop.items: # Runs the lines below once per shop item. "item" is the current item (one dictionary), it exists only inside the loop
		# Check 1: every item has the field "id"
		assert_true(item.has("id"), "Every item should have an id") # has() answers true or false, no field means false and the test fails
		# Check 2: every item has the field "name_key"
		assert_true(item.has("name_key"), "Every item should have a name key")
		# Check 3: every item has a price above zero
		assert_gt(item.get("price", 0), 0, "Every item should have a price above zero") # get("price", 0) reads the price, and if the item has no price at all, it gives 0 instead of crashing. assert_gt(got, expected) passes only when got is strictly greater than expected. So a price of 0, a negative price, or a missing price all fail. Both numbers must be the same type (int and int), otherwise GUT reports a failure


# Unique ids
## WHAT: walks through the shop items one by one and checks that no id appears twice.
## WHY: the game tells items apart by their id; two items with the same id could mix up purchases or show one item twice.
## PASSES when: all 7 ids are different from each other. FAILS when any id is used by more than one item.
func test_shop_item_ids_are_unique() -> void: # Name starts with test_ so GUT runs it
	var seen_ids: Array = [] # An empty list. We put every id here after checking it, so it holds the ids we have already met

	for item in shop.items: # Runs the lines below once per shop item. "item" is the current item (one dictionary)
		# Check 1: the id of this item was not met before, so no id repeats
		assert_false(seen_ids.has(item["id"]), "Item id should be unique: " + item["id"]) # has() answers true if the list contains the value. We want false here, so a repeated id makes the test fail and the message shows which id it is
		seen_ids.append(item["id"]) # Now remember this id, so the next items can be compared with it
