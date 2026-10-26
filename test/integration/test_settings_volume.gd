extends GutTest # "I am a test file" - GUT (Godot Unit Test) can now find and run me
# Checks the real settings screen: moving a volume slider changes the real audio bus and saves the value.

# Path of the fake save file used ONLY by these tests.
# user:// = the game's user data folder. The real game uses save.json, so we never touch it.
const TEST_SAVE_PATH: String = "user://test_integration_save.json"

var real_save_path: String # the real save path of the running game, put back in after_each
var real_music_volume: float # the real music volume of the game (0-100), put back in after_each
var real_sfx_volume: float # the real sound effects volume of the game (0-100), put back in after_each
var real_music_db: float # the real loudness of the Music bus in decibels (dB), put back in after_each
var real_sfx_db: float # the real loudness of the SFX (sound effects) bus in decibels (dB), put back in after_each
var real_language_index: int # the real language number of the game, put back in after_each
var real_locale: String # the real language of the engine (like "en"), put back in after_each
var real_base_font: Font # the real font of the game theme, put back in after_each


# Setup before every test
## WHAT: remembers the real volumes, buses, language and font, points GameManager to the test save file, and sets both buses to full volume.
## WHY: the settings screen reads the loudness of the buses when it opens and moves the sliders to match. We need a known start (100) so that moving a slider to 40 is a real change, and we must put everything back afterwards, otherwise the real game and the next tests would sound quieter.
## HOW IT RUNS: GUT calls a function with exactly this name (before_each) automatically before every test in this file. It is not a test, so it has no check inside.
func before_each() -> void: # The name before_each is special, GUT looks for it. It has no test_ at the start on purpose
	real_save_path = GameManager.SAVE_PATH # remember the real path first
	real_music_volume = GameManager.music_volume # remember the real music volume
	real_sfx_volume = GameManager.sfx_volume # remember the real sound effects volume
	real_music_db = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) # the Music bus loudness now. get_bus_index finds the bus by its name
	real_sfx_db = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")) # the SFX bus loudness now
	real_language_index = GameManager.language_index # remember the real language number
	real_locale = TranslationServer.get_locale() # the language the engine uses right now
	var theme_font: FontVariation = load("res://assets/game_theme.tres").default_font as FontVariation # the theme font that the settings screen swaps for Chinese
	real_base_font = theme_font.base_font # remember which font file it uses now
	GameManager.SAVE_PATH = TEST_SAVE_PATH # from this line on, every save goes to the test file
	GameManager.language_index = 0 # English: the screen applies the language when it opens, this keeps it the same in every run
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), 0.0) # 0 dB = full volume, so the music slider starts at 100
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), 0.0) # the same for the sound effects slider


# Cleanup after every test
## WHAT: puts the real volumes, buses, language and font back, and deletes the test save file.
## WHY: the next test (and the real game running next to the tests) must hear and see the same game as before.
## HOW IT RUNS: GUT calls a function with exactly this name (after_each) automatically after every test in this file. It is not a test, so it has no check inside.
func after_each() -> void: # The name after_each is special, GUT looks for it. It has no test_ at the start on purpose
	GameManager.music_volume = real_music_volume # put the music volume back
	GameManager.sfx_volume = real_sfx_volume # put the sound effects volume back
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), real_music_db) # put the Music bus loudness back
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), real_sfx_db) # put the SFX bus loudness back
	GameManager.language_index = real_language_index # put the language number back
	TranslationServer.set_locale(real_locale) # put the engine language back
	var theme_font: FontVariation = load("res://assets/game_theme.tres").default_font as FontVariation # the same theme font as in before_each
	theme_font.base_font = real_base_font # put the real font file back
	GameManager.SAVE_PATH = real_save_path # LAST: only now saves go to the real file again
	if FileAccess.file_exists(TEST_SAVE_PATH): # only delete if the test created the file
		DirAccess.remove_absolute(TEST_SAVE_PATH) # remove it from disk


