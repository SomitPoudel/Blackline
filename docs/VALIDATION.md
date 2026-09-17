# Validation and build status

Engine: Godot 4.4.1 Standard, official Linux x86_64 build.
Renderer: Compatibility / OpenGL 4.5, Mesa software rendering in an X11 virtual display.

## Completed

- Imported all game scripts and assets with the Godot editor in headless mode.
- Started the main scene in the actual Godot runtime.
- Passed **873 automated engine assertions**, including reachability of every civilian, suspect and evidence position in all 50 generated missions; correct populations; closed/open door visibility; retained enemy alertness; bounded jammer range; ammunition consumption; field treatment; queued commands; snapshot serialisation; and objective-gated extraction.
- Passed a separate **actual save/reload integration test**, including persistent alert state, destroyed light fixtures, radio messages, jammer battery drain and movement after resuming.
- Fixed the integer/float conversion issue found by that integration test; IDs and integer fields retain their types in operation snapshots.
- Rendered and visually inspected the headquarters, campaign board, armoury, deployment screen and a full-environment inspection view using the real game renderer.
- Exported an ARM64 Android debug APK with the official Android template, then checked APK alignment and signature verification.

## Reproduce engine tests

Run from the project directory with Godot 4.4.1 on your PATH:

```text
godot --headless --editor --import --quit
godot --headless --path . --script res://tests/test_operation.gd
godot --headless --path . --script res://tests/test_resume.gd
```

Tests use the application user-data save location. Run them in a development environment; the resume test creates and then deletes its test operation snapshot.

For screenshots, run without `--headless`:

```text
godot --path . --script res://tests/capture.gd
```

## Not verified

- Installation and gameplay on a physical Android phone or Android emulator.
- Sustained phone frame rate, thermals, battery consumption or GPU-specific rendering.
- Physical-device touch gestures and Android interruption scenarios.
- Human playthroughs or balance tuning of every mission.
- Acoustic or ballistic accuracy against real-world weapon measurements.

The screenshots are desktop renders. The full-environment cutaway intentionally reveals the building for visual inspection; it is not normal gameplay visibility. Audio was generated and imported successfully, but this environment had no physical audio output device for listening checks.
