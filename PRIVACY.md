# SlipBoard Privacy Policy

_Last updated: 2026-09-10_

SlipBoard is a local clipboard manager for macOS. This policy describes
what it does with your data, in plain terms.

## What SlipBoard reads

SlipBoard watches the system clipboard (`NSPasteboard`) so it can show
your recent copies in its popup. It also records which app was
frontmost when you copied something, so it can show that app's name and
icon next to the item.

## What SlipBoard never does

- **No network access.** SlipBoard does not contain any networking code.
  Nothing you copy, paste, or type into SlipBoard is ever sent anywhere.
- **No analytics, no telemetry, no crash reporting services.**
- **No account, no sign-in.**

## Where your data lives

Everything SlipBoard stores — clipboard history, snippets, settings — is
kept only on your Mac, in your user's local Application Support folder.
When App Lock is enabled, clipboard content and notes are additionally
encrypted on disk using a key protected by the Secure Enclave (or the
Keychain as a fallback), unlocked with Touch ID, Face ID, or your system
password.

iPhone ↔ Mac clipboard sharing, if you use it, goes through Apple's own
Universal Clipboard (Handoff) feature — SlipBoard does not operate or
have access to that transport.

## System permissions SlipBoard asks for

- **Accessibility**: required to simulate the paste keystroke (⌘V) when
  you select an item in the popup. SlipBoard uses this only to paste; it
  does not log or transmit your keystrokes.

## Deleting your data

Quit SlipBoard and delete `~/Library/Application Support/SlipBoard` to
remove all locally stored clipboard history, snippets, and settings.

## Changes to this policy

If SlipBoard's data handling changes in a future version, this file will
be updated alongside that release.
