extends GutTest # "I am a test file" - GUT (Godot Unit Test) can now find and run me
# Checks that every translation key the game uses really exists in the translation table ui.csv.


# Keys used in the game
## WHAT: reads all scene files (.tscn) and script files (.gd) of the game as plain text, finds every translation key written in quotes (like "MENU_QUIT") and checks that each one is a key in ui.csv.
## WHY: if a key in a scene or script is misspelled or was deleted from the table, the player sees the raw key (like MENU_QUITT) on the screen instead of text.
## PASSES when: every key found in the game files is in ui.csv. FAILS when any key is missing, and the message names the key and the file.
func test_all_translation_keys_used_in_game_exist_in_ui_csv() -> void: # Name starts with test_ so GUT runs it
	var table_keys: Dictionary = {} # An empty dictionary. We put every key of ui.csv here, so we can ask it "do you have this key?" quickly
	var table_file: FileAccess = FileAccess.open("res://translations/ui.csv", FileAccess.READ) # Open the translation table for reading
	table_file.get_csv_line() # Read the first line (the header: keys, en, ru, uk, es, de, fr, zh_CN) and throw it away, it is not a key
	while not table_file.eof_reached(): # Repeat until the end of the file (EOF = end of file)
		var row: PackedStringArray = table_file.get_csv_line() # One row of the table: cell 0 is the key, the other cells are texts
		if row.size() < 2: # The last line of the file can be empty. Skip it, it is not a key
			continue
		table_keys[row[0]] = true # Remember this key. The value "true" does not matter, we only need the key to be in the dictionary

	var game_files: Array[String] = [] # A list of file paths we will read
	game_files.append_array(_collect_files("res://scenes", ".tscn")) # Add all scene files (.tscn = text scene) from the scenes folder and all its subfolders
	game_files.append_array(_collect_files("res://scripts", ".gd")) # Add all script files (.gd = GDScript) from the scripts folder and all its subfolders

	var regex: RegEx = RegEx.new() # A tool for searching text by a pattern (RegEx = regular expression)
	regex.compile('"([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)"') # The pattern: a word in quotes made of CAPITAL letters and digits with at least one underscore, like "MENU_QUIT". The brackets around the word let us take it out without the quotes

	var checked_count: int = 0 # A counter of keys we have checked. It protects us from a test that "passes" because it found nothing

	for path in game_files: # Runs the lines below once per file. "path" is the path of the current file
		var text: String = FileAccess.get_file_as_string(path) # Read the whole file as one big text
		for found in regex.search_all(text): # Find every place in the text that fits the pattern. "found" is one such place
			var key: String = found.get_string(1) # Take the word from inside the quotes, for example MENU_QUIT
			checked_count += 1 # One more key checked

			# Check 1: this key is in the table. has() answers true if the dictionary contains the key
			assert_true(table_keys.has(key), "Key " + key + " from " + path + " is not in ui.csv") # The message names the key and the file, so you see right away where to look

	# Check 2: we really found some keys. If the paths were wrong, the loops above would check nothing and the test would still be green
	assert_gt(checked_count, 0, "No translation keys were found in the game files") # assert_gt (greater than): at least one key must be found


# Helper function (not a test: the name does not start with test_, so GUT does not run it by itself).
# Collects the paths of all files with the given ending from a folder and all folders inside it.
func _collect_files(folder: String, extension: String) -> Array[String]: # Gets a folder path and a file ending (like ".gd"), gives back a list of paths
	var result: Array[String] = [] # An empty list for the paths we find

	for file_name in DirAccess.get_files_at(folder): # Go through all files that lie directly in this folder
		if file_name.ends_with(extension): # Keep only files with the ending we need
			result.append(folder + "/" + file_name) # Add the full path: folder, a slash and the file name

	for sub_folder in DirAccess.get_directories_at(folder): # Go through all folders that lie directly in this folder
		result.append_array(_collect_files(folder + "/" + sub_folder, extension)) # The function calls itself for the inner folder and adds what it finds there. This is how we reach files at any depth

	return result # Give the list back to whoever called the function
