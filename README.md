# Taveronen: The Beginning

[![Tests](https://github.com/KurchikovDA/taveronen-the-beginning/actions/workflows/tests.yml/badge.svg)](https://github.com/KurchikovDA/taveronen-the-beginning/actions/workflows/tests.yml)

A small tavern game made in Godot 4, released on itch.io in 7 languages, with automated tests (GUT unit and integration tests, a smoke test of the scene changes, a browser test of the web build and a start check of the Windows .exe) and a CI/CD (continuous integration and delivery) pipeline on GitHub Actions.

This repository is part of my QA portfolio: it shows a finished game, the automated tests I wrote for it and the pipeline that tests, builds and publishes it.

- Play it in the browser or download it for Windows: https://voljulan.itch.io/taveronen-the-beginning
- Trailer: https://youtu.be/woRWkePzKOY
- Latest test report (Allure): https://kurchikovda.github.io/taveronen-the-beginning/

## About the game

Gold slowly flows into the tavern. You spend it in the shop on furniture (7 items in total), the tavern fills up, and you can click the items to collect bonus coins. When everything is bought, a victory screen appears. The game has a settings screen with music and effects volume, a language switcher and a save system. The game version is shown in small text in the bottom-right corner of the main menu.

Languages: English, Russian, Ukrainian, Spanish, German, French, Simplified Chinese. The game uses two custom pixel fonts (Taveronen Start for the European languages and Taveronen Hanzi for Chinese).

## Automated tests

All tests are in the `test/` folder. Current result of the GUT tests: 19 test scripts, 64 tests, 1544 asserts, all passing.

| Area | Folder | What is checked |
|---|---|---|
| Game logic | `test/unit/game_manager/` | gold (add and spend, signals), income ticks, click bonuses, the gold milestone, saving and loading the progress |
| Shop | `test/unit/shop/` | shop data: item count, prices, required fields, unique ids |
| Localization | `test/unit/localization/` | the translation table (all keys, all 7 languages, no empty cells), formatting tags, translation keys used in the code, language lists, and that both fonts have a glyph for every character used in the table |
| Audio | `test/unit/audio/` | every music track loops, the music and sound effect players use the right volume bus (Music and SFX), the main menu music starts by itself |
| Integration | `test/integration/` | the real scenes: the New Game confirmation window in the main menu, switching the language in settings, buying an item in the tavern shop (by signal and by a real mouse click), the whole ending (victory screen, "Keep Playing", the gold-milestone easter egg, "Return to Main Menu") together with its music, the music and sound effects volume sliders, and the game version label in the main menu (it must show the version from the project settings) |
| Smoke test | `test/smoke/` | a script that starts the game without a window, presses the buttons that change the scene (New Game with and without a save, Continue in the intro and in the main menu, Main Menu in the pause menu, Return to Menu on the victory screen, "Yes" in the New Game confirmation) and checks that the right scene opens; it is not a GUT test, it ends with an exit code (0 = all checks passed) |
| Browser test | `test/e2e/` | a Python test (pytest and Playwright) that opens the exported web build in Chromium, checks that the browser console has no errors, clicks New Game and Continue and checks that the screen really changed by comparing screenshots (e2e = end to end) |
| Windows build check | `test/ci/` | a PowerShell script that runs the exported Windows `.exe` without a window for a limited number of frames and checks that the game started, loaded the main menu and wrote no errors to its log; it runs only in the release pipeline, on a real Windows server |

What I used and learned while writing them: parameterized tests, doubles, stubs and spies, signal and call assertions, awaiting frames in scene tests, real mouse input with GUT's input sender, stubbing a scene change so a button can be tested, checking audio buses without listening, and cleaning up after each test.

### How the tests are made safe

The integration tests use the real `GameManager` of the game, so each test redirects the save path to a separate test file and puts every changed value back afterwards (gold, items, language, volumes, the volume of the audio buses, the engine language and the theme font) and stops the music it started. Your real save is never touched.

### A bug found by a test

A test that loads a save file with `language_index = 99` failed: the game took the number from the file without checking it, and the settings screen then looked for a language code outside the list of 7 languages. The fix keeps the number in the valid range, and the test now guards it.

### How to run the tests

1. Open the project in Godot 4.7 (Project Manager, Import, choose `project.godot`).
2. Make sure the GUT plugin is enabled (Project, Project Settings, Plugins). A GUT panel appears at the bottom of the editor.
3. In the GUT panel press "Run All". The settings are read from `.gutconfig.json`. If the panel shows no tests, check that the test directory is `res://test` and "Include Subdirs" is turned on.

The GUT tests and the smoke test also run automatically on GitHub on every push (see the badge at the top and the Actions tab). The browser test and the Windows build check run in the release pipeline. The whole pipeline is described in the CI/CD section below.

To run the smoke test, start Godot from the command line in the project folder (`godot` means the Godot executable):

```
godot --headless --path . -s res://test/smoke/smoke_scene_changes.gd
```

It prints one line per check, and the exit code is 0 when everything passed. At the end Godot may print warnings about leaked resources, because the music is still playing when the script quits. They are harmless and do not change the result.

To run the browser test you need Python 3 and an exported web build (the folder with `index.html`). From the project folder:

```
pip install -r test/e2e/requirements.txt
python -m playwright install chromium
python -m pytest test/e2e
```

By default the test looks for the build in `dist/web`. To use another folder, set the environment variable `WEB_BUILD_DIR`. The screenshots of the run are saved to `e2e-output/` (it is not committed to git).

### Test report

Every run on the `main` branch saves the results as a JUnit XML file and builds an Allure report from it (Allure is a report tool that shows the tests grouped by file with their status). The report is published at https://kurchikovda.github.io/taveronen-the-beginning/ and shows the latest run, including failures if there are any.

## CI/CD (continuous integration and delivery)

Two GitHub Actions workflows live in `.github/workflows/`:

| Workflow | When it runs | What it does |
|---|---|---|
| `tests.yml` (Tests) | on every push to a branch | runs the GUT tests and the smoke test, builds the Allure report (it is published only from `main`) |
| `release.yml` (Build and release) | when a version tag like `v1.0.7` is pushed, or by hand with the "Run workflow" button | runs four jobs one after another: `test` (calls `tests.yml`), `build` (exports the Windows and Web builds with Godot in headless mode, runs the browser test on the web build, saves the builds and the screenshots as downloadable artifacts), `windows-check` (takes the Windows build on a Windows server and starts the `.exe`, see below) and `publish` (uploads both builds to itch.io with butler, the itch.io upload tool) |

If the tests fail, the build does not start. If the browser test or the Windows check fails, nothing is uploaded, because `publish` waits for both `build` and `windows-check`.

The Windows check (`test/ci/check_windows_build.ps1`) runs on a `windows-2025` server. It starts the first `.exe` it finds with `--headless --quit-after 300`, so the game runs without a window for 300 frames, and gives it 60 seconds. The Windows release build has no console, so its output cannot be captured; the script reads the log file that Godot writes itself (`--verbose --log-file`). The check fails if the exit code is not 0, if the log has no line about loading `res://scenes/main_menu.tscn`, or if the log has lines starting with `SCRIPT ERROR`, `USER ERROR`, `ERROR` or `Parse Error`. The harmless message "resources still in use at exit" is ignored. To try it on your own computer, export the Windows build and run in PowerShell: `pwsh ./test/ci/check_windows_build.ps1 -BuildDir <folder with the .exe>`.

Some details:

- The steps that install Godot (and the export templates) are written once, in a reusable action: `.github/actions/setup-godot/action.yml`.
- The versions of the tools are fixed on purpose, so a new version cannot break the pipeline by itself: Godot in the action file, butler, the runner images (`ubuntu-24.04`, `windows-2025`) and the GitHub Actions in the workflow files, the Python packages in `test/e2e/requirements.txt`.
- Dependabot (`.github/dependabot.yml`) checks the versions of the GitHub Actions used in the workflows once a month and opens a pull request when a newer one exists. Because the pull request check runs only `tests.yml`, I first run `release.yml` by hand on the bot's branch (with "publish" off) and merge only when it is green.
- The itch.io key is stored in GitHub Secrets and is never in the repository.
- A manual run of `release.yml` does a safe dry run for itch.io (butler only lists what it would upload) in the `publish` job. The "publish" option turns on a real upload, and only the `main` branch or a version tag can use it.

### Protected main branch

The `main` branch is protected by a repository ruleset: nobody can push to it directly, delete it or force-push to it. Every change goes through a branch and a pull request, and the `Tests` check must be green before the merge.

### How a release is made

1. Create a branch `release-X.Y.Z` and raise the version in three places: the project settings (Application, Config, Version, which is also shown in the main menu) and the Godot export presets (`file_version` and `product_version`). Commit, push and open a pull request.
2. Wait for the green `Tests` check, merge the pull request and pull `main`.
3. Create a tag `vX.Y.Z` with the same number on the top commit of `main` and push it.
4. The pipeline checks that the tag matches the game version (in the export presets and in the project settings), runs the tests, builds, tests the web build, starts the Windows `.exe` on a Windows server and only then uploads both builds to the `windows` and `web` channels of the itch.io page. The itch.io page text, tags and the devlog are still updated by hand.

### Rolling back to a previous version

If a release is broken, run `release.yml` by hand from the tag of the last good version (Actions, Build and release, Run workflow, "Use workflow from" = that tag) with "publish" turned on. The workflow file is taken from the tag, so the old release is rebuilt exactly as it was, and butler sends only the difference to itch.io. Run it first with "publish" off to see what would be uploaded. This works for tags that already contain `release.yml` (`v1.0.5` and newer). Tags older than `v1.0.8` have the older chain without the separate `windows-check` and `publish` jobs, and that is fine: the old release is rebuilt the way it was made. To go forward again, run it from the newest tag the same way.

## Known limitations

- The save file is checked only partly: the top level of the JSON and the language number are validated, but the types and ranges of the other values are not.
- Real mouse input in the GUT tests is used for one button only (buying the fireplace in the shop). The other buttons are pressed through their signals. The buttons that change the scene are checked by the smoke test, which presses them directly.
- There is no line-coverage report: there is no mature coverage tool for GDScript, so the tests are planned by risk (the economy, saving, translations, the ending) and not by a percent of code.
- There is no linter or formatter in the pipeline. I tried gdtoolkit (`gdlint` and `gdformat`) and decided not to add it: passing it would mean rewriting a lot of working code and tests only for style.
- The Ukrainian, German, French and Chinese translations are AI-assisted and have not been reviewed by native speakers yet.
- Gold income is paused while the victory screen or the hidden gold-milestone screen is open. This is a deliberate decision.
- The browser test covers only the path main menu, New Game, intro, Continue, tavern. It clicks by pixel coordinates for a fixed window size, so a change of the menu layout needs new coordinates. A screen counts as changed when more than 20 percent of the pixels differ.
- The Windows build check only proves that the `.exe` starts, loads the main menu and writes no errors in 300 frames. It runs without a window, so it does not see the picture, does not press buttons and does not check sound. Playing the Windows build by hand before a big release is still a good idea.
- The version label test checks the text of the label, not how it looks (position, color and size are checked by eye).
- Builds are uploaded to itch.io by the pipeline, but the itch.io page itself (description, tags, the "played in browser" option) is edited by hand.

## How this was made

I made the game myself in the Godot editor with Claude (an AI assistant) as a mentor: it explained the concepts and provided code, and I assembled everything in the engine. I learned test automation and CI/CD step by step and wrote all the test code and the pipeline files by hand, with Claude explaining the concepts and reviewing my work. The music and the graphics were generated by Claude, and the translations were made with AI help.

## License

- Code and tests: MIT License (see `LICENSE`).
- GUT (`addons/gut`): MIT License, see `addons/gut/LICENSE.md`.
- Fonts (`assets/fonts`): SIL Open Font License 1.1. Taveronen Start is based on Press Start 2P (The Press Start 2P Project Authors), Taveronen Hanzi is based on Fusion Pixel 12px (TakWolf). The license texts are next to the font files.
- Music and graphics: AI-generated. They are in this repository only to let the game and the tests run, and no separate license for reusing them is given.

Author: Denis Kurchikov