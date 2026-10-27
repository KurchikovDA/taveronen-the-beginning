# Web smoke test (a quick check that the web build comes alive in a real browser).
# It opens the exported web build in Chromium (a browser controlled by the Playwright library), clicks the buttons and checks that the screen changes.
# It is NOT a GUT test: GUT only looks for test_*.gd files, and this one is a Python file for pytest.
# Run it from the project folder: python -m pytest test/e2e

import functools # functools = helpers for functions (we use it to tell the web server which folder to show)
import http.server # http.server = a tiny web server that comes with Python
import io # io = lets us treat bytes (the screenshot) like a file for Pillow
import os # os = access to the environment variables of the computer
import pathlib # pathlib = a handy way to work with file and folder paths
import threading # threading = lets the web server work in the background while the test runs

import pytest # pytest = the test runner (it finds the test_ functions and runs them)
from PIL import Image, ImageChops # Pillow = a library for pictures: Image opens a picture, ImageChops compares two pictures

BUILD_DIR = pathlib.Path(os.environ.get("WEB_BUILD_DIR", "dist/web")) # the folder with the exported web build; the default is dist/web (the same folder as in CI = continuous integration), set WEB_BUILD_DIR to use another one
OUTPUT_DIR = pathlib.Path(os.environ.get("E2E_OUTPUT_DIR", "e2e-output")) # the folder for screenshots, it is created by the test and is not part of the game
LOAD_TIMEOUT_MS = 30000 # how long we wait for the game to load, in milliseconds (30 seconds)
SETTLE_MS = 3000 # extra time after the canvas appears, so the main menu is fully drawn (3 seconds)
CLICK_WAIT_MS = 2000 # time after a click, so the new screen is fully drawn (2 seconds)
VIEWPORT = {"width": 1280, "height": 720} # the size of the browser window in pixels; the click coordinates below are for this size
NEW_GAME_BUTTON = (945, 178) # x and y of the New Game button in the main menu (counted from the top left corner of the window)
INTRO_CONTINUE_BUTTON = (640, 613) # x and y of the Continue button on the intro screen
PIXEL_DIFF = 30 # a pixel counts as changed if its brightness differs by more than this (from 0 to 255); it ignores tiny animation noise
MIN_CHANGED = 0.2 # a screen counts as changed if more than 20% of the pixels changed; a calm menu changes only about 0.2% by itself (animation), a new screen changes about 40%


# Set the size of the browser window
## WHAT: tells pytest-playwright to open every browser tab with the same fixed size.
## WHY: we click by coordinates, so the window size must never change between runs.
@pytest.fixture(scope="session") # a fixture = a helper that pytest prepares before the tests that ask for it by name
def browser_context_args(browser_context_args): # the same name as the built-in fixture, so ours replaces it; the parameter is the built-in settings
    return {**browser_context_args, "viewport": VIEWPORT} # take the built-in settings and add our window size to them


# Start a web server for the build
## WHAT: starts a small web server that shows the folder with the web build, and gives its address to the tests.
## WHY: a web build cannot be opened by a double click (browsers block it for files), it must come from a web server.
## The scope="session" means: one server for all tests of this run, it stops when the run ends.
@pytest.fixture(scope="session") # one server for the whole run
def game_url(): # no parameters, it returns the address of the game, for example http://127.0.0.1:50321/index.html
    assert (BUILD_DIR / "index.html").exists(), f"No web build in {BUILD_DIR.resolve()} (set WEB_BUILD_DIR)" # the check: the folder must really contain index.html, otherwise the message says where we looked
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(BUILD_DIR)) # a handler that serves files from the build folder
    handler.log_message = lambda *args: None # keep the server quiet, we do not need a log line for every file
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler) # port 0 = the system picks a free port, 127.0.0.1 = only this computer can connect
    threading.Thread(target=server.serve_forever, daemon=True).start() # run the server in the background (daemon = it does not block the end of the run)
    yield f"http://127.0.0.1:{server.server_address[1]}/index.html" # give the address to the tests; the code after yield runs when all tests are done
    server.shutdown() # stop the server at the end


# Open the game
## WHAT: opens the game in the tab, waits until the main menu is drawn and starts collecting console errors.
## WHY: all tests begin the same way, so the steps live in one place.
## Returns the list of errors; it stays connected to the page, so errors that come later are added to it too.
def open_game(page, game_url): # page = a browser tab, game_url = the address of the game
    errors = [] # here we collect everything that looks like an error
    page.on("console", lambda msg: errors.append(msg.text) if msg.type == "error" else None) # every console message goes here; we keep only the ones of type "error"
    page.on("pageerror", lambda exc: errors.append(str(exc))) # pageerror = an uncaught error of the page (a crash in JavaScript), we keep it too
    page.goto(game_url) # open the game in the browser tab
    page.wait_for_selector("canvas", timeout=LOAD_TIMEOUT_MS) # wait until the canvas (the drawing area where Godot shows the game) appears on the page
    page.wait_for_timeout(SETTLE_MS) # wait a little more, the canvas exists before the menu is drawn
    return errors # give the list back to the test


