# SynthMaker Techno 1.1 — development build

A one-bar acid groovebox for iPhone. Press Play to start the bass, kick and hi-hat, then edit the 16 steps while it runs.

## Implemented

- Sample-clocked 16-step playback, 60–180 BPM and swing.
- Per-step pitch, rest, accent, slide, kick and hi-hat.
- Four acid bass waveforms; resonant filter with envelope modulation; drive.
- Warm Analog, Glass Bell and Soft Keys synthesis models, plus the original LUMA-7 instrument.
- Adjustable register and tone decay, with a tempo-synced damped tape-style echo.
- Per-note probability and every-2/every-4-loop conditions, with per-step cutoff locks.
- Euclidean rhythm generation for each lane; A minor pentatonic mutation; one-level full-pattern undo for generation/load.
- Six starting patterns and four local save slots for the full pattern and sound.
- Four-bar mono WAV export at 44.1 kHz, using the same DSP as live playback.
- Stops on backgrounding, audio interruptions and headphone disconnection.
- Removes the advertising banner and tracking request from the application path.

The old manual keyboard/ADSR screen is replaced by the groove editor. This is a focused groovebox iteration, not a full DAW. MIDI, AUv3, song arrangement, undo, automation and a dedicated keyboard are not included yet. Exported files have short edge fades; seamless loop tails are not implemented.

## LUMA-7 and modeled instruments

LUMA-7 is the working name for an original monophonic software instrument, not an emulation of a specific commercial synth. Seven separately phased partials form its voice:

- **Color** moves the upper partials away from exact harmonics toward a glass-like spectrum. The fundamental stays in tune.
- **Bloom** controls the delayed opening of upper partials after a note starts.
- **Motion** adds slow phase/frequency movement.
- **Tone tail** sets the amplitude decay time constant, not a hard note duration.
- **Tape echo** adds damped, softly saturated dotted-eighth repeats to the instrument, leaving the drums dry. It is an echo, not a convolution reverb.

Warm Analog blends slightly detuned band-limited saws with a sine. Glass Bell uses inharmonic FM; Soft Keys uses a decaying harmonic FM tone and a brief upper partial. These are original synthesis approximations, not component-accurate replicas of named hardware. All instrument models share one melodic voice; new notes retune it. Polyphonic chords, independently decaying voices and stereo effects are not implemented.

Choosing an instrument changes the tone controls/register while preserving the pattern. The previous patch can be recovered with Undo. Tone settings are saved in slots and used by WAV export. Older saves without a tone object load as the original acid bass.

The signature starting patch is **LUMA-7 · First Light**. Glass Bell · Starlight and Soft Keys · Night Transit provide two other melodic starting points.

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

Tests cover preset validity, complete JSON round trips, rejected invalid saves, fractional sample timing over eight bars at two sample rates, extreme swing, silence, output limits and deterministic rendering. Instrument tests cover legacy saves, round trips for every model, audible/distinct output, LUMA-7 macro response, no notes before a trigger, deterministic transport reset including echo memory, and bounded high-register output at 44.1/48 kHz. Evolution tests also check Euclidean spacing and hit counts, lane isolation, scale-safe mutation, probability-zero silence, audible cutoff locks and alternating conditional bars. These ran successfully with Swift 6.3.3 on Windows. They do not verify AVAudioEngine, SwiftUI or perceived sound quality.

Before shipping, run the iOS build and check on real devices:

- Play/Stop and live edits at 60/130/180 BPM; listen for glitches during heavy interaction.
- Silent switch, Bluetooth/wired headphones, interruption, background/foreground and audio-service reset.
- Save all four slots, relaunch, restore every sound/step setting; cancel replacement dialogs.
- Export all presets, share to Files, reopen the WAV, confirm four-bar duration and edge fades.
- Small iPhone screens, large text, VoiceOver, sustained playback and CPU/battery use.
- Update App Store screenshots, feature text and advertising/privacy declarations to match the shipped binary.

## Audio preview

`Scripts/RenderDemo.swift` renders an eight-bar WAV with the same DSP, using Euclidean bass rhythm, probability, loop conditions and cutoff locks. Compile it with `GrooveCore.swift` and pass an output WAV path. An optional model argument (1: Warm Analog, 2: Glass Bell, 3: Soft Keys, 4: LUMA-7) renders four melodic bars with a two-second tail. This offline preview does not verify device playback or sharing.

The initial iOS simulator build passed in GitHub Actions. Rerun CI after subsequent edits and complete real-device checks before release.

No App Store upload or release is performed by this change.