# Music slider
## WHAT: opens the real settings screen, moves the music slider from 100 to 40 and looks at the Music bus, GameManager and the test save file.
## WHY: the volume slider is a setting that the player sees and that must survive a restart. This test checks the whole chain: the slider, the loudness of the bus, the value in GameManager and the saved file.
## PASSES when: the slider starts at 100, the Music bus gets the loudness of 40 percent, GameManager remembers 40 and the test save file has 40. FAILS when any of these does not happen.
func test_music_slider_changes_music_bus_and_saves() -> void: # Name starts with test_ so GUT runs it
	var settings: Node = add_child_autoqfree(load("res://scenes/settings_panel.tscn").instantiate()) # the real settings screen, placed into the test and removed after it
	await wait_process_frames(2) # let the screen finish its _ready (await = wait here, then go on)
	var slider: HSlider = settings.get_node("%MusicVolumeSlider") # % finds a node by its unique name: the music slider (HSlider = horizontal slider)

	# Check 1: the screen shows the real loudness of the bus, so the slider starts at 100 (full volume)
	assert_eq(slider.value, 100.0, "The music slider should start at 100")

	slider.value = 40.0 # move the slider, like a drag of the player. This sends the value_changed signal

	# Check 2: the Music bus got the loudness of 40 percent (we compare with a small allowed difference, the numbers are fractions)
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), linear_to_db(0.4), 0.01, "The Music bus should get the loudness of 40 percent") # linear_to_db turns a share (0.4 = 40 percent) into decibels
	# Check 3: GameManager remembers the new music volume
	assert_eq(GameManager.music_volume, 40.0, "GameManager should remember the music volume 40")

	var file_text: String = FileAccess.get_file_as_string(TEST_SAVE_PATH) # read the whole test save file as text
	var saved: Dictionary = JSON.parse_string(file_text) # turn the JSON (JavaScript Object Notation) text into a dictionary
	# Check 4: the new music volume is written into the save file
	assert_eq(saved.get("music_volume", -1.0), 40.0, "The saved file should have the music volume 40") # get(key, default) gives -1 if the key is missing


# Sound effects slider
## WHAT: opens the real settings screen, moves the sound effects slider from 100 to 40 and looks at the SFX bus, GameManager and the test save file.
## WHY: the same chain as for the music slider, but for the other bus. A mix-up of the two sliders (SFX = sound effects) would not be noticed otherwise.
## PASSES when: the slider starts at 100, the SFX bus gets the loudness of 40 percent, GameManager remembers 40 and the test save file has 40. FAILS when any of these does not happen.
func test_sfx_slider_changes_sfx_bus_and_saves() -> void: # Name starts with test_ so GUT runs it
	var settings: Node = add_child_autoqfree(load("res://scenes/settings_panel.tscn").instantiate()) # the real settings screen, placed into the test and removed after it
	await wait_process_frames(2) # let the screen finish its _ready
	var slider: HSlider = settings.get_node("%SFXVolumeSlider") # the sound effects slider

	# Check 1: the screen shows the real loudness of the bus, so the slider starts at 100 (full volume)
	assert_eq(slider.value, 100.0, "The sound effects slider should start at 100")

	slider.value = 40.0 # move the slider, like a drag of the player

	# Check 2: the SFX bus got the loudness of 40 percent
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")), linear_to_db(0.4), 0.01, "The SFX bus should get the loudness of 40 percent")
	# Check 3: GameManager remembers the new sound effects volume
	assert_eq(GameManager.sfx_volume, 40.0, "GameManager should remember the sound effects volume 40")

	var file_text: String = FileAccess.get_file_as_string(TEST_SAVE_PATH) # read the whole test save file as text
	var saved: Dictionary = JSON.parse_string(file_text) # turn the JSON text into a dictionary
	# Check 4: the new sound effects volume is written into the save file
	assert_eq(saved.get("sfx_volume", -1.0), 40.0, "The saved file should have the sound effects volume 40")
