# SlipTray Privacy Policy

_Last updated: 2026-10-16_

SlipTray is a local clipboard manager for macOS. This policy describes
what it does with your data, in plain terms.

## What SlipTray reads

SlipTray watches the system clipboard (`NSPasteboard`) so it can show
your recent copies in its popup. It also records which app was
frontmost when you copied something, so it can show that app's name and
icon next to the item.

SlipTray records **everything** you copy, including passwords and other
secrets copied from a password manager. It does not detect such content
and does not treat it differently from any other text. To keep an app's
copies out of the history, add that app to the exclusion list in
Settings, or pause capture before you copy.

## What SlipTray never does

- **Nothing you copy, paste, or type into SlipTray is ever sent anywhere.**
- **No analytics, no telemetry, no crash reporting services.**
- **No account, no sign-in.**

## Diagnostic log

Off by default. When you turn on **Record diagnostic log** in Settings →
About, SlipTray writes a log of its own activity and errors (error codes,
clip kinds, settings values) to
`~/Library/Application Support/SlipTray/Logs`. It never includes what you
copy. Nothing is sent: **Export Diagnostic Log…** saves a zip with the log,
your app and macOS versions, a few settings and SlipTray's crash reports,
which you can send to the developer yourself. Turning the setting off
deletes the log.

## Update checks

SlipTray's only network connection is the update check, done by the
open-source [Sparkle](https://sparkle-project.org) framework. It runs when
you click **Check for Updates** in Settings → About, and on a daily
schedule only if you allow automatic checks when SlipTray asks on its
second launch; turn them on or off later in Settings → About. It downloads
`https://github.com/huynq2311/SlipTray/releases/latest/download/appcast.xml`
from GitHub, and the new version from GitHub when you install one. The
request carries SlipTray's and Sparkle's version numbers; system
profiling is off, so nothing about your Mac or your clipboard is sent.
GitHub sees your IP address as it does for any download.

SlipTray loads Sparkle only when a check, or that one-time question,
is due, and only after checking that Sparkle is signed with the same
certificate as SlipTray itself; if that check fails, Sparkle is never
loaded and no update check happens.

## Where your data lives

Everything SlipTray stores — clipboard history, snippets, settings — is
kept only on your Mac, in your user's local Application Support folder.

**Clipboard history is stored unencrypted.** The text of your clips is in
a local database (`Database/`), very long clips are in plain text files
(`LongText/`), copied images are in `Cache/`, and the search index holds
clip text while SlipTray is unlocked. Anyone who can read your user
account's files can read them. Turn on FileVault to protect them when
your Mac is off or locked out.

**App Lock is not disk encryption.** It locks the SlipTray window and
hides previews until you unlock with Touch ID or your system password,
and it clears clip text from the search index while locked. It also
keeps an encrypted copy of clip content and notes, with a key wrapped
by the Secure Enclave (team-signed builds, when the Mac has one) or
stored in `PayloadKey.json`, a file only your user account can read
(release builds, signed with SlipTray's self-signed certificate, and ad-hoc
builds). On those builds that key
sits next to the encrypted data, so anyone who can read your files can
read the notes too; the encryption only keeps them out of casual view.
The unencrypted copies described above stay on disk either way.

**App Lock only locks within a session.** SlipTray opens unlocked when
it launches, including after a restart or reinstall, and locks when you
choose Lock or after the auto-lock timeout. Anyone who can use your
logged-in Mac can quit and reopen SlipTray to see your history.

iPhone ↔ Mac clipboard sharing, if you use it, goes through Apple's own
Universal Clipboard (Handoff) feature — SlipTray does not operate or
have access to that transport.

## System permissions SlipTray asks for

- **Accessibility**: required to simulate the paste keystroke (⌘V) when
  you select an item in the popup. SlipTray uses this only to paste; it
  does not log or transmit your keystrokes.

## Deleting your data

Quit SlipTray and delete `~/Library/Application Support/SlipTray` to
remove all locally stored clipboard history, snippets, and settings.

## Changes to this policy

If SlipTray's data handling changes in a future version, this file will
be updated alongside that release.
