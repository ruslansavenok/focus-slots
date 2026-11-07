# Focus Slots

A simple native macOS menu bar app for manually started focus sessions. Set a daily goal and a slot length, start a timer, and hear a short chime when it finishes. No automatic breaks, accounts, or network access.

## Screenshots

| Light appearance | Dark appearance |
| --- | --- |
| <img src="screenshots/timer-light.png" alt="Focus Slots timer in light appearance" width="300"> | <img src="screenshots/timer-dark.png" alt="Focus Slots timer in dark appearance" width="300"> |

Settings includes the daily target, slot length, sound preview and volume, and the running version.

| Settings | History |
| --- | --- |
| <img src="screenshots/settings.png" alt="Focus Slots settings with sound controls and version 1.0.7" width="300"> | <img src="screenshots/history.png" alt="Daily history with dates and completed slots over daily targets" width="300"> |

## How it works

- The menu bar shows today's completed slots, such as **0/4**. While a slot runs, it also shows the remaining time.
- Click the count to open the timer. Press **Start** to begin and close the dropdown; the countdown stays visible in the menu bar. **Stop** discards an unfinished slot.
- A completed slot plays a gentle chime and increases the count. The timer returns to the full slot length, ready for another manual start. You can continue beyond the target, such as **5/4** after five completed slots.
- Defaults are **4 slots of 45 minutes**, with sound volume at **100%**. Settings lets you change these and preview the sound.
- The **History** icon, immediately left of Settings, opens a newest-first list such as **Nov 7 — 3/4**. Each date keeps its own daily target and includes extra slots.
- Settings, progress, and history persist across app restarts and installer updates. The daily count resets at local midnight while its result remains in History.

A running timer includes time spent asleep or while the app is closed. An overdue timer completes on wake or relaunch. Slots that cross midnight count on their finish day; a slot that finished on a previous day is not added to today's count. Changing the slot length affects the next timer. You can continue beyond your daily target.

History begins with the saved day available when upgrading to 1.0.7 and continues from then on. Older versions discarded earlier daily totals, so those cannot be reconstructed. Only dates recorded by the app are listed; days skipped while the app is closed are not filled in.

## Requirements

- macOS 13 or newer to run the app.
- A Mac with Apple's Command Line Tools and Swift 6 or newer to build. Tested with Swift 6.0.3 and the macOS 15.2 SDK.
- No third-party packages or paid Apple developer account are needed for a local build.

Install the Command Line Tools if needed:

```bash
xcode-select --install
```

## Build

Clone the project into a new folder:

```bash
mkdir -p ~/Projects
cd ~/Projects
git clone https://github.com/ruslansavenok/focus-slots.git FocusSlots
cd FocusSlots
```

From the project folder, run:

```bash
bash build.sh
```

The build tests the timer logic, generates the icon and sound, compiles both Intel and Apple Silicon binaries, combines them into a universal app, verifies its ad-hoc signature, and creates a macOS installer.

For version 1.0.7, the outputs are:

- App: `build/Focus Slots.app`
- Installer: `dist/FocusSlots-1.0.7.pkg`

To try the app without installing it:

```bash
open "build/Focus Slots.app"
```

Quit any already-running copy before opening another build. Build files and installers are generated locally and excluded from Git.

## Install or update

1. If Focus Slots (or the previous Time Slots app) is running, click its menu bar count and choose **Quit**.
2. Open the installer and follow the macOS installation prompts:

   ```bash
   open dist/FocusSlots-1.0.7.pkg
   ```

3. Launch **Focus Slots** from Applications or Spotlight:

   ```bash
   open "/Applications/Focus Slots.app"
   ```

4. Look for **0/4** (or your saved progress) in the menu bar. There is no Dock icon. Open Settings to confirm the running version and use **Test sound** to check the chime.

When upgrading from Time Slots, the installer renames the existing app to Focus Slots before replacing it. The app retains the same internal identity and preference keys, so progress and settings carry over.

An update replaces the app while keeping its saved progress, timer, and settings. Reopen it after updating so the new code runs. Version 1.0.4 sets completion sound volume to 100% once on first launch, including upgrades. Later volume adjustments are saved normally. Sound follows your Mac's selected output, volume, and mute setting.

The build uses an ad-hoc app signature. Developer ID signing and Apple notarization for distributing prebuilt apps are not configured; the instructions above build the app locally on your Mac.

To uninstall, quit the app and move **Focus Slots** from Applications to Trash.

## Tests and screenshot generation

After building, run the native integration checks in your Mac's logged-in desktop session:

```bash
bash test-ui.sh
```

These checks exercise saved settings and progress, start/stop, live completion, real audio playback, sound preview, and volume persistence. The suite uses isolated preferences, briefly plays the chime twice, and renders light, dark, Settings, and History screenshots into `build/`.

The README screenshots live separately in `screenshots/`. Refresh them after reviewing the rendered images:

```bash
cp build/popover-light.png screenshots/timer-light.png
cp build/popover-dark.png screenshots/timer-dark.png
cp build/popover-settings.png screenshots/settings.png
cp build/popover-history.png screenshots/history.png
```

## Project layout

| Path | Purpose |
| --- | --- |
| `Sources/` | Timer state, audio playback, menu bar app, and Settings UI |
| `Resources/make-assets.swift` | Generates the icon and completion chime locally |
| `Tests/` | Timer behavior, installer migration, and native integration checks |
| `Installer/preinstall` | Renames a matching legacy app during installation |
| `screenshots/` | Screenshots displayed in this README |
| `build.sh` | Builds, signs, checks, and packages the app |
| `test-ui.sh` | Runs native checks and renders screenshots |
| `version.sh` | Defines the release version and internal build number |
| `toolchain.sh` | Configures the SDK and project-local compiler cache |

Some Command Line Tools installations contain duplicate SwiftBridging headers. The build handles this with a project-local virtual filesystem overlay, without changing the installed Apple tools.
