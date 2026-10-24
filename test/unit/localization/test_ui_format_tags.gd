extends GutTest # "I am a test file" - GUT (Godot Unit Test) can now find and run me
# Checks that the format tags (like [font_size=35]) in every translation match the English text.


# Format tags
## WHAT: for every key of ui.csv takes the English text as the example and compares its format tags (the parts in square brackets, like [font_size=35] and [/font_size]) with the tags of every other language.
## WHY: if a translator loses a closing tag or changes a size, the text breaks in one language only (for example the headline stays huge to the end of the text). This is hard to notice by eye in 7 columns.
## PASSES when: every language has the same tags in the same order as English. FAILS when any language differs, and the message names the key and the language.
func test_ui_csv_format_tags_match_english() -> void: # Name starts with test_ so GUT runs it
	var table_file: FileAccess = FileAccess.open("res://translations/ui.csv", FileAccess.READ) # Open the translation table for reading (CSV = comma-separated values)
	var header: PackedStringArray = table_file.get_csv_line() # The first line: keys, en, ru, uk, es, de, fr, zh_CN. We keep it to know the language of each column

	# Check 1: the column number 1 is really English. The test uses it as the example, so if someone moves the columns, we must know about it
	assert_eq(header[1], "en", "Column 1 of ui.csv should be en, the test uses it as the example for all other languages") # Actual value first, expected second

	var regex: RegEx = RegEx.new() # A tool for searching text by a pattern (RegEx = regular expression)
	regex.compile("\\[[^\\]]*\\]") # The pattern: an opening square bracket, then any characters except a closing bracket, then a closing bracket. It finds [font_size=35] and [/font_size]. The double backslash is how GDScript writes one backslash inside a text

	var checked_count: int = 0 # A counter of compared cells. It protects us from a test that "passes" because it compared nothing
	while not table_file.eof_reached(): # Repeat until the end of the file (EOF = end of file)
		var row: PackedStringArray = table_file.get_csv_line() # One row of the table: cell 0 is the key, cell 1 is English, the other cells are other languages
		if row.size() < 2: # The last line of the file can be empty. Skip it
			continue
		var english_tags: Array[String] = _collect_tags(regex, row[1]) # The tags of the English text. This is our example
		for column in range(2, header.size()): # Go through all other languages. We start from 2 because column 0 is the key and column 1 is English itself
			var language_tags: Array[String] = _collect_tags(regex, row[column]) # The tags of this language
			checked_count += 1 # One more cell compared

			# Check 2: the tags of this language are the same as in English (same tags, same order). Two lists are compared by their content
			assert_eq(language_tags, english_tags, "Key " + row[0] + " has different format tags in language " + header[column] + " than in English") # The message names the key and the language, so you see right away where to look

	# Check 3: we really compared some cells. If the table was empty, the loops above would check nothing and the test would still be green
	assert_gt(checked_count, 0, "No translations were compared") # assert_gt (greater than): at least one cell must be compared


# Helper function (not a test: the name does not start with test_, so GUT does not run it by itself).
# Finds all format tags in one text and gives them back as a list, in the order they appear.
func _collect_tags(regex: RegEx, text: String) -> Array[String]: # Gets the search tool and a text, gives back a list of tags
	var tags: Array[String] = [] # An empty list for the tags we find
	for found in regex.search_all(text): # Find every place in the text that fits the pattern. "found" is one such place
		tags.append(found.get_string()) # get_string() without a number gives the whole found piece, with the brackets, like [font_size=35]
	return tags # Give the list back to whoever called the function
