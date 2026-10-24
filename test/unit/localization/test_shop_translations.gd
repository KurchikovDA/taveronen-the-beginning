extends GutTest # "I am a test file" - GUT (Godot Unit Test) can now find and run me
# Checks that the texts the shop shows to the player exist in the translation table.


# Item names
## WHAT: walks through the shop items one by one and asks the game to translate each item's name key (like ITEM_TORCH).
## WHY: if a key is misspelled, the shop button shows the raw key instead of a name, and the player sees ITEM_TORCH on the screen.
## PASSES when: all 7 name keys are translated into real texts. FAILS when any key comes back unchanged, and the message names that key.
func test_shop_item_names_have_translations() -> void: # Name starts with test_ so GUT runs it
	var shop: Node = autofree(load("res://scripts/gameplay/shop_panel.gd").new()) # A shop in memory, no game window needed. GUT throws it away after the test

	for item in shop.items: # Runs the lines below once per shop item. "item" is the current item (one dictionary)
		var key: String = item["name_key"] # The name key of this item, for example "ITEM_TORCH". It is the label we look up in ui.csv
		var translated: String = shop.tr(key) # tr() (short for translate) is the same function the shop uses to show names. It takes a key and gives back the text in the current language. If the key is not in the table, it gives the key itself back

		# Check 1: the item name is translated into a real text, not left as the raw key like ITEM_TORCH. assert_ne (not equal) passes when the two values are different, so a real text passes and an unknown key fails
		assert_ne(translated, key, "Item name key " + key + " has no translation") # The message names the key, so you see right away which one to fix


# Price suffix
## WHAT: asks the game to translate the key ITEM_PRICE_SUFFIX, the word that the shop writes after every price (like "GOLD").
## WHY: if this key is misspelled or missing, every shop button shows the raw key ITEM_PRICE_SUFFIX after the price.
## PASSES when: the key is translated into a real text. FAILS when the key comes back unchanged.
func test_shop_price_suffix_has_translation() -> void: # Name starts with test_ so GUT runs it
	var shop: Node = autofree(load("res://scripts/gameplay/shop_panel.gd").new()) # A shop in memory, no game window needed. GUT throws it away after the test

	var key: String = "ITEM_PRICE_SUFFIX" # The key the shop asks for after each price. It is written in the shop code as plain text, so we write it here too
	var translated: String = shop.tr(key) # Ask the game to translate it, the same way the shop does. An unknown key comes back unchanged

	# Check 1: the price suffix is translated into a real text, not left as the raw key ITEM_PRICE_SUFFIX. assert_ne (not equal) passes when the two values are different
	assert_ne(translated, key, "Price suffix key " + key + " has no translation") # The message names the key, so you see right away what to fix
