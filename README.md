# Focus Slots

A simple native macOS menu bar app for manually started focus sessions. Set a daily goal and a slot length, start a timer, and hear a short chime when it finishes. No automatic breaks, accounts, or network access.

## Screenshots

| Light appearance | Dark appearance |
| --- | --- |
| <img src="screenshots/timer-light.png" alt="Focus Slots timer in light appearance" width="300"> | <img src="screenshots/timer-dark.png" alt="Focus Slots timer in dark appearance" width="300"> |

| Running timer — light | Running timer — dark |
| --- | --- |
| <img src="screenshots/running-light.png" alt="Running timer with visible Stop text and icon in light mode" width="300"> | <img src="screenshots/running-dark.png" alt="Running timer with visible Stop text and icon in dark mode" width="300"> |

Settings includes the daily target, slot length, sound preview and volume, and the running version.

| Settings | History |
| --- | --- |
| <img src="screenshots/settings.png" alt="Focus Slots settings with sound controls and version 1.0.10" width="300"> | <img src="screenshots/history.png" alt="Daily history with dates and completed slots over daily targets" width="300"> |

## How it works

- The menu bar shows today's completed slots, such as **0/4**. While a slot runs, it also shows the remaining time.
- Click the count to open the timer. Press **Start** to begin and close the dropdown; the countdown stays visible in the menu bar. **Stop** discards an unfinished slot.
- A completed slot plays a gentle chime and increases the count. The timer returns to the full slot length, ready for another manual start. You can continue beyond the target, such as **5/4** after five completed slots.
- Defaults are **4 slots of 45 minutes**, with sound volume at **100%**. Settings lets you change these and preview the sound.
- The **History** icon, immediately left of Settings, opens a newest-first list such as **Nov 7 — 3/4**. Each date keeps its own daily target and includes extra slots.
- Settings, progress, and history persist across app restarts and app updates. The daily count resets at local midnight while its result remains in History.

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

The build tests the timer logic, generates the icon and sound, compiles both Intel and Apple Silicon binaries, combines them into a universal app, verifies its ad-hoc signature, and creates a compressed drag-to-Applications disk image. It then mounts the image and checks the copied app, its signature, version, and both CPU architectures.

For version 1.0.10, the outputs are:

- App: `build/Focus Slots.app`
- Disk image: `dist/FocusSlots-1.0.10.dmg`

To try the app without installing it:

```bash
open "build/Focus Slots.app"
```

Quit any already-running copy before opening another build. Build files and disk images are generated locally and excluded from Git.

## Install or update

1. If Focus Slots (or the previous Time Slots app) is running, click its menu bar count and choose **Quit**.
2. Open the disk image:

   ```bash
   open dist/FocusSlots-1.0.10.dmg
   ```

3. Drag **Focus Slots.app** onto the **Applications** shortcut in the mounted image. When updating an existing copy, choose **Replace**.
4. Eject the **Focus Slots** disk image, then launch **Focus Slots** from Applications or Spotlight:

   ```bash
   open "/Applications/Focus Slots.app"
   ```

5. Look for **0/4** (or your saved progress) in the menu bar. There is no Dock icon. Open Settings to confirm the running version and use **Test sound** to check the chime.

The DMG installs by copying the app. It does not run an installer package or installation scripts. Your Mac or organisation may still require permission to write to Applications or run the app.

If upgrading from the old **Time Slots** name, quit it and move **Time Slots.app** from Applications to Trash before copying **Focus Slots.app**. The app retains the original internal identity and preference keys, so removing the old app bundle does not erase saved progress, settings, or history.

An update replaces the app while keeping its saved progress, timer, and settings. Reopen it after updating so the new code runs. Version 1.0.4 sets completion sound volume to 100% once on first launch, including upgrades. Later volume adjustments are saved normally. Sound follows your Mac's selected output, volume, and mute setting.

The build uses an ad-hoc app signature. Developer ID signing and Apple notarization for distributing prebuilt apps are not configured; the instructions above build the app locally on your Mac.

To uninstall, quit the app and move **Focus Slots** from Applications to Trash.

## Tests and screenshot generation

After building, run the native integration checks in your Mac's logged-in desktop session:

```bash
bash test-ui.sh
```

These checks exercise saved settings and progress, start/stop, live completion, real audio playback, sound preview, and volume persistence. The suite uses isolated preferences, briefly plays the chime twice, and renders Start and Stop in light and dark mode, plus Settings and History screenshots into `build/`.

The README screenshots live separately in `screenshots/`. Refresh them after reviewing the rendered images:

```bash
cp build/popover-light.png screenshots/timer-light.png
cp build/popover-dark.png screenshots/timer-dark.png
cp build/popover-running-light.png screenshots/running-light.png
cp build/popover-running-dark.png screenshots/running-dark.png
cp build/popover-settings.png screenshots/settings.png
cp build/popover-history.png screenshots/history.png
```

## Project layout

| Path | Purpose |
| --- | --- |
| `Sources/` | Timer state, audio playback, menu bar app, and Settings UI |
| `Resources/make-assets.swift` | Generates the icon and completion chime locally |
| `Tests/` | Timer behavior, DMG copy-install verification, and native integration checks |
| `screenshots/` | Screenshots displayed in this README |
| `build.sh` | Builds, signs, and checks the app, then creates and verifies the DMG |
| `test-ui.sh` | Runs native checks and renders screenshots |
| `Tests/DMGTests.sh` | Mounts the DMG and verifies a copy of its app |
| `version.sh` | Defines the release version and internal build number |
| `toolchain.sh` | Configures the SDK and project-local compiler cache |

Some Command Line Tools installations contain duplicate SwiftBridging headers. The build handles this with a project-local virtual filesystem overlay, without changing the installed Apple tools.
