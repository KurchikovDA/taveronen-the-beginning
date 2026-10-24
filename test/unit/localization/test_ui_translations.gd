extends GutTest # "I am a test file" - GUT (Godot Unit Test) can now find and run me
# Checks the translation table ui.csv: every key has a text in every language.


# Filled translations
## WHAT: opens ui.csv, goes through every key row by row and checks that the cells of all 7 languages (en, ru, uk, es, de, fr, zh_CN) are not empty.
## WHY: an empty cell means the player sees a blank button or the raw key (like MENU_QUIT) instead of text.
## PASSES when: all 35 keys have text in all 7 languages. FAILS when any cell is empty, and the message names the key and the language.
func test_ui_csv_has_no_empty_translations() -> void: # Name starts with test_ so GUT runs it
	var file: FileAccess = FileAccess.open("res://translations/ui.csv", FileAccess.READ) # Open the translation table for reading. "res://" (resources) is the project folder, so this is the same file the game uses
	var header: PackedStringArray = file.get_csv_line() # Read the first line: keys, en, ru, uk, es, de, fr, zh_CN. get_csv_line() reads one table row and splits it into cells (CSV = comma-separated values). Texts with line breaks inside quotes stay in one cell
	var key_count: int = 0 # A counter of keys we have checked. It protects us from a test that "passes" because it read nothing

	while not file.eof_reached(): # Repeat until the end of the file. eof_reached() (EOF = end of file) answers true when there is nothing left to read, "not" flips it. Each round reads the next row of the table
		var row: PackedStringArray = file.get_csv_line() # One row: cell 0 is the key, cells 1 to 7 are the texts in en (English), ru (Russian), uk (Ukrainian), es (Spanish), de (German), fr (French), zh_CN (Simplified Chinese)
		if row.size() < 2: # The last line of the file can be empty and gives a row with one empty cell. Skip it, it is not a key
			continue
		key_count += 1 # One more key found

		for column in range(1, header.size()): # Walk through the language columns 1 to 7 (we skip column 0, it is the key itself). The number of columns comes from the header, so a new language is checked automatically
			# Check 1: the text in this language is not empty. assert_ne (not equal) passes when the two values are different. strip_edges() cuts spaces on both sides, so a cell with only spaces counts as empty
			assert_ne(row[column].strip_edges(), "", "Key " + row[0] + " has an empty text in language " + header[column]) # The message names the key and the language, so you see right away which cell to fix

	# Check 2: we really found 35 keys. If the file was empty or the path was wrong, the loop above would check nothing and the test would still be green. It also turns red when a key is added or removed, so the change is noticed on purpose
	assert_eq(key_count, 35, "ui.csv should have 35 keys") # assert_eq (equal): the counter must be exactly 35
