extends Node

# Emitted whenever the gold amount changes, so UI elements can react to it
signal gold_changed(new_amount: int)

# Emitted each time one of the player's items finishes its current random
# wait and becomes collectable (see item_purchase_progress/item_bonus_threshold
# below) - the tavern scene's click-interaction script listens for this to
# start a subtle "ready to click" pulse on that item's sprite. Unlike the
# gold milestone below, this fires many times over a session: once per
# item, every time that item's cycle completes, not just once ever.
signal bonus_available(item_id: String)

# Emitted once, the very first time total gold reaches GOLD_MILESTONE_AMOUNT -
# the tavern's shop panel listens for this to show the hidden "Legend of
# Gold" easter-egg screen.
signal gold_milestone_reached

# Current amount of gold the player has
var gold: int = 0

# How much gold is automatically added per tick (per second)
var gold_per_second: int = 1

# Passive income and the click-bonus timers only run while the player is
# actually in the tavern: the tavern scene must be open (its pause menu
# being shown on top is fine), and neither the victory screen nor the
# "Legend of Gold" easter-egg screen may be up. Nothing ticks on the
# Main Menu or during the intro story. See _is_income_active below.
const TAVERN_SCENE_PATH: String = "res://scenes/tavern.tscn"

# Engine time (Time.get_ticks_msec) up to which passive income has
# already been paid out. In a browser the whole game loop stops while
# the tab is minimized or in the background (the browser simply stops
# giving the page new frames), so the 1-second timer below stops firing
# too, even though the music keeps playing. The engine clock itself keeps
# running, so on the first tick after the player comes back, _on_tick
# pays out every whole second that passed while the tab was hidden.
# On desktop this changes nothing - there each tick is still 1 second.
var _last_tick_msec: int = 0

# Whether passive income is counted by the real clock (above) or simply
# as one second per timer tick. Exported builds (desktop and web) use the
# real clock, so a minimized browser tab is paid out later. Runs from the
# Godot editor count ticks instead: the editor's game speed control speeds
# up the timer but not the real clock, so only tick counting lets gold
# speed up together with the rest of the game while testing.
# This has to be a var, not a const - OS.has_feature() is a runtime check.
# Being a var also lets autotests switch between the two modes.
var count_income_by_real_clock: bool = not OS.has_feature("editor")

# IDs of items the player has already bought (persisted between sessions)
var purchased_items: Array[String] = []

# Index into settings_panel.gd's LANGUAGE_KEYS/LOCALE_CODES arrays for the
# currently selected language. Lives here (not on the Settings panel
# itself) because this autoload survives scene changes, while the
# Settings panel gets recreated every time main_menu.tscn loads - so
# keeping it there would reset the language back to English every time
# the player returns to the main menu. Now also saved to disk (see
# save_game/load_game below), so it survives full game restarts too.
var language_index: int = 0

# How many languages the game has (positions 0-6 in settings_panel.gd: en, ru, uk, es, de, fr, zh_CN).
# load_game uses it to throw away a language number that does not exist. Change it when a new language is added.
const LANGUAGE_COUNT: int = 7

# Music/SFX volume, in the same 0-100 range the settings sliders use
# (not raw decibels) - kept here for the same reason as language_index
# above: this autoload survives scene changes and full restarts, while
# the Settings panel itself gets recreated every time it's opened.
# Applied to the actual audio buses in _ready() below (via
# apply_audio_settings), and saved/loaded alongside everything else.
var music_volume: float = 100.0
var sfx_volume: float = 100.0

# Whether the player has ever actually entered the tavern (see
# mark_game_started, called from ShopPanel.gd's _ready()). This is
# separate from "does save.json exist on disk" - this autoload's own
# timers below autosave every 10 seconds from the moment the app
# launches, so a save file can appear just from sitting on the Main
# Menu, before any real game has been played. The Main Menu's Continue
# button checks this flag (via has_save()) instead, so it only lights
# up once there's an actual game to continue.
var game_started: bool = false

