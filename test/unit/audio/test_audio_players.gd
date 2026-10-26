extends GutTest # "I am a test file" - GUT (Godot Unit Test) can now find and run me
# Checks the audio of the game without listening to it: every music track loops, and every music and sound effect player sends its sound to the right volume bus.

var game_manager: Node # a fresh copy of GameManager with its music players, declared once so before_each and every test can see it
var menu: Node # the main menu scene (not opened, only loaded) to reach its music player and hover sound
var tavern: Node # the tavern scene (not opened, only loaded) to reach its sound effect players


# Setup before every test
## WHAT: creates a fresh copy of GameManager with its two music players, and loads the main menu scene and the tavern scene.
## WHY: the tests read the players and their settings, and every test needs its own new objects. The copy is not part of the running game, so nothing plays and no save file is touched.
## HOW IT RUNS: GUT calls a function with exactly this name (before_each) automatically before every test in this file. It is not a test, so it has no check inside.
func before_each() -> void: # The name before_each is special, GUT looks for it. It has no test_ at the start on purpose
	game_manager = autofree(load("res://scripts/autoload/game_manager.gd").new()) # a fresh GameManager in memory. autofree asks GUT to delete it after the test
	game_manager._setup_music() # the function that creates tavern_music and victory_music. In the real game it runs when the music is needed first
	menu = autofree(load("res://scenes/main_menu.tscn").instantiate()) # the main menu scene as an object. It is not added to the screen, so its music does not start
	tavern = autofree(load("res://scenes/tavern.tscn").instantiate()) # the tavern scene as an object, also not added to the screen, to reach its sound effect players


# Tracks loop
## WHAT: reads the loop flag of the track of every music player: tavern, victory and main menu.
## WHY: the tavern track lasts 30 minutes, but a player can stay longer, and a track without a loop would end in silence.
## PASSES when: all three tracks have loop turned on. FAILS when any of them stops at its end.
func test_all_music_tracks_loop() -> void: # Name starts with test_ so GUT runs it
	var menu_music: AudioStreamPlayer = menu.get_node("MenuMusic") # the music player of the main menu, found by its name in the scene

	# Check 1: the tavern track repeats after it ends
	assert_true(game_manager.tavern_music.stream.loop, "The tavern music should loop") # stream = the audio file inside the player, loop = true means it starts again at the end
	# Check 2: the victory track repeats after it ends
	assert_true(game_manager.victory_music.stream.loop, "The victory music should loop")
	# Check 3: the main menu track repeats after it ends
	assert_true(menu_music.stream.loop, "The main menu music should loop")


# Music bus
## WHAT: checks that the Music bus exists and that all three music players send their sound to it.
## WHY: the volume slider "Music" changes the bus named Music. A player on another bus (for example Master) would ignore the slider.
## PASSES when: the Music bus exists and tavern, victory and main menu players all use it. FAILS when the bus is missing or any player uses another one.
func test_music_players_use_music_bus() -> void: # Name starts with test_ so GUT runs it
	var menu_music: AudioStreamPlayer = menu.get_node("MenuMusic") # the music player of the main menu, found by its name in the scene

	# Check 1: the bus named Music exists in the project (get_bus_index answers -1 when there is no such bus)
	assert_ne(AudioServer.get_bus_index("Music"), -1, "The project should have a bus named Music")
	# Check 2: the tavern music goes through the Music bus
	assert_eq(game_manager.tavern_music.bus, &"Music", "The tavern music should use the Music bus") # bus = the name of the volume channel the player sends its sound to. &"Music" is a special name type (StringName) written with & before the quotes: it is the same text "Music", but this is the form Godot stores in the bus property, so we compare like with like
	# Check 3: the victory music goes through the Music bus
	assert_eq(game_manager.victory_music.bus, &"Music", "The victory music should use the Music bus") # same as above: the bus name &"Music" must be the name the player really has
	# Check 4: the main menu music goes through the Music bus
	assert_eq(menu_music.bus, &"Music", "The main menu music should use the Music bus") # same check for the main menu player


# SFX bus
## WHAT: checks that the SFX bus exists and that the four sound effect players send their sound to it: menu hover, sign letters, item appearing and coin.
## WHY: the volume slider "Sound effects" changes the bus named SFX. A player on another bus would ignore the slider and stay loud.
## PASSES when: the SFX bus exists and all four players use it. FAILS when the bus is missing or any player uses another one.
func test_sound_effect_players_use_sfx_bus() -> void: # Name starts with test_ so GUT runs it
	var hover_sound: AudioStreamPlayer = menu.get_node("HoverSound") # the sound of the mouse over a menu button
	var letter_sound: AudioStreamPlayer = tavern.get_node("CanvasLayer/TaveronenSign/LetterAppearSound") # the sound of the sign letters appearing
	var item_sound: AudioStreamPlayer = tavern.get_node("ItemAppearSound") # the sound of a bought item appearing
	var coin_sound: AudioStreamPlayer = tavern.get_node("CoinSound") # the sound of collecting a coin bonus

	# Check 1: the bus named SFX exists in the project (get_bus_index answers -1 when there is no such bus)
	assert_ne(AudioServer.get_bus_index("SFX"), -1, "The project should have a bus named SFX")
	# Check 2: the menu hover sound goes through the SFX bus
	assert_eq(hover_sound.bus, &"SFX", "The menu hover sound should use the SFX bus") # SFX = sound effects. The bus named SFX is the channel the "Sound effects" slider controls. &"SFX" is the name as a StringName (see the Music test above)
	# Check 3: the sign letter sound goes through the SFX bus
	assert_eq(letter_sound.bus, &"SFX", "The sign letter sound should use the SFX bus") # the player must send its sound to the SFX channel
	# Check 4: the item appearing sound goes through the SFX bus
	assert_eq(item_sound.bus, &"SFX", "The item appearing sound should use the SFX bus") # the player must send its sound to the SFX channel
	# Check 5: the coin sound goes through the SFX bus
	assert_eq(coin_sound.bus, &"SFX", "The coin sound should use the SFX bus") # the player must send its sound to the SFX channel


# Main menu music
## WHAT: reads two settings of the main menu music player: whether it starts by itself and which audio file it plays.
## WHY: the menu has no code that starts its music, it relies on the autoplay setting of the player. If autoplay is switched off or the wrong track is chosen, the menu is silent or plays the wrong theme, and no other test would notice.
## PASSES when: autoplay is on and the player plays the menu theme file. FAILS when autoplay is off or another file is set.
func test_main_menu_music_starts_by_itself_and_plays_menu_theme() -> void: # Name starts with test_ so GUT runs it
	var menu_music: AudioStreamPlayer = menu.get_node("MenuMusic") # the music player of the main menu, found by its name in the scene

	# Check 1: the menu music starts by itself when the menu opens
	assert_true(menu_music.autoplay, "The main menu music should start by itself (autoplay)") # autoplay = true means the player starts as soon as the scene opens
	# Check 2: the player plays the menu theme file, not another track
	assert_eq(menu_music.stream.resource_path, "res://assets/audio/menu_theme_5min.ogg", "The main menu should play the menu theme") # resource_path = the path of the audio file that was loaded into the player
