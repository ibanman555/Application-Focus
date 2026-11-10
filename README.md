# Application Focus for Stream Deck

> **TEST BUILD — NOT YET CONFIRMED WORKING ON WINDOWS/STREAM DECK.** This project is in the test phase until the maintainer confirms successful installation and real-world application focusing. Do not consider v1.0 production-ready or depend on it during a live show until tested.

A Windows-only Stream Deck plugin for **focusing an application that is ALREADY RUNNING** — without starting the target program.

## The one job this plugin does

When you press the Stream Deck key, it searches for an **existing, visible, top-level application window** matching the configured `.exe` name, then attempts to **bring that window to the front**. If that window is minimized, it attempts to restore it.

**It NEVER launches, starts, reopens, or restarts the target program.** If the target is closed, has no focusable window, or Windows denies focus, the plugin shows an alert instead. This is deliberately **not** Stream Deck's built-in **Open Application** action, which may start an application.

It is intended for users who keep multiple programs running and need a single button to switch focus without additional automation software. Examples include Wireless Workbench, SuperRack Performer, LiveTrax, and other desktop programs.

## Test-phase status

- **Status:** experimental / awaiting user confirmation.
- **Host platform:** Windows 10/11, Stream Deck 7.1+ (intended; not independently confirmed on hardware).
- **Known:** source and installer archive have been assembled. **Not yet verified** to install or focus windows on Windows hardware. v1.0.1 corrects the invalid icon dimensions of the initial test installer.
- **Version:** v1.0.1 test build. No stable release is claimed.
- **Safety:** test on non-critical windows, not in a live-show workflow, until confirmed.

## Test build history

- **v1.0.1 (November 10, 2026):** Corrected Elgato-required image sizes, added the 28/56px category icon, and incremented the version following an installer failure. This build is **not yet confirmed** to install or focus windows.

## Install the test build

1. Download [`Application_Focus_for_Stream_Deck_v1.0.1.streamDeckPlugin`](Application_Focus_for_Stream_Deck_v1.0.1.streamDeckPlugin) from this repository.
2. On a Windows computer with Stream Deck installed, double-click the downloaded `.streamDeckPlugin` installer.
3. In Stream Deck, locate **Application Focus → Focus Existing App** and drag it onto a key.
4. Select the button and choose an application from **Choose an open application**, or type its executable filename manually (for example, `Wireless Workbench.exe`).
5. Optionally enter part of the existing window title, then press the Stream Deck button to focus it.

The selection dropdown lists visible titled windows. Case-insensitive executable matching supports `*` and `?` wildcards. The optional title filter distinguishes windows with the same executable, where possible. Minimized applications may still be found; tray-only or background processes with no window cannot be focused. Browser tabs inside the same browser window are not separate windows and cannot be individually focused.

## Verify behavior before relying on it

1. Start a test application normally and leave it open; switch to a different application.
2. Press the Application Focus key; confirm the running application comes to the foreground without spawning a duplicate process.
3. Minimize the application and press again; confirm the existing window is restored and focused.
4. **Close the target application entirely**, press the key, and verify it **does not launch**. Expect a Stream Deck alert.
5. Check the app picker, manually entered executable name, optional title filter, and wildcard matching.
6. Check if Windows refuses foreground activation or if an elevated/admin program behaves differently; report it as a test result.

Please **confirm whether these tests work** before this project is marked stable. Feedback and bug reports can be added as GitHub issues.

## How it works

The plugin communicates with Stream Deck's local plugin WebSocket and uses a hidden, persistent Windows PowerShell helper to **enumerate and focus existing Win32 windows**. It uses Win32 window-management APIs (`EnumWindows`, `ShowWindowAsync`, `SetForegroundWindow`, and related calls) and may fall back to `WScript.Shell.AppActivate` against an existing process ID. The PowerShell helper itself is started by Stream Deck; **the selected target application is never started**. No MIDI routing, third-party plugins, or separately configured scripts are required.

Windows foreground-focus restrictions may prevent an activation. Elevated apps may also be inaccessible depending on permissions. No app can be made focusable if it has no top-level window.

## Build from source

See the `com.koop.appfocus.sdPlugin/` folder for the manifest, JavaScript plugin backend, PowerShell Windows helper, property-inspector UI, and icons. The packaged test build contains the same files. To package changes locally, see the official [Stream Deck CLI instructions](https://docs.elgato.com/streamdeck/cli/commands/pack/).

