extends GutTest # "I am a test file" - GUT (Godot Unit Test) can now find and run me
# Checks the language switcher lists in the settings screen.


# Same length
## WHAT: compares how many language names and how many language codes the settings screen has.
## WHY: the switcher uses one position number for both lists (name and code at the same position); if the lists have different lengths, it picks the wrong language or fails at the end of the list.
## PASSES when: LANGUAGE_KEYS and LOCALE_CODES have the same number of items. FAILS when one list is longer than the other.
func test_settings_language_lists_have_same_length() -> void: # Name starts with test_ so GUT runs it
	var settings: Node = autofree(load("res://scripts/ui/settings_panel.gd").new()) # The settings screen script in memory, no game window needed. GUT throws it away after the test. _ready() does not run, so nothing is connected to the sliders or buttons

	# Check 1: both lists have the same size. LANGUAGE_KEYS and LOCALE_CODES are constants (const = a value written once in the script that never changes), and we read them from the object like properties. size() gives the number of items in a list
	assert_eq(settings.LANGUAGE_KEYS.size(), settings.LOCALE_CODES.size(), "Language names and language codes should have the same number of items") # Actual value first, expected second. Both numbers are 7 now: English, Russian, Ukrainian, Spanish, German, French, Chinese


# Loaded translations
## WHAT: takes every language code from the settings screen (en, ru, uk, es, de, fr, zh_CN) and checks that the game has loaded a translation for it.
## WHY: if a code is in the list but its translation file is not connected in the project settings, the player picks the language and the texts do not change.
## PASSES when: all codes are in the list of loaded languages. FAILS when any code has no loaded translation, and the message names that code.
func test_settings_language_codes_have_loaded_translations() -> void: # Name starts with test_ so GUT runs it
	var settings: Node = autofree(load("res://scripts/ui/settings_panel.gd").new()) # The settings screen script in memory, no game window needed. GUT throws it away after the test
	var loaded_locales: PackedStringArray = TranslationServer.get_loaded_locales() # Ask the game which languages have a loaded translation. A locale is a language setting, and its short name is the code (like en, ru or zh_CN). The answer is a list of such codes

	for code in settings.LOCALE_CODES: # Runs the line below once per language code. "code" is the current code, like "ru"
		# Check 1: this code is in the list of loaded languages. assert_has(list, value, msg) passes when the list contains the value
		assert_has(loaded_locales, code, "Language code " + code + " has no loaded translation") # The message names the code, so you see right away which language to fix


# Language order
## WHAT: checks that all seven languages of the switcher stay at the same positions, both the codes and the names.
## WHY: a saved game stores the language as a position number (0 to 6). From release 1.0.2 on the order is locked: if a language moves to another position, an old saved number opens a different language. One accepted exception: Ukrainian was inserted at position 2 before 1.0.2 came out, so Spanish moved from 2 to 3 (players of 1.0.1 with Spanish see Ukrainian once).
## PASSES when: every position holds the expected code and the expected name. FAILS when any of them moved, and the message names the position. If you add a new language, put it at the END of both lists and add it here too.
func test_settings_languages_keep_saved_order() -> void: # Name starts with test_ so GUT runs it
	var settings: Node = autofree(load("res://scripts/ui/settings_panel.gd").new()) # The settings screen script in memory, no game window needed. GUT throws it away after the test
	var expected_codes: Array[String] = ["en", "ru", "uk", "es", "de", "fr", "zh_CN"] # The language codes in the order of release 1.0.2. A list: the first item has position 0, the second 1, and so on
	var expected_keys: Array[String] = ["LANG_ENGLISH", "LANG_RUSSIAN", "LANG_UKRAINIAN", "LANG_SPANISH", "LANG_GERMAN", "LANG_FRENCH", "LANG_CHINESE"] # The language names in the same order (the keys of ui.csv)

	for index in range(expected_codes.size()): # Runs the lines below once per position: 0 to 6. "index" is the current position number
		# Check 1: the code at this position is the same as expected. list[index] takes the item at that position
		assert_eq(settings.LOCALE_CODES[index], expected_codes[index], "Language code at position " + str(index) + " moved, old saves would open another language") # Actual value first, expected second. str() turns the number into text so we can glue it to the message

		# Check 2: the name at this position is the same as expected
		assert_eq(settings.LANGUAGE_KEYS[index], expected_keys[index], "Language name at position " + str(index) + " moved, old saves would show a wrong language name") # Same idea for the name list


# Language count in the saved game
## WHAT: compares the number LANGUAGE_COUNT in game_manager.gd with the real number of languages in the settings screen.
## WHY: load_game replaces a language number that is LANGUAGE_COUNT or more with 0. If a new language is added to the lists but LANGUAGE_COUNT is forgotten, the saved new language would be silently reset to English.
## PASSES when: LANGUAGE_COUNT equals the size of LOCALE_CODES. FAILS when one of them was changed without the other.
func test_language_count_in_game_manager_matches_settings_languages() -> void: # Name starts with test_ so GUT runs it
	var game_manager: Node = autofree(load("res://scripts/autoload/game_manager.gd").new()) # GameManager in memory, GUT throws it away after the test. We only read a constant from it
	var settings: Node = autofree(load("res://scripts/ui/settings_panel.gd").new()) # The settings screen script in memory, no game window needed. GUT throws it away after the test. We only read LOCALE_CODES from it

	# Check 1: the language count in game_manager.gd equals the number of languages in the settings screen. LANGUAGE_COUNT is a number (7), LOCALE_CODES is a list, size() gives the number of items in it
	assert_eq(game_manager.LANGUAGE_COUNT, settings.LOCALE_CODES.size(), "LANGUAGE_COUNT in game_manager.gd should be the same as the number of languages in settings_panel.gd") # Actual value first, expected second
