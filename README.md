# Simulator Drop

Push files and URLs onto a booted iOS Simulator from the menu bar.

Menu extra for macOS 14+. It lives in the menu bar and does not show a Dock icon.

## Features

- Lists simulators via `xcrun simctl`.
- Drop zone window for files.
- Open a pasted URL on the selected simulator.
- Recent drops.
- Pin a device in Settings.

## Requirements

- macOS 14 Sonoma or later
- Swift 5.9 or later
- `xcrun` and the `simctl` developer tool (Xcode or full Command Line Tools)

## Install

Homebrew (macOS 14+):

```bash
brew tap BadryansahBangsawan/mac-menu-apps
brew install --cask simulator-drop
```

Opens as a menu extra (no Dock icon). The cask is ad-hoc signed. If Gatekeeper blocks it:

```bash
xattr -cr /Applications/SimulatorDrop.app
```

Build from source:

```bash
git clone https://github.com/BadryansahBangsawan/simulator-drop.git
cd simulator-drop
bash package-app.sh
open dist/SimulatorDrop.app
```

Enable **Open at Login** from Settings if you want it after reboot.

## Usage

- Pick a booted simulator, then **Drop zone** or paste a URL and **Open**.
- If `simctl` is missing, the panel shows the `xcrun` stderr (for example `unable to find utility "simctl"`) instead of a fake empty-simulator state.

## Permissions

- No Screen Recording. Simulator control goes through `simctl`.

Denied permissions must not crash the app. You should see a banner and a button to open System Settings.

## Privacy

No network except what you send into the simulator (opened URLs). Device pin is local UserDefaults.

Bundle ID: `engineer.badry.simulatordrop`.

## Development

```bash
swift build
swift build -c release --product SimulatorDrop
```

Layout: `Sources/` (SwiftPM executable), `Info.plist`, `Assets/AppIcon.icns`, `package-app.sh`.

## Missing simctl

This app does not install Xcode. On a machine with `xcrun` but no `simctl`, a red label is the expected result.


## License

[MIT](LICENSE)
