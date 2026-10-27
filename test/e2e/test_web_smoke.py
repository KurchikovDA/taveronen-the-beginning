# Web smoke test (a quick check that the web build comes alive in a real browser).
# It opens the exported web build in Chromium (a browser controlled by the Playwright library) and checks that the game starts.
# It is NOT a GUT test: GUT only looks for test_*.gd files, and this one is a Python file for pytest.
# Run it from the project folder: python -m pytest test/e2e

import functools # functools = helpers for functions (we use it to tell the web server which folder to show)
import http.server # http.server = a tiny web server that comes with Python
import os # os = access to the environment variables of the computer
import pathlib # pathlib = a handy way to work with file and folder paths
import threading # threading = lets the web server work in the background while the test runs

import pytest # pytest = the test runner (it finds the test_ functions and runs them)

BUILD_DIR = pathlib.Path(os.environ.get("WEB_BUILD_DIR", "dist/web")) # the folder with the exported web build; the default is dist/web (the same folder as in CI = continuous integration), set WEB_BUILD_DIR to use another one
OUTPUT_DIR = pathlib.Path(os.environ.get("E2E_OUTPUT_DIR", "e2e-output")) # the folder for screenshots, it is created by the test and is not part of the game
LOAD_TIMEOUT_MS = 30000 # how long we wait for the game to load, in milliseconds (30 seconds)
SETTLE_MS = 3000 # extra time after the canvas appears, so the main menu is fully drawn (3 seconds)


# Start a web server for the build
## WHAT: starts a small web server that shows the folder with the web build, and gives its address to the tests.
## WHY: a web build cannot be opened by a double click (browsers block it for files), it must come from a web server.
## The scope="session" means: one server for all tests of this run, it stops when the run ends.
@pytest.fixture(scope="session") # a fixture = a helper that pytest prepares before the tests that ask for it by name
def game_url(): # no parameters, it returns the address of the game, for example http://127.0.0.1:50321/index.html
    assert (BUILD_DIR / "index.html").exists(), f"No web build in {BUILD_DIR.resolve()} (set WEB_BUILD_DIR)" # the check: the folder must really contain index.html, otherwise the message says where we looked
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(BUILD_DIR)) # a handler that serves files from the build folder
    handler.log_message = lambda *args: None # keep the server quiet, we do not need a log line for every file
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler) # port 0 = the system picks a free port, 127.0.0.1 = only this computer can connect
    threading.Thread(target=server.serve_forever, daemon=True).start() # run the server in the background (daemon = it does not block the end of the run)
    yield f"http://127.0.0.1:{server.server_address[1]}/index.html" # give the address to the tests; the code after yield runs when all tests are done
    server.shutdown() # stop the server at the end


# Check that the game starts
## WHAT: opens the game, waits until it is drawn, saves a screenshot and checks that the browser console has no errors.
## WHY: only a real browser shows that the web build loads (the wasm file, the pck file, the canvas) and that the game does not crash on start.
## PASSES when: the canvas appears and nothing was written to the console as an error. FAILS when the page does not load or the console has errors.
def test_game_starts_without_errors(page, game_url): # page = a fresh browser tab from pytest-playwright, game_url = the address from the fixture above
    errors = [] # here we collect everything that looks like an error
    page.on("console", lambda msg: errors.append(msg.text) if msg.type == "error" else None) # every console message goes here; we keep only the ones of type "error"
    page.on("pageerror", lambda exc: errors.append(str(exc))) # pageerror = an uncaught error of the page (a crash in JavaScript), we keep it too
    page.goto(game_url) # open the game in the browser tab
    page.wait_for_selector("canvas", timeout=LOAD_TIMEOUT_MS) # wait until the canvas (the drawing area where Godot shows the game) appears on the page
    page.wait_for_timeout(SETTLE_MS) # wait a little more, the canvas exists before the menu is drawn
    OUTPUT_DIR.mkdir(exist_ok=True) # create the screenshot folder if it is not there yet
    page.screenshot(path=str(OUTPUT_DIR / "01_main_menu.png")) # save a picture of the page, you can open it and see what the browser saw
    assert errors == [], f"Console errors: {errors}" # Check 1: the console has no errors; the message shows them if there are any