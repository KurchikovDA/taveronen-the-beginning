# Taveronen: The Beginning

[![GUT tests](https://github.com/KurchikovDA/taveronen-the-beginning/actions/workflows/tests.yml/badge.svg)](https://github.com/KurchikovDA/taveronen-the-beginning/actions/workflows/tests.yml)

A small tavern game made in Godot 4, released on itch.io in 7 languages, with a suite of automated tests written in GUT (Godot Unit Test).

This repository is part of my QA portfolio: it shows a finished game and the automated tests I wrote for it.

- Play it in the browser or download it for Windows: https://voljulan.itch.io/taveronen-the-beginning
- Trailer: https://youtu.be/woRWkePzKOY
- Latest test report (Allure): https://kurchikovda.github.io/taveronen-the-beginning/

## About the game

Gold slowly flows into the tavern. You spend it in the shop on furniture (7 items in total), the tavern fills up, and you can click the items to collect bonus coins. When everything is bought, a victory screen appears. The game has a settings screen with music and effects volume, a language switcher and a save system.

Languages: English, Russian, Ukrainian, Spanish, German, French, Simplified Chinese. The game uses two custom pixel fonts (Taveronen Start for the European languages and Taveronen Hanzi for Chinese).

## Automated tests

All tests are in the `test/` folder. Current result: 18 test scripts, 63 tests, 1541 asserts, all passing.

| Area | Folder | What is checked |
|---|---|---|
| Game logic | `test/unit/game_manager/` | gold (add and spend, signals), income ticks, click bonuses, the gold milestone, saving and loading the progress |
| Shop | `test/unit/shop/` | shop data: item count, prices, required fields, unique ids |
| Localization | `test/unit/localization/` | the translation table (all keys, all 7 languages, no empty cells), formatting tags, translation keys used in the code, language lists, and that both fonts have a glyph for every character used in the table |
| Audio | `test/unit/audio/` | every music track loops, the music and sound effect players use the right volume bus (Music and SFX), the main menu music starts by itself |
| Integration | `test/integration/` | the real scenes: the New Game confirmation window in the main menu, switching the language in settings, buying an item in the tavern shop (by signal and by a real mouse click), the whole ending (victory screen, "Keep Playing", the gold-milestone easter egg, "Return to Main Menu") together with its music, and the music and sound effects volume sliders |

What I used and learned while writing them: parameterized tests, doubles, stubs and spies, signal and call assertions, awaiting frames in scene tests, real mouse input with GUT's input sender, stubbing a scene change so a button can be tested, checking audio buses without listening, and cleaning up after each test.

### How the tests are made safe

The integration tests use the real `GameManager` of the game, so each test redirects the save path to a separate test file and puts every changed value back afterwards (gold, items, language, volumes, the volume of the audio buses, the engine language and the theme font) and stops the music it started. Your real save is never touched.

### A bug found by a test

A test that loads a save file with `language_index = 99` failed: the game took the number from the file without checking it, and the settings screen then looked for a language code outside the list of 7 languages. The fix keeps the number in the valid range, and the test now guards it.

### How to run the tests

1. Open the project in Godot 4.7 (Project Manager, Import, choose `project.godot`).
2. Make sure the GUT plugin is enabled (Project, Project Settings, Plugins). A GUT panel appears at the bottom of the editor.
3. In the GUT panel press "Run All". The settings are read from `.gutconfig.json`. If the panel shows no tests, check that the test directory is `res://test` and "Include Subdirs" is turned on.

The same tests also run automatically on GitHub on every push (see the badge at the top and the Actions tab).

### Test report

Every run on the `main` branch saves the results as a JUnit XML file and builds an Allure report from it (Allure is a report tool that shows the tests grouped by file with their status). The report is published at https://kurchikovda.github.io/taveronen-the-beginning/ and shows the latest run, including failures if there are any.

## Known limitations

- The save file is checked only partly: the top level of the JSON and the language number are validated, but the types and ranges of the other values are not.
- Real mouse input is tested for one button only (buying the fireplace in the shop). The other buttons are pressed through their signals, and the "Yes" button of the New Game window is not tested because it changes the scene.
- There is no line-coverage report: there is no mature coverage tool for GDScript, so the tests are planned by risk (the economy, saving, translations, the ending) and not by a percent of code.
- The Ukrainian, German, French and Chinese translations are AI-assisted and have not been reviewed by native speakers yet.
- Gold income is paused while the victory screen or the hidden gold-milestone screen is open. This is a deliberate decision.

## How this was made

I made the game myself in the Godot editor with Claude (an AI assistant) as a mentor: it explained the concepts and provided code, and I assembled everything in the engine. I learned test automation step by step and wrote all the test code by hand, with Claude explaining the concepts and reviewing my work. The music and the graphics were generated by Claude, and the translations were made with AI help.

## License

- Code and tests: MIT License (see `LICENSE`).
- GUT (`addons/gut`): MIT License, see `addons/gut/LICENSE.md`.
- Fonts (`assets/fonts`): SIL Open Font License 1.1. Taveronen Start is based on Press Start 2P (The Press Start 2P Project Authors), Taveronen Hanzi is based on Fusion Pixel 12px (TakWolf). The license texts are next to the font files.
- Music and graphics: AI-generated. They are in this repository only to let the game and the tests run, and no separate license for reusing them is given.

Author: Denis Kurchikov