# For each purchased item: how many seconds it has accumulated towards
# its CURRENT click-bonus cycle (see item_bonus_threshold below). Only
# counted while income is active (incremented from the same
# once-a-second _on_tick that already drives the passive gold income
# below) - closing the game or sitting on the Main Menu does not keep
# this timer running in the background. (A minimized browser tab with
# the tavern open does count - see _last_tick_msec.)
var item_purchase_progress: Dictionary = {}

# For each purchased item: how many seconds its CURRENT cycle needs
# before it becomes collectable - a fresh random value between
# BONUS_MIN_WAIT_SECONDS and BONUS_MAX_WAIT_SECONDS, picked when the
# item is first purchased and again every time its bonus is collected.
# Keeping this per-item (instead of one shared value) means every item
# repeats forever, independently, and a given item's next wait never
# starts until its previous coin was actually clicked and collected.
var item_bonus_threshold: Dictionary = {}

# Range for how long (in actual running seconds) a purchased item waits
# before its click bonus becomes collectable again.
const BONUS_MIN_WAIT_SECONDS: int = 60
const BONUS_MAX_WAIT_SECONDS: int = 300

# Each collectable bonus pays out a random amount in this range.
const BONUS_MIN_GOLD: int = 1
const BONUS_MAX_GOLD: int = 5

# Gold total that unlocks the hidden "Legend of Gold" easter-egg screen -
# reachable only by continuing to play well past full completion.
const GOLD_MILESTONE_AMOUNT: int = 10000

# Whether the gold milestone screen has already been triggered once -
# it's a one-time easter egg, never shown again after the first time.
var gold_milestone_seen: bool = false

# Whether the player has already moved past the normal victory screen,
# through either of its buttons ("Keep Playing" or "Return to Main Menu" -
# see continue_playing_button.gd and return_to_menu_button.gd). The
# victory screen (see ShopPanel._check_for_victory) only ever appears
# after every item has been purchased, so this flag being true proves the
# tavern is fully furnished, and it also makes sure the victory screen is
# shown only once. It is the gate for the gold-milestone easter egg below -
# without it, passive income alone (gold_per_second, unaffected by
# purchases) would reach GOLD_MILESTONE_AMOUNT on its own, even if the
# player never bought a single item.
var victory_continued: bool = false

# Where the save file lives on disk. Runs from the Godot editor and the
# exported game share the same user:// folder on this computer, so
# without this split an exported build would load (and keep
# overwriting) whatever progress was last played in the editor. The
# editor keeps using save.json, so development progress stays exactly
# as it is; exported builds get their own save_release.json, so a fresh
# export always starts clean. Players never see the file name.
# This has to be a var, not a const - OS.has_feature() is a runtime
# check, and a const only accepts values known before the game runs.
var SAVE_PATH: String = "user://save.json" if OS.has_feature("editor") else "user://save_release.json"

# Persistent music players - live here (not in a scene) so playback
# survives scene changes (intro -> tavern -> victory -> menu, etc.)
var tavern_music: AudioStreamPlayer
var victory_music: AudioStreamPlayer

func _ready() -> void:
	# Load any existing save before anything else starts ticking,
	# so the shop can check purchased_items in its own _ready(), and
	# settings_panel.gd picks up the saved language_index in its own
	# _ready() right after this.
	load_game()

	# Start counting income time from the moment the game launches.
	_last_tick_msec = Time.get_ticks_msec()

	# Apply the saved (or default) volume to the actual audio buses right
	# away, so music that starts playing before the player ever opens the
	# Settings panel (e.g. the intro/tavern theme) already respects it.
	apply_audio_settings()

	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_on_tick)
	add_child(timer)

	# Autosave every 10 seconds, so progress isn't lost if the game
	# is closed without a fresh purchase happening right before.
	var autosave_timer := Timer.new()
	autosave_timer.wait_time = 10.0
	autosave_timer.autostart = true
	autosave_timer.timeout.connect(save_game)
	add_child(autosave_timer)

	_setup_music()

