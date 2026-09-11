# SlipBoard

A menu-bar clipboard manager for macOS. Press a hotkey, see your recent
copies in a popup grid, paste the one you want.

## Features

- Automatic clipboard capture (text, rich text, images, files/paths, code)
  with content-type detection (URL, email, phone, code, file path, hex
  color).
- Popup history grid with Pinned and Recent rails, search, tags, and
  folders.
- Paste as plain text, Markdown, stripped Unicode/accents, UPPERCASE, or
  lowercase.
- Snippets with dedicated per-snippet hotkeys.
- Exclude specific apps from capture, and pause capture manually or on a
  timer.
- Retention limits (max item count, TTL) with pinned items exempt from
  cleanup.
- App Lock: Touch ID/Face ID or system password, auto-lock, encrypted
  on-disk payload, hidden previews while locked.
- iPhone → Mac and Mac → iPhone clipboard sync works automatically through
  macOS Universal Clipboard (Handoff) — no iCloud account wiring required.

## Requirements

- macOS 15 or later to run. Liquid Glass theming activates automatically
  on macOS 26+; earlier versions fall back to the standard theme.
- Xcode 26 to build, because the project uses macOS 26 SDK APIs behind
  availability checks even though it ships back to macOS 15.

## Building

```bash
xcodebuild -project SlipBoard.xcodeproj -target SlipBoard -configuration Debug build
```

No shared Xcode scheme is committed; build by target as shown above, or
open `SlipBoard.xcodeproj` and build the `SlipBoard` target directly.

## Project layout

- `SlipBoard/` — the app (Core logic, Models, UI, Themes).
- `Tools/LocalizationHarness/` — standalone harness for testing the
  localization catalog (`swiftc`, no Xcode project needed).
- `design/` — design docs and UI contracts.

## License

All rights reserved.
