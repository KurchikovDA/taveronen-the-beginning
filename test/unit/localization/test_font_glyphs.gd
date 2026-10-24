extends GutTest # "I am a test file" - GUT (Godot Unit Test) can now find and run me
# Checks that both game fonts can draw every character used in the translation table ui.csv.

const LATIN_FONT_PATH: String = "res://assets/fonts/TaveronenStart-Regular.ttf" # Font for English, Russian, Ukrainian, Spanish, German, French (res:// = resources folder of the project)
const CHINESE_FONT_PATH: String = "res://assets/fonts/TaveronenHanzi-Regular.woff2" # Font for Chinese
const CHINESE_COLUMN: String = "zh_CN" # The name of the Chinese column in the header of ui.csv
const CHINESE_NAME_KEY: String = "LANG_CHINESE" # The key of the Chinese language name. It is the only language name that needs the Chinese font


# Fonts and characters
## WHAT: goes through every character of every text in ui.csv and asks the right font if it has a glyph (the picture of one character) for it.
## WHY: if a font has no glyph for a character, the player sees an empty square instead of the letter. This is easy to miss when you only look at some screens.
## PASSES when: every character used in the table exists in the font of its language. FAILS when any glyph is missing, and the message names the character, the key and the language.
func test_fonts_have_every_character_used_in_ui_csv() -> void: # Name starts with test_ so GUT runs it
	var latin_font: Font = load(LATIN_FONT_PATH) as Font # Load the font file from disk. "as Font" says: treat it as a font (gives null if it is not one)
	var chinese_font: Font = load(CHINESE_FONT_PATH) as Font # Load the Chinese font the same way

	# Check 1: both fonts really loaded. If a path is wrong, we get null and the checks below would crash
	assert_not_null(latin_font, "Latin font was not loaded from " + LATIN_FONT_PATH) # assert_not_null: the value must not be null (null = "nothing")
	assert_not_null(chinese_font, "Chinese font was not loaded from " + CHINESE_FONT_PATH) # Same check for the Chinese font
	if latin_font == null or chinese_font == null: # If any font is missing, stop here, there is nothing to check with
		return # Leave the function

	var table_file: FileAccess = FileAccess.open("res://translations/ui.csv", FileAccess.READ) # Open the translation table for reading (CSV = comma-separated values)
	var header: PackedStringArray = table_file.get_csv_line() # The first line: keys, en, ru, uk, es, de, fr, zh_CN. We keep it to know the language of each column

	var seen: Dictionary = {} # Remembers "language:character code" pairs we already checked, so every character is checked only once per language
	while not table_file.eof_reached(): # Repeat until the end of the file (EOF = end of file)
		var row: PackedStringArray = table_file.get_csv_line() # One row of the table: cell 0 is the key, the other cells are texts
		if row.size() < 2: # The last line of the file can be empty. Skip it
			continue
		for column in range(1, header.size()): # Go through all language columns. We start from 1 because column 0 holds the keys, not a language
			var language: String = header[column] # The language of this column, for example "de"
			var font: Font = chinese_font if language == CHINESE_COLUMN else latin_font # Pick the Chinese font for zh_CN, the Latin font for all other languages
			if row[0].begins_with("LANG_"): # A language name (like DEUTSCH) has the same text in every column and is always drawn with the font of the language it names, not the font of the column
				font = chinese_font if row[0] == CHINESE_NAME_KEY else latin_font # Only the Chinese name uses the Chinese font, all other names use the Latin font
			var text: String = row[column] # The text of this cell
			for index in range(text.length()): # Go through the text one character at a time. index is the position of the character
				var code: int = text.unicode_at(index) # The number of the character in the Unicode table (for example "A" is 65). has_char() wants this number
				if code <= 32: # Codes 32 and below are the space, the new line and other invisible characters. They have nothing to draw
					continue # Skip them
				var seen_id: String = language + ":" + str(code) # A short label like "de:196" (language and character number)
				if seen.has(seen_id): # has() answers true if we already checked this character for this language
					continue # Skip it, no need to check twice
				seen[seen_id] = true # Remember that we checked it now

				# Check 2: the font has a glyph for this character
				assert_true(font.has_char(code), "Font has no glyph for character " + text[index] + " (code " + str(code) + ") used by key " + row[0] + " in language " + language) # The message names the character, the key and the language, so you see right away what to fix

	# Check 3: we really checked some characters. If the table was empty, the loops above would check nothing and the test would still be green
	assert_gt(seen.size(), 0, "No characters were found in ui.csv") # assert_gt (greater than): at least one character must be found