func _on_tick() -> void:
	var now: int = Time.get_ticks_msec()
	# This timer lives on an autoload, so it keeps firing in every scene -
	# skip the whole tick (gold and click-bonus progress) whenever the
	# player isn't actually playing in the tavern right now. The clock is
	# moved forward too, so time spent outside the tavern (Main Menu,
	# intro, victory screen) is never paid out later.
	if not _is_income_active():
		_last_tick_msec = now
		return
	var seconds: int = 1 # Editor run: one timer tick is one second of game time
	if count_income_by_real_clock:
		# Whole seconds since the last payout: normally 1, but more right
		# after a browser tab was minimized or in the background (see
		# _last_tick_msec above). Rounding plus advancing the clock by exactly
		# the seconds paid keeps the long-run total equal to real time.
		seconds = roundi(float(now - _last_tick_msec) / 1000.0)
		if seconds <= 0:
			return
		_last_tick_msec += seconds * 1000
	else:
		_last_tick_msec = now # Keep the real clock up to date anyway, in case the mode is switched
	add_gold(gold_per_second * seconds)
	# Click-bonus timers catch up by the same number of seconds. They stop
	# counting once an item's coin is ready, so after BONUS_MAX_WAIT_SECONDS
	# every item is waiting anyway - no need to loop any further than that.
	for i in mini(seconds, BONUS_MAX_WAIT_SECONDS):
		_tick_bonus_progress()

# Whether gold and click-bonus timers should advance right now: the
# tavern scene is the one on screen, and neither of its full-screen
# overlays (the victory screen or the "Legend of Gold" easter-egg
# screen) is showing. The pause menu does not count as an overlay here,
# so income keeps running while it is open. current_scene can briefly be
# null while change_scene_to_file() swaps scenes, which simply counts as
# "not active" for that one tick. The two panels are unique-named nodes
# in tavern.tscn, looked up by name the same way escape_menu.gd does.
func _is_income_active() -> bool:
	var scene: Node = get_tree().current_scene
	if scene == null or scene.scene_file_path != TAVERN_SCENE_PATH:
		return false
	for panel_name in ["%VictoryPanel", "%GoldMilestonePanel"]:
		var panel := scene.get_node_or_null(panel_name) as CanvasItem
		if panel != null and panel.visible:
			return false
	return true

# Advances the click-bonus timer for every purchased item that isn't
# already waiting to be clicked, by one second. Only ever called from
# _on_tick above, so this only counts seconds while income is active -
# exactly like the passive gold income (including the seconds caught up
# after a browser tab was in the background).
func _tick_bonus_progress() -> void:
	for item_id in purchased_items:
		var threshold: int = item_bonus_threshold.get(item_id, BONUS_MAX_WAIT_SECONDS)
		var progress: int = item_purchase_progress.get(item_id, 0)
		if progress >= threshold:
			# Already collectable and waiting on the player to click it -
			# don't keep counting (and don't re-emit) until they do.
			continue
		progress += 1
		item_purchase_progress[item_id] = progress
		if progress >= threshold:
			bonus_available.emit(item_id)

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)
	_check_gold_milestone()

# Fires the one-time "Legend of Gold" easter egg the moment total gold
# first reaches GOLD_MILESTONE_AMOUNT - but only once the player has
# actually earned it (see victory_continued above). Safe to call as
# often as we like - it only ever actually triggers once per save.
func _check_gold_milestone() -> void:
	if gold_milestone_seen:
		return
	if not victory_continued:
		return
	if gold >= GOLD_MILESTONE_AMOUNT:
		gold_milestone_seen = true
		gold_milestone_reached.emit()
		save_game()

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		gold_changed.emit(gold)
		return true
	return false

# Call this right after a purchase succeeds, so it's remembered next
# time - also starts that item's very first click-bonus cycle with a
# fresh random wait.
func mark_purchased(item_id: String) -> void:
	if not purchased_items.has(item_id):
		purchased_items.append(item_id)
		item_purchase_progress[item_id] = 0
		item_bonus_threshold[item_id] = randi_range(BONUS_MIN_WAIT_SECONDS, BONUS_MAX_WAIT_SECONDS)
		save_game()