# Take a screenshot
## WHAT: saves a picture of the page into the output folder and gives the same picture back as bytes.
## WHY: we need the picture twice: for a person to look at it later, and for the comparison.
def take_screenshot(page, name): # page = a browser tab, name = the file name, for example 01_main_menu.png
    OUTPUT_DIR.mkdir(exist_ok=True) # create the screenshot folder if it is not there yet
    return page.screenshot(path=str(OUTPUT_DIR / name)) # save the picture and return it as bytes


# How much of the screen changed
## WHAT: compares two screenshots and returns the share of changed pixels, from 0.0 (the same) to 1.0 (everything changed).
## WHY: the menu and the tavern move by themselves (animation), so "the pictures are not equal" is always true. A big share of changed pixels means a real new screen.
def changed_share(before, after): # before and after = two screenshots as bytes
    gray_before = Image.open(io.BytesIO(before)).convert("L") # open the first picture and make it gray (one number per pixel is enough for us)
    gray_after = Image.open(io.BytesIO(after)).convert("L") # the same for the second picture
    diff = ImageChops.difference(gray_before, gray_after) # a new picture: every pixel is the difference of the two pixels
    histogram = diff.histogram() # a list of 256 numbers: how many pixels have the difference 0, 1, 2, ... 255
    changed = sum(histogram[PIXEL_DIFF + 1:]) # count the pixels whose difference is bigger than PIXEL_DIFF
    return changed / sum(histogram) # the share = changed pixels divided by all pixels


# Check that the game starts
## WHAT: opens the game, saves a screenshot of the main menu and checks that the browser console has no errors.
## WHY: only a real browser shows that the web build loads (the wasm file, the pck file, the canvas) and that the game does not crash on start.
## PASSES when: the canvas appears and nothing was written to the console as an error. FAILS when the page does not load or the console has errors.
def test_game_starts_without_errors(page, game_url): # page = a fresh browser tab from pytest-playwright, game_url = the address from the fixture above
    errors = open_game(page, game_url) # open the game and wait for the main menu
    take_screenshot(page, "01_main_menu.png") # save a picture of the main menu, you can open it and see what the browser saw
    assert errors == [], f"Console errors: {errors}" # Check 1: the console has no errors; the message shows them if there are any


# Check the New Game button
## WHAT: clicks New Game in the main menu and checks that another screen (the intro) appears.
## WHY: the button must really lead somewhere in the web build, not only in the editor.
## PASSES when: more than MIN_CHANGED of the pixels changed after the click and there are no console errors.
def test_new_game_opens_the_intro(page, game_url): # same parameters as in the first test
    errors = open_game(page, game_url) # open the game and wait for the main menu
    before = take_screenshot(page, "02_before_new_game.png") # a picture of the main menu before the click
    page.mouse.click(*NEW_GAME_BUTTON) # click the New Game button (the * unpacks the pair (x, y) into two numbers)
    page.wait_for_timeout(CLICK_WAIT_MS) # wait until the intro is drawn
    after = take_screenshot(page, "03_intro.png") # a picture of the screen after the click
    share = changed_share(before, after) # how much of the screen is different now
    assert share > MIN_CHANGED, f"New Game did not change the screen: only {share:.1%} of pixels changed" # Check 2: the screen changed a lot, so a new screen is shown
    assert errors == [], f"Console errors: {errors}" # Check 3: the console still has no errors after the click


# Check the Continue button of the intro
## WHAT: starts a new game, clicks Continue on the intro screen and checks that the tavern appears.
## WHY: this is the way every new player enters the game, so it must work in the web build.
## PASSES when: more than MIN_CHANGED of the pixels changed after the second click and there are no console errors.
def test_intro_continue_opens_the_tavern(page, game_url): # same parameters as in the first test
    errors = open_game(page, game_url) # open the game and wait for the main menu
    page.mouse.click(*NEW_GAME_BUTTON) # click New Game, the intro opens
    page.wait_for_timeout(CLICK_WAIT_MS) # wait until the intro is drawn
    before = take_screenshot(page, "04_before_continue.png") # a picture of the intro before the click
    page.mouse.click(*INTRO_CONTINUE_BUTTON) # click the Continue button of the intro
    page.wait_for_timeout(CLICK_WAIT_MS) # wait until the tavern is drawn
    after = take_screenshot(page, "05_tavern.png") # a picture of the tavern
    share = changed_share(before, after) # how much of the screen is different now
    assert share > MIN_CHANGED, f"Continue did not change the screen: only {share:.1%} of pixels changed" # Check 4: the screen changed a lot, so a new screen is shown
    assert errors == [], f"Console errors: {errors}" # Check 5: the console still has no errors in the tavern