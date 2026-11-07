# Time Slots

A simple native macOS menu bar app for manually started focus sessions. Set a daily goal and a slot length, start a timer, and hear a short chime when it finishes. No automatic breaks, accounts, or network access.

## Screenshots

| Light appearance | Dark appearance |
| --- | --- |
| <img src="screenshots/timer-light.png" alt="Time Slots timer in light appearance" width="300"> | <img src="screenshots/timer-dark.png" alt="Time Slots timer in dark appearance" width="300"> |

Settings includes the daily target, slot length, sound preview and volume, and the running version.

<img src="screenshots/settings.png" alt="Time Slots settings with sound controls and version 1.0.3" width="324">

## How it works

- The menu bar shows today's completed slots, such as **0/4**. While a slot runs, it also shows the remaining time.
- Click the count to open the timer. Press **Start** to begin; **Stop** discards an unfinished slot.
- A completed slot plays a gentle chime and increases the count. The next slot starts only when you press Start again.
- Defaults are **4 slots of 45 minutes**, with sound volume at **85%**. Settings lets you change these and preview the sound.
- Settings and progress persist across app restarts and installer updates. The daily count resets at local midnight.

A running timer includes time spent asleep or while the app is closed. An overdue timer completes on wake or relaunch. Slots that cross midnight count on their finish day; a slot that finished on a previous day is not added to today's count. Changing the slot length affects the next timer. You can continue beyond your daily target.

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
git clone https://github.com/ruslansavenok/time-slots.git TimeSlots
cd TimeSlots
```

From the project folder, run:

```bash
bash build.sh
```

The build tests the timer logic, generates the icon and sound, compiles both Intel and Apple Silicon binaries, combines them into a universal app, verifies its ad-hoc signature, and creates a macOS installer.

For version 1.0.3, the outputs are:

- App: `build/Time Slots.app`
- Installer: `dist/TimeSlots-1.0.3.pkg`

To try the app without installing it:

```bash
open "build/Time Slots.app"
```

Quit any already-running copy before opening another build. Build files and installers are generated locally and excluded from Git.

## Install or update

1. If Time Slots is running, click its menu bar count and choose **Quit**.
2. Open the installer and follow the macOS installation prompts:

   ```bash
   open dist/TimeSlots-1.0.3.pkg
   ```

3. Launch **Time Slots** from Applications or Spotlight:

   ```bash
   open "/Applications/Time Slots.app"
   ```

4. Look for **0/4** (or your saved progress) in the menu bar. There is no Dock icon. Open Settings to confirm the running version and use **Test sound** to check the chime.

An update replaces the app while keeping its saved progress, timer, and settings. Reopen it after updating so the new code runs. Saved volume preferences are retained. Sound follows your Mac's selected output, volume, and mute setting.

The build uses an ad-hoc app signature. Developer ID signing and Apple notarization for distributing prebuilt apps are not configured; the instructions above build the app locally on your Mac.

To uninstall, quit the app and move **Time Slots** from Applications to Trash.

## Tests and screenshot generation

After building, run the native integration checks in your Mac's logged-in desktop session:

```bash
bash test-ui.sh
```

These checks exercise saved settings and progress, start/stop, live completion, real audio playback, sound preview, and volume persistence. The suite uses isolated preferences, briefly plays the chime twice, and renders light, dark, and Settings screenshots into `build/`.

The README screenshots live separately in `screenshots/`. Refresh them after reviewing the rendered images:

```bash
cp build/popover-light.png screenshots/timer-light.png
cp build/popover-dark.png screenshots/timer-dark.png
cp build/popover-settings.png screenshots/settings.png
```

## Project layout

| Path | Purpose |
| --- | --- |
| `Sources/` | Timer state, audio playback, menu bar app, and Settings UI |
| `Resources/make-assets.swift` | Generates the icon and completion chime locally |
| `Tests/` | Timer behavior and native integration checks |
| `screenshots/` | Screenshots displayed in this README |
| `build.sh` | Builds, signs, checks, and packages the app |
| `test-ui.sh` | Runs native checks and renders screenshots |
| `version.sh` | Defines the release version and internal build number |
| `toolchain.sh` | Configures the SDK and project-local compiler cache |

Some Command Line Tools installations contain duplicate SwiftBridging headers. The build handles this with a project-local virtual filesystem overlay, without changing the installed Apple tools.