# Whether item_id's click bonus can be collected right now: owned, and
# its current random wait is over.
func can_collect_bonus(item_id: String) -> bool:
	if not purchased_items.has(item_id):
		return false
	var threshold: int = item_bonus_threshold.get(item_id, BONUS_MAX_WAIT_SECONDS)
	return item_purchase_progress.get(item_id, 0) >= threshold

# Pays out item_id's current click bonus (a random amount between
# BONUS_MIN_GOLD and BONUS_MAX_GOLD), then immediately starts a fresh
# cycle for it with a new random wait - so the same item keeps paying
# out again and again, indefinitely, for the rest of the session.
# Returns the amount actually granted, or 0 if it wasn't eligible - the
# caller uses that return value to show "+N" in the click popup.
func collect_bonus(item_id: String) -> int:
	if not can_collect_bonus(item_id):
		return 0
	item_purchase_progress[item_id] = 0
	item_bonus_threshold[item_id] = randi_range(BONUS_MIN_WAIT_SECONDS, BONUS_MAX_WAIT_SECONDS)
	var amount: int = randi_range(BONUS_MIN_GOLD, BONUS_MAX_GOLD)
	add_gold(amount)
	save_game()
	return amount

# Call this whenever the player changes language, so it's remembered next time
func save_language() -> void:
	save_game()

# Applies music_volume/sfx_volume (0-100 range) to the actual audio
# buses. Called once at startup (see _ready above, right after
# load_game) and again by the Settings panel every time a slider moves.
func apply_audio_settings() -> void:
	var sfx_bus := AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(sfx_volume / 100.0))
	var music_bus := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(music_bus, linear_to_db(music_volume / 100.0))

# Call this whenever the player drags a volume slider, so it's
# remembered next time (same pattern as save_language above).
func save_audio_settings() -> void:
	save_game()

# Call this once the player actually reaches the tavern (see
# ShopPanel.gd's _ready()) - marks that there is now a real game in
# progress, so the Main Menu's Continue button can light up.
func mark_game_started() -> void:
	if not game_started:
		game_started = true
		save_game()

# Call this the moment the player presses "Keep Playing" on the normal
# victory screen (see continue_playing_button.gd). Re-runs the gold
# milestone check right away, as a safety net in case gold already
# crossed GOLD_MILESTONE_AMOUNT right before the victory screen opened
# (income itself is paused while that screen is up).
func mark_victory_continued() -> void:
	if not victory_continued:
		victory_continued = true
		save_game()
	_check_gold_milestone()

func save_game() -> void:
	var data := {
		"gold": gold,
		"purchased_items": purchased_items,
		"language_index": language_index,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"game_started": game_started,
		"item_purchase_progress": item_purchase_progress,
		"item_bonus_threshold": item_bonus_threshold,
		"gold_milestone_seen": gold_milestone_seen,
		"victory_continued": victory_continued,
	}
	var temp_path: String = SAVE_PATH + ".tmp" # Write to a temporary file first, so a crash in the middle cannot break the real save
	var file := FileAccess.open(temp_path, FileAccess.WRITE) # Open the temporary file for writing
	if file == null: # The file could not be opened (disk full, no rights)
		push_error("Could not write the save file: error " + str(FileAccess.get_open_error())) # Tell the log, so the problem is not silent
		return # Keep the old save as it is and stop here
	file.store_string(JSON.stringify(data)) # Put all the progress into the temporary file
	file.close() # Finish writing
	DirAccess.rename_absolute(temp_path, SAVE_PATH) # Only now replace the real save with the finished file

