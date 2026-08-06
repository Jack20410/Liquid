# Build & Run

## Requirements

- **Xcode 26** (the project targets iOS 26.5 and only iOS 26 simulators are used).
- An **iPhone 17-family** simulator (that is what is installed on this machine —
  there is no iPhone 16). Adjust the destination name to any installed device.

## Toolchain note — use `DEVELOPER_DIR`

On this machine, `xcode-select` points at the Command Line Tools, not the full
Xcode, so a plain `xcodebuild` fails with *"requires Xcode"*. Full Xcode is installed
at `/Applications/Xcode.app`, so prefix commands with `DEVELOPER_DIR` — this needs no
`sudo` and no password:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild ...
```

(Alternatively, a one-time `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
would make the prefix unnecessary and also enable the native Simulator tooling — but
that requires the machine password.)

## Build

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project Liquid.xcodeproj -scheme Liquid \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Test

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project Liquid.xcodeproj -scheme Liquid \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:LiquidTests
```

## Run in the simulator

```bash
DD=/Applications/Xcode.app/Contents/Developer
APP="$(DEVELOPER_DIR=$DD xcodebuild -project Liquid.xcodeproj -scheme Liquid \
      -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
      -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $2; exit}')/Liquid.app"

DEVELOPER_DIR=$DD xcrun simctl boot "iPhone 17 Pro" 2>/dev/null; open -a Simulator
DEVELOPER_DIR=$DD xcrun simctl install booted "$APP"
DEVELOPER_DIR=$DD xcrun simctl launch booted com.jabick.Liquid
```

The bundle identifier is `com.jabick.Liquid`.

## Sample data

In **DEBUG** builds, first launch seeds a month of demo data (two accounts, five
envelopes with rules, an allocated paycheck, a fresh unallocated paycheck, and
scattered expenses) via `Liquid/Support/SampleData.swift`. This entire file is inside
`#if DEBUG`, so **release builds ship no seed** — a real device starts empty with the
user's own data. To reset the demo data, uninstall the app from the simulator (which
clears its SwiftData store) and relaunch.

## A note on editor warnings

The background SourceKit indexer also runs under the Command Line Tools and cannot
find the SwiftData macro plugin, so it emits false *"External macro … SwiftDataMacros
not found"* and *"Cannot find type …"* diagnostics for the model files. These are not
real — the authoritative signal is a `DEVELOPER_DIR` `xcodebuild` run.
