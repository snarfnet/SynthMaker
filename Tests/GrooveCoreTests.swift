import Foundation

@main
struct GrooveCoreTests {
    static func main() throws {
        for index in 0...7 {
            let patch = GroovePatch.preset(index)
            precondition(patch.isValid)
            let restored = try JSONDecoder().decode(GroovePatch.self, from: JSONEncoder().encode(patch))
            precondition(restored == patch, "Save/load must preserve every control and step")
        }
        var invalid = GroovePatch()
        invalid.steps = []
        precondition(!invalid.isValid)
        invalid = GroovePatch(); invalid.tempo = .nan
        precondition(!invalid.isValid)
        invalid = GroovePatch(); invalid.steps[0].note = 100
        precondition(!invalid.isValid)

        for rate in [44_100.0, 48_000.0] {
            for swing in [0.0, 0.45] {
                var patch = GroovePatch()
                patch.tempo = 137; patch.swing = swing
                var dsp = GrooveDSP(sampleRate: rate)
                let bar = rate * 60 / patch.tempo * 4
                let frames = Int(ceil(bar * 8))
                var energy = 0.0
                for _ in 0..<frames {
                    let sample = Double(dsp.nextSample(patch))
                    precondition(sample.isFinite && abs(sample) <= 0.85, "Output must stay finite and bounded")
                    energy += sample * sample
                }
                precondition(dsp.stepCount == 128, "Eight bars must contain exactly 128 steps")
                _ = dsp.nextSample(patch)
                precondition(dsp.stepCount == 129, "Fractional timing must not drift across bars")
                precondition(energy / Double(frames) > 0.0001, "Default pattern must be audible")
            }
        }
        var silent = GroovePatch()
        silent.drums = false
        for i in silent.steps.indices { silent.steps[i].enabled = false }
        var silenceDSP = GrooveDSP(sampleRate: 44_100)
        for _ in 0..<44_100 { precondition(silenceDSP.nextSample(silent) == 0) }

        var extreme = GroovePatch()
        extreme.cutoff = 12000; extreme.resonance = 10; extreme.envMod = 1; extreme.drive = 1
        for wave in 0...3 {
            extreme.waveform = wave
            var dsp = GrooveDSP(sampleRate: 44_100)
            for _ in 0..<88_200 {
                let output = dsp.nextSample(extreme)
                precondition(output.isFinite && abs(output) <= 0.85)
            }
        }
        var first = GrooveDSP(sampleRate: 44_100)
        var second = GrooveDSP(sampleRate: 44_100)
        for _ in 0..<44_100 {
            precondition(first.nextSample(.preset(0)) == second.nextSample(.preset(0)), "Export must reproduce playback DSP")
        }
        for hits in 0...16 {
            for rotation in 0..<16 {
                let rhythm = GroovePatch.euclidean(pulses: hits, rotation: rotation)
                precondition(rhythm.filter { $0 }.count == hits)
                let indices = rhythm.indices.filter { rhythm[$0] }
                if hits > 1 {
                    let gaps = indices.indices.map { (indices[($0 + 1) % hits] - indices[$0] + 16) % 16 }
                    precondition(gaps.max()! - gaps.min()! <= 1, "Euclidean hits must be evenly distributed")
                }
            }
        }
        var generated = GroovePatch()
        let original = generated
        generated.generateRhythm(pulses: 5, rotation: 3, lane: 1)
        precondition(generated.steps.filter { $0.kick }.count == 5)
        for i in 0..<16 {
            precondition(generated.steps[i].note == original.steps[i].note)
            precondition(generated.steps[i].enabled == original.steps[i].enabled)
            precondition(generated.steps[i].hat == original.steps[i].hat)
        }
        generated.mutate(seed: 42)
        precondition(generated != original && generated.isValid)
        precondition(generated.steps.allSatisfy { [0, 3, 5, 7, 10, 12].contains($0.note) })
        for i in 0..<16 { precondition(generated.steps[i].enabled == original.steps[i].enabled) }

        var probability = GroovePatch()
        probability.drums = false
        for i in 0..<16 { probability.steps[i].probability = 0 }
        var chanceDSP = GrooveDSP(sampleRate: 44_100)
        for _ in 0..<88_200 { precondition(chanceDSP.nextSample(probability) == 0) }
        var locked = GroovePatch()
        locked.steps[0].cutoffLock = 80
        locked.steps[1].probability = 0.35
        locked.steps[2].every = 4
        let restoredLocks = try JSONDecoder().decode(GroovePatch.self, from: JSONEncoder().encode(locked))
        precondition(restoredLocks == locked)
        var plainDSP = GrooveDSP(sampleRate: 44_100)
        var lockedDSP = GrooveDSP(sampleRate: 44_100)
        var difference = 0.0
        for _ in 0..<4000 {
            difference += abs(Double(plainDSP.nextSample(.preset(0)) - lockedDSP.nextSample(locked)))
        }
        precondition(difference > 1, "Cutoff locks must change the rendered sound")
        var conditional = GroovePatch()
        conditional.tempo = 120; conditional.drums = false
        for i in 0..<16 { conditional.steps[i].every = 2 }
        var conditionalDSP = GrooveDSP(sampleRate: 44_100)
        var energyByBar = [0.0, 0.0, 0.0]
        for bar in 0..<3 {
            for frame in 0..<88_200 {
                let value = Double(conditionalDSP.nextSample(conditional))
                if frame > 44_100 { energyByBar[bar] += value * value }
            }
        }
        precondition(energyByBar[0] > 1 && energyByBar[1] < 0.00001 && energyByBar[2] > 1)
        // Old slots have no tone payload: retain the original acid instrument.
        var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(GroovePatch())) as! [String: Any]
        legacy.removeValue(forKey: "tone")
        let oldSave = try JSONDecoder().decode(GroovePatch.self, from: JSONSerialization.data(withJSONObject: legacy))
        precondition(oldSave.tone == ToneSettings() && oldSave.isValid)
        var modelSignatures: [Double] = []
        for model in 1...4 {
            var patch = GroovePatch()
            patch.applyTone(model)
            patch.drums = false
            patch.steps = (0..<16).map { GrooveStep(note: 7, enabled: $0 == 0) }
            precondition(patch.isValid)
            let decoded = try JSONDecoder().decode(GroovePatch.self, from: JSONEncoder().encode(patch))
            precondition(decoded == patch)
            var dsp = GrooveDSP(sampleRate: 44_100)
            var rendered: [Float] = []
            var energy = 0.0
            for frame in 0..<88_200 {
                let sample = dsp.nextSample(patch)
                precondition(sample.isFinite && abs(sample) <= 0.85)
                if frame < 4000 { rendered.append(sample) }
                energy += Double(sample * sample)
            }
            precondition(energy > 1, "Every instrument must be audible")
            modelSignatures.append(energy)
            dsp.reset()
            for expected in rendered {
                precondition(dsp.nextSample(patch) == expected, "Restart must clear echo and oscillator state")
            }
            for i in 0..<16 { patch.steps[i].enabled = false }
            dsp.reset()
            for _ in 0..<44_100 { precondition(dsp.nextSample(patch) == 0, "No ghost notes before first trigger") }
            // Max-register stress at both supported test rates.
            patch.steps[0].enabled = true; patch.steps[0].note = 24
            patch.tone.octave = 3; patch.tone.color = 1; patch.tone.bloom = 1
            patch.tone.motion = 1; patch.tone.space = 0.6; patch.tone.tail = 3
            patch.resonance = 10; patch.drive = 1
            for rate in [44_100.0, 48_000.0] {
                var extremeDSP = GrooveDSP(sampleRate: rate)
                for _ in 0..<48_000 {
                    let sample = extremeDSP.nextSample(patch)
                    precondition(sample.isFinite && abs(sample) <= 0.85)
                }
            }
        }
        precondition(Set(modelSignatures).count == 4, "Instrument models must produce different signals")
        var luma = GroovePatch.preset(3)
        luma.drums = false
        for control in 0...2 {
            var changed = luma
            if control == 0 { changed.tone.color = 0.95 }
            if control == 1 { changed.tone.bloom = 0.05 }
            if control == 2 { changed.tone.motion = 0.95 }
            var baseline = GrooveDSP(sampleRate: 44_100)
            var altered = GrooveDSP(sampleRate: 44_100)
            var delta = 0.0
            for _ in 0..<44_100 {
                delta += abs(Double(baseline.nextSample(luma) - altered.nextSample(changed)))
            }
            precondition(delta > 1, "Every LUMA-7 macro must change the sound")
        }
        for chord in 0...8 {
            var patch = GroovePatch.preset(6)
            patch.tone.pad?.chord = chord
            patch.tone.pad?.attack = 0.01
            patch.tone.pad?.holdBeats = 0.25
            patch.tone.pad?.release = 0.1
            patch.steps = (0..<16).map { GrooveStep(note: 0, enabled: $0 == 0) }
            var dsp = GrooveDSP(sampleRate: 44_100)
            _ = dsp.nextSample(patch)
            precondition(dsp.activeLumaVoices == LumaHarmony.count(chord))
            for _ in 0..<30_000 { _ = dsp.nextSample(patch, triggerNotes: false) }
            precondition(dsp.activeLumaVoices == 0, "Released voices must retire")
        }
        precondition((0..<4).map { LumaHarmony.interval(4, voice: $0, spread: 0) } == [0, 4, 7, 11])
        precondition((0..<5).map { LumaHarmony.interval(8, voice: $0, spread: 0) } == [0, 3, 7, 10, 14])
        var pad = GroovePatch.preset(6)
        pad.tempo = 120
        pad.tone.pad?.holdBeats = 2
        pad.tone.pad?.release = 1
        pad.tone.pad?.attack = 0.1
        pad.steps = (0..<16).map { GrooveStep(note: $0 == 4 ? 5 : 0, enabled: $0 == 0 || $0 == 4) }
        pad.steps[0].chord = 1; pad.steps[4].chord = 4
        let savedPad = try JSONDecoder().decode(GroovePatch.self, from: JSONEncoder().encode(pad))
        precondition(savedPad == pad && savedPad.isValid)
        var poly = GrooveDSP(sampleRate: 44_100)
        var firstFrames: [Float] = []
        for _ in 0..<22_051 { firstFrames.append(poly.nextSample(pad)) }
        precondition(poly.activeLumaVoices == 7, "Previous chord must overlap the next chord")
        poly.releaseLumaVoices()
        var tailEnergy = 0.0
        for _ in 0..<44_200 {
            let value = poly.nextSample(pad, triggerNotes: false)
            tailEnergy += Double(value * value)
        }
        precondition(tailEnergy > 1 && poly.activeLumaVoices == 0)
        poly.reset()
        for expected in firstFrames { precondition(poly.nextSample(pad) == expected) }
        for i in 0..<16 { pad.steps[i].enabled = true; pad.steps[i].chord = 8 }
        pad.tone.pad?.holdBeats = 8; pad.tone.pad?.release = 6
        pad.tone.pad?.attack = 0.005; pad.tone.pad?.detune = 15
        pad.tone.octave = 3; pad.tone.pad?.spread = 2
        for rate in [44_100.0, 48_000.0] {
            var busy = GrooveDSP(sampleRate: rate)
            var reachedLimit = false
            for _ in 0..<Int(rate * 3) {
                let value = busy.nextSample(pad)
                precondition(value.isFinite && abs(value) <= 0.85)
                precondition(busy.activeLumaVoices <= 24)
                reachedLimit = reachedLimit || busy.activeLumaVoices == 24
            }
            precondition(reachedLimit, "Dense chords must exercise bounded voice stealing")
        }
        var legacyTone = try JSONSerialization.jsonObject(with: JSONEncoder().encode(GroovePatch.preset(3))) as! [String: Any]
        var toneObject = legacyTone["tone"] as! [String: Any]
        toneObject.removeValue(forKey: "pad"); legacyTone["tone"] = toneObject
        let monoSave = try JSONDecoder().decode(GroovePatch.self, from: JSONSerialization.data(withJSONObject: legacyTone))
        precondition(monoSave.tone.pad == nil && monoSave.isValid)
        var badPad = pad; badPad.tone.pad?.release = .nan
        precondition(!badPad.isValid)
        badPad = pad; badPad.steps[0].chord = 99
        precondition(!badPad.isValid)
        print("PASS: chord intervals, independent overlapping voices, attack/release retirement, tail rendering, 24-voice limit, reset and legacy mono migration")
        print("PASS: legacy saves, modeled instruments, LUMA-7 macros, tails/reset, silence and high-register stability")
        print("PASS: Euclidean spacing, lane isolation, scale mutation, probability, cutoff locks, loop conditions")
        print("PASS: presets, persistence, validation, sample timing, swing, silence, output bounds, deterministic rendering")
    }
}
