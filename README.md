# Application Focus for Stream Deck

> **v1.0.2 TEST BUILD — NEW CONFIRMATION TOGGLE AWAITING VERIFICATION.** Version 1.0.1 has been confirmed to install and focus existing applications successfully on Windows with Stream Deck. Version 1.0.2 retains that focus behavior and adds an optional confirmation setting; test the updated build before relying on it during a live show.

A Windows-only Stream Deck plugin for **focusing an application that is ALREADY RUNNING** — without starting the target program.

## The one job this plugin does

When you press the Stream Deck key, it searches for an **existing, visible, top-level application window** matching the configured `.exe` name, then attempts to **bring that window to the front**. If that window is minimized, it attempts to restore it.

**It NEVER launches, starts, reopens, or restarts the target program.** If the target is closed, has no focusable window, or Windows denies focus, the action fails without launching it; an alert is shown only if button confirmation is enabled. This is deliberately **not** Stream Deck's built-in **Open Application** action, which may start an application.

It is intended for users who keep multiple programs running and need a single button to switch focus without additional automation software. Examples include Wireless Workbench, SuperRack Performer, LiveTrax, and other desktop programs.

## Version status

- **v1.0.1:** Confirmed by the project owner to install and focus already-running programs successfully on Windows with Stream Deck.
- **v1.0.2:** Test build awaiting confirmation that the new per-button setting works as expected.
- **Platform:** Windows 10/11, Stream Deck 7.1+.
- **Safety:** Try the updated build on non-critical applications before relying on it during a live show.

## Build history

- **v1.0.2 (November 10, 2026):** Added a per-key **Show button confirmation** checkbox, enabled by default. Turn it off to suppress both the success checkmark and error alert; focusing continues unchanged. **Awaiting user confirmation.**
- **v1.0.1 (November 10, 2026):** Corrected image sizes, added category artwork, and fixed installation. The project owner **confirmed installation and application focusing work**.

## Install the test build

1. Download [`Application_Focus_for_Stream_Deck_v1.0.2.streamDeckPlugin`](Application_Focus_for_Stream_Deck_v1.0.2.streamDeckPlugin) from this repository.
2. On a Windows computer with Stream Deck installed, double-click the downloaded `.streamDeckPlugin` installer.
3. In Stream Deck, locate **Application Focus → Focus Existing App** and drag it onto a key.
4. Select the button and choose an application from **Choose an open application**, or type its executable filename manually (for example, `Wireless Workbench.exe`).
5. Optionally enter part of the existing window title.
6. Leave **Show button confirmation** checked to show a ✓ when focus succeeds or an error indicator when it fails. Uncheck it to suppress **both** overlays.
7. Press the Stream Deck button to focus the existing window. The setting is saved separately for each action/key.

The selection dropdown lists visible titled windows. Case-insensitive executable matching supports `*` and `?` wildcards. The optional title filter distinguishes windows with the same executable, where possible. Minimized applications may still be found; tray-only or background processes with no window cannot be focused. Browser tabs inside the same browser window are not separate windows and cannot be individually focused.

## Verify behavior before relying on it

1. Start a test application normally and leave it open; switch to a different application.
2. Press the Application Focus key; confirm the running application comes to the foreground without spawning a duplicate process.
3. Minimize the application and press again; confirm the existing window is restored and focused.
4. **Close the target application entirely**, press the key, and verify it **does not launch**. With confirmation enabled, expect a Stream Deck error indicator. With confirmation disabled, expect no overlay.
5. Check the app picker, manually entered executable name, optional title filter, and wildcard matching.
6. With **Show button confirmation** ON, verify the success checkmark appears when focus works and the error indicator appears if a target is unavailable.
7. Turn **Show button confirmation** OFF; verify neither indicator appears for success or failure, while the actual focus result stays the same.
8. Check if Windows refuses foreground activation or if an elevated/admin program behaves differently.

**v1.0.1 focusing is confirmed working on the project owner's system.** Please report any v1.0.2 confirmation-toggle problems as GitHub issues.

## How it works

The plugin communicates with Stream Deck's local plugin WebSocket and uses a hidden, persistent Windows PowerShell helper to **enumerate and focus existing Win32 windows**. It uses Win32 window-management APIs (`EnumWindows`, `ShowWindowAsync`, `SetForegroundWindow`, and related calls) and may fall back to `WScript.Shell.AppActivate` against an existing process ID. The PowerShell helper itself is started by Stream Deck; **the selected target application is never started**. No MIDI routing, third-party plugins, or separately configured scripts are required.

Windows foreground-focus restrictions may prevent an activation. Elevated apps may also be inaccessible depending on permissions. No app can be made focusable if it has no top-level window.

## Build from source

See the `com.koop.appfocus.sdPlugin/` folder for the manifest, JavaScript plugin backend, PowerShell Windows helper, property-inspector UI, and icons. The packaged test build contains the same files. To package changes locally, see the official [Stream Deck CLI instructions](https://docs.elgato.com/streamdeck/cli/commands/pack/).

