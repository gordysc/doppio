# Doppio

Doppio is a macOS menu bar app. It gives a GUI for `/usr/bin/caffeinate`.

## Features

- **Keep awake:** Select the assertions that `caffeinate` holds. The options are display (`-d`), system idle (`-i`), disk (`-m`), system on AC power (`-s`), and user active (`-u`).
- **Duration:** Select one limit. The Mac stays awake forever, for a set time, until a time of day, or while an app runs (`-w <pid>`).
- **Menu bar:** The icon shows steam when the Mac stays awake. The icon can also show the remaining time.
- **Window:** The window has the same controls and the settings. To open the window, click **Settings…** in the menu bar panel. You can also open Doppio again from Finder or Spotlight.
- **Settings:** Doppio can open at login. It can keep the Mac awake when it opens. It can show in the menu bar, in the Dock, or in both.

Doppio always shows the full `caffeinate` command. You can copy the command.

## Install

You must have macOS 15 or later, and Xcode with Swift 6.

1. Open Terminal in the project folder.
2. Type `make install`.

The command builds the app, copies it to `/Applications`, and opens it.

Other `make` targets:

| Target | Result |
| --- | --- |
| `make app` | Builds `build/Doppio.app`. |
| `make test` | Runs the unit tests. |
| `make icon` | Makes `Resources/AppIcon.icns` again. |
| `make clean` | Removes the build output. |

## How it works

Doppio starts the real `caffeinate` tool as a child process. Doppio does not call the power APIs directly.

Each session gives `-w <Doppio pid>` to `caffeinate`. Thus `caffeinate` stops when Doppio stops, also after a crash or a force quit.

A timed session also gives `-t <seconds>` to `caffeinate`. Doppio also compares the deadline with the wall clock, and stops the session at the deadline.

If you change an assertion during a session, Doppio starts `caffeinate` again with the same deadline. If you change the duration, Doppio starts a new session.

## Layout

| Path | Contents |
| --- | --- |
| `Sources/DoppioCore` | The logic without UI: assertions, session limits, the command line, and text formats. Unit tests cover this code. |
| `Sources/Doppio` | The app: the model, the `caffeinate` process, the SwiftUI views, and the app delegate. |
| `Tests/DoppioCoreTests` | The Swift Testing tests for `DoppioCore`. |
| `Resources` | The `Info.plist` file, and the `AppIcon.icns` file that `make icon` makes. |
| `scripts` | The scripts that make the icon, build the bundle, and install the app. |

## Code signing

The build script signs the app ad hoc. To sign the app with a certificate, set `CODESIGN_IDENTITY` before you type `make app`.

## License

The MIT License applies to Doppio. Refer to the [`LICENSE`](LICENSE) file.
