# SlipBoard Privacy Policy

_Last updated: 2026-10-12_

SlipBoard is a local clipboard manager for macOS. This policy describes
what it does with your data, in plain terms.

## What SlipBoard reads

SlipBoard watches the system clipboard (`NSPasteboard`) so it can show
your recent copies in its popup. It also records which app was
frontmost when you copied something, so it can show that app's name and
icon next to the item.

SlipBoard records **everything** you copy, including passwords and other
secrets copied from a password manager. It does not detect such content
and does not treat it differently from any other text. To keep an app's
copies out of the history, add that app to the exclusion list in
Settings, or pause capture before you copy.

## What SlipBoard never does

- **No network access.** SlipBoard does not contain any networking code.
  Nothing you copy, paste, or type into SlipBoard is ever sent anywhere.
- **No analytics, no telemetry, no crash reporting services.**
- **No account, no sign-in.**

## Where your data lives

Everything SlipBoard stores — clipboard history, snippets, settings — is
kept only on your Mac, in your user's local Application Support folder.

**Clipboard history is stored unencrypted.** The text of your clips is in
a local database (`Database/`), very long clips are in plain text files
(`LongText/`), copied images are in `Cache/`, and the search index holds
clip text while SlipBoard is unlocked. Anyone who can read your user
account's files can read them. Turn on FileVault to protect them when
your Mac is off or locked out.

**App Lock is not disk encryption.** It locks the SlipBoard window and
hides previews until you unlock with Touch ID or your system password,
and it clears clip text from the search index while locked. It also
keeps an encrypted copy of clip content and notes, with a key wrapped
by the Secure Enclave (team-signed builds, when the Mac has one) or
stored in `PayloadKey.json`, a file only your user account can read
(ad-hoc builds, which is what releases are). On ad-hoc builds that key
sits next to the encrypted data, so anyone who can read your files can
read the notes too; the encryption only keeps them out of casual view.
The unencrypted copies described above stay on disk either way.

**App Lock only locks within a session.** SlipBoard opens unlocked when
it launches, including after a restart or reinstall, and locks when you
choose Lock or after the auto-lock timeout. Anyone who can use your
logged-in Mac can quit and reopen SlipBoard to see your history.

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