# Whether there's an actual game to continue - not just whether
# save.json happens to exist on disk (see game_started above for why
# those two aren't the same thing).
func has_save() -> bool:
	return game_started

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary): # The file must hold a table of values. Garbage, an empty file or a file with just a number is ignored
		return

	gold = parsed.get("gold", 0)
	var loaded_items = parsed.get("purchased_items", [])
	purchased_items.clear()
	for id in loaded_items:
		purchased_items.append(str(id))
	language_index = parsed.get("language_index", 0)
	if language_index < 0 or language_index >= LANGUAGE_COUNT: # the number from the file is not a real language position
		language_index = 0 # fall back to English, the default language
	# Old saves (before this feature) won't have these fields - default
	# to full volume, same as a brand new install.
	music_volume = float(parsed.get("music_volume", 100.0))
	sfx_volume = float(parsed.get("sfx_volume", 100.0))
	game_started = parsed.get("game_started", false)

	item_purchase_progress.clear()
	var loaded_progress = parsed.get("item_purchase_progress", {})
	for id in loaded_progress.keys():
		item_purchase_progress[str(id)] = int(loaded_progress[id])

	item_bonus_threshold.clear()
	var loaded_threshold = parsed.get("item_bonus_threshold", {})
	for id in loaded_threshold.keys():
		item_bonus_threshold[str(id)] = int(loaded_threshold[id])
	# Old saves (before this feature) won't have a threshold for items
	# already owned - give each of those a fresh random one instead of
	# defaulting to "always collectable" or crashing.
	for id in purchased_items:
		if not item_bonus_threshold.has(id):
			item_bonus_threshold[id] = randi_range(BONUS_MIN_WAIT_SECONDS, BONUS_MAX_WAIT_SECONDS)

	gold_milestone_seen = parsed.get("gold_milestone_seen", false)
	victory_continued = parsed.get("victory_continued", false)

# Wipes all progress and deletes the save file - used by "New Game".
# Language and volume settings are kept on purpose: they are settings, not progress.
func reset_game() -> void:
	gold = 0
	purchased_items.clear()
	item_purchase_progress.clear()
	item_bonus_threshold.clear()
	gold_milestone_seen = false
	victory_continued = false
	game_started = false # No game in progress until the player reaches the tavern again (ShopPanel calls mark_game_started there)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	save_game()

func _setup_music() -> void:
	tavern_music = AudioStreamPlayer.new()
	tavern_music.stream = load("res://assets/audio/tavern_theme_30min.ogg")
	# Route this player through the Music bus so its volume follows the Music slider
	tavern_music.bus = &"Music"
	# Stream the track instead of letting the browser build preload it as
	# one big sample: in web builds Godot's default playback type hands the
	# whole sound to the browser fully decoded, which for this 30-minute
	# track means roughly 600 MB of memory (slow start, or a crashed tab on
	# weaker machines). Streaming decodes it bit by bit as it plays. On
	# desktop this setting changes nothing - music is always streamed there.
	tavern_music.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(tavern_music)

	victory_music = AudioStreamPlayer.new()
	victory_music.stream = load("res://assets/audio/victory_theme_1min.ogg")
	# Same here, so both tracks respond to the Music slider
	victory_music.bus = &"Music"
	# Streamed for the same reason as the tavern theme above.
	victory_music.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(victory_music)

# Starts the tavern theme if it isn't already playing - call this from the
# intro scene, so the music begins there and simply keeps going into the tavern
func play_tavern_theme() -> void:
	if tavern_music == null:
		_setup_music()
	if not tavern_music.playing:
		tavern_music.play()

func stop_tavern_theme() -> void:
	if tavern_music != null and tavern_music.playing:
		tavern_music.stop()

# Pauses the tavern theme without losing its playback position -
# used when the victory screen appears, so it can resume later
func pause_tavern_theme() -> void:
	if tavern_music != null:
		tavern_music.stream_paused = true

# Resumes the tavern theme from exactly where it was paused
func resume_tavern_theme() -> void:
	if tavern_music != null:
		tavern_music.stream_paused = false

# Pauses the tavern theme (not stop, so it can resume later) and plays
# the victory fanfare instead - call this when the victory screen appears
func play_victory_theme() -> void:
	if victory_music == null:
		_setup_music()
	pause_tavern_theme()
	if not victory_music.playing:
		victory_music.play()

func stop_victory_theme() -> void:
	if victory_music != null and victory_music.playing:
		victory_music.stop()
