# BLACKLINE — Tactical Command

An offline, top-down 3D tactical squad game for Android and desktop, built with **Godot 4.4.1 Standard**. This is a playable prototype with an editable source project, not a native Android Studio Java/Kotlin project.

## Play on Android

Install `Blackline-Android.apk` on an **ARM64 Android phone with OpenGL ES 3 support**. Android may ask you to allow installation from the app opening the APK. Use landscape orientation. No account or internet connection is needed after installation.

This is a debug-signed development build for personal testing. It has not been tested on a physical Android phone. The packaged APK's signature, alignment and included resources were checked. Desktop Godot engine tests and actual 3D rendering were checked separately.

## Edit and run

1. Download **Godot 4.4.1 Standard** from https://godotengine.org/download/archive/4.4.1-stable/ . No .NET version is needed.
2. Extract the source ZIP.
3. In Godot's Project Manager, click **Import**, select `Blackline/project.godot`, then **Import & Edit**.
4. Wait for asset import, then press **F6** for the open scene or **F5** for the game.
5. Choose **Operations → Deploy squad**. The operation begins paused.

Android Studio is useful for installing the Android SDK. The game itself is edited in Godot because this project uses Godot's 3D renderer, lighting, input and Android runtime.

## Controls

| Action | Touch / mouse |
|---|---|
| Select officer | Tap their squad card or visible model; desktop keys 1–4 also work |
| Move | Select MOVE and tap a walkable floor location |
| Add waypoints | Enable Queue waypoints; desktop Shift also queues |
| Command everyone | Toggle ALL; the footer shows SINGLE or ALL |
| Execute / pause | GO / PAUSE; desktop Space |
| Change facing | Select FACE and tap the direction to watch |
| Open door / toggle fixture | INTERACT close to it; doors also open when following a route |
| Request surrender | HOLD FIRE, then INTERACT on a nearby visible suspect |
| Secure suspect | INTERACT again within close range after surrender |
| Destroy a fixture | SHOOT LIGHT, then tap a visible fixture; paused shots queue for GO |
| Reload | RELOAD; empty weapons also reload automatically |
| Use equipment | JAMMER or HEAL for the selected officer, when equipped |
| Zoom | + / −, mouse wheel, or two-finger pinch |
| Pan | Arrow controls or right-mouse drag |
| Save | SAVE & HQ; active operations also autosave periodically |

Civilians follow a nearby living officer. Return them to the green deployment strip. Stand close to a gold evidence case to collect it. Once all civilians and evidence are secured, return all surviving officers to the green zone and press EXTRACT. A civilian death fails the mission. An officer loss reduces your reward; the mission can continue with survivors.

## Included systems

- Four independently controlled officers with pause, queued routes, group orders and facing controls.
- Original 3D cutaway rooms, furniture, modelled characters and weapons, tile materials, dynamic interior lights, flashlights, shadows and muzzle traces.
- Current line of sight, light-sensitive detection, fog of war, dim remembered areas, floor-plan outlines and stale contact markers.
- Individually breakable and switchable light fixtures. Broken fixtures remain broken. Gunshots and glass impacts create separate sound events.
- Weighted sound propagation through the floor plan, with attenuation from walls and closed doors. Suppressed and unsuppressed weapons have distinct sound and hearing values.
- Suspect investigation, searching, persistent high alert, last-known positions, recognition delay, surrender, arrests and delayed radio reports.
- A six-game-unit jammer field, 90-second battery, blocked outgoing/incoming radio reports, nearby verbal fallback and restricted shared visibility for the squad.
- Five firearm types: pistol, SMG, shotgun, carbine and suppressed SMG. Magazine capacity, reserve ammunition, firing intervals, spread, individual shotgun pellets, per-shell shotgun reload, weight and armour are simulated.
- Protective vest, low-light goggles, thermal highlights, jammer, medkit and utility knife. The knife speeds evidence collection; it is not a melee assassination mechanic.
- Credits, reputation-based equipment access, per-officer loadouts and gradual experience-based reaction improvement. Gear purchases unlock access for the squad; each officer equips one weapon and up to three tools.
- Fifty seeded missions across five chapters, using variations of a six-room floor plan. Later missions increase suspect counts, civilian objectives, darkness and enemy coordination. Enemies do not gain extra health simply because the mission number rises.
- Persistent career and mid-operation saves, including injuries, ammunition, doors, damaged lights, enemy alert memory, queued actions and radio reports.

## Prototype boundaries

The graphics are original stylised 3D prototype art. The seven positional audio samples are original procedural effects, **not recordings of real weapons**. Weapon figures are fictional balance values, not a validated firearm simulation.

The 50 missions are generated variations of one building system, not 50 individually modelled locations. Their core objective is rescue, evidence recovery and extraction. Later level variety and difficulty still need playtesting.

Night vision improves dark-room visibility; thermal equipment adds visible heat highlights. Neither sees through walls. This prototype has no glass-material thermal simulation, electrical circuit network, advanced destructible structures, or ballistic penetration model.

NPCs use explicit states and local observations. They do not have a comprehensive human behaviour model: for example, civilian fear is simplified, squad body avoidance is limited, and advanced cover tactics are not implemented. Squad position cards remain available while radio sharing is disrupted.

Automatic aiming is provided for accessible squad command. You can disable automatic engagement with HOLD FIRE. The camera and large controls support touch, but final touch feel, battery use, frame rate and accessibility need testing on actual phones.

## Android export from source

1. Install Godot's **matching 4.4.1 export templates** through Editor → Manage Export Templates.
2. Install JDK 17 and the Android SDK. Android Studio's SDK Manager can install platform-tools and build-tools.
3. In Godot's Editor Settings → Export → Android, set **Java SDK Path** and **Android SDK Path**.
4. Open Project → Export. The **Android** preset is included and targets ARM64.
5. Select Export Project and keep **Export With Debug** enabled for a personal test APK.

The supplied build uses Godot's standard non-Gradle Android template. Godot 4.4.1's template determines its Android SDK targeting; this is not a Play Store publication setup. Store publication would require a separately configured, signed release and compliance with the store's current requirements.

Official guide: https://docs.godotengine.org/en/4.4/tutorials/export/exporting_for_android.html

## Source layout

| File | Responsibility |
|---|---|
| `scripts/main.gd` | Menus, HUD, touch/mouse commands, mission flow |
| `scripts/simulation.gd` | Navigation, combat, perception, sound, AI, radio, save snapshots |
| `scripts/world_view.gd` | 3D geometry, lighting, fog, effects and positional audio |
| `scripts/catalog.gd` | Weapon and equipment balance values |
| `scripts/profile.gd` | Credits, reputation, loadouts and campaign progression |
| `data/missions.json` | All 50 mission definitions and seeds |
| `tests/test_operation.gd` | Campaign reachability and mechanics checks |
| `tests/test_resume.gd` | Real snapshot save/reload and resumed simulation checks |
| `tests/capture.gd` | Desktop-render screenshots for visual review |

Local save files are stored in Godot's application user-data directory as `career.json` and `operation.json`. They are not embedded in the APK. Uninstalling or clearing app data can remove them.

## Verification

See `docs/VALIDATION.md` for the actual checks completed and their limits. Images in `previews/` are real desktop Godot renders. The image named **environment-cutaway** deliberately disables fog for architectural inspection; normal gameplay keeps concealed characters hidden.

## Asset ownership

Project source, mesh construction, shaders, icon and generated sound effects were created for this game. Godot's runtime is distributed under the MIT licence; see https://godotengine.org/license/ . No Door Kickers code, models, maps, audio or branding is used.
