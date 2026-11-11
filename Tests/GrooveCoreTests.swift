import Foundation

@main
struct GrooveCoreTests {
    static func main() throws {
        for index in 0...2 {
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
        print("PASS: presets, persistence, validation, sample timing, swing, silence, output bounds, deterministic rendering")
    }
}
