# SynthMaker Techno 1.1 — development build

A one-bar acid groovebox for iPhone. Press Play to start the bass, kick and hi-hat, then edit the 16 steps while it runs.

## Implemented

- Sample-clocked 16-step playback, 60–180 BPM and swing.
- Per-step pitch, rest, accent, slide, kick and hi-hat.
- Four bass waveforms; resonant filter with envelope modulation; drive.
- Three starting patterns and four local save slots for the full pattern and sound.
- Four-bar mono WAV export at 44.1 kHz, using the same DSP as live playback.
- Stops on backgrounding, audio interruptions and headphone disconnection.
- Removes the advertising banner and tracking request from the application path.

The old manual keyboard/ADSR screen is replaced by the groove editor. This is a focused groovebox iteration, not a full DAW. MIDI, AUv3, song arrangement, undo, automation and a dedicated keyboard are not included yet. Exported files have short edge fades; seamless loop tails are not implemented.

## Build

Open `SynthMaker.xcodeproj` in Xcode on macOS. Target: iOS 15+. Bundle ID remains `com.tokyonasu.SynthMaker`. Version 1.1, build 2. Signing needs the original developer account.

```sh
xcodebuild -project SynthMaker.xcodeproj -scheme SynthMaker -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## Tests

```sh
swiftc SynthMaker/GrooveCore.swift Tests/GrooveCoreTests.swift -o /tmp/groove-tests
/tmp/groove-tests
```

Tests cover preset validity, complete JSON round trips, rejected invalid saves, fractional sample timing over eight bars at two sample rates, extreme swing, silence, output limits and deterministic rendering. These ran successfully with Swift 6.3.3 on Windows. They do not verify AVAudioEngine, SwiftUI or perceived sound quality.

Before shipping, run the iOS build and check on real devices:

- Play/Stop and live edits at 60/130/180 BPM; listen for glitches during heavy interaction.
- Silent switch, Bluetooth/wired headphones, interruption, background/foreground and audio-service reset.
- Save all four slots, relaunch, restore every sound/step setting; cancel replacement dialogs.
- Export all presets, share to Files, reopen the WAV, confirm four-bar duration and edge fades.
- Small iPhone screens, large text, VoiceOver, sustained playback and CPU/battery use.
- Update App Store screenshots, feature text and advertising/privacy declarations to match the shipped binary.

No App Store upload or release is performed by this change.
