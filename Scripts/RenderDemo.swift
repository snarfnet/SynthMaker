import Foundation

@main
struct RenderDemo {
    static func main() throws {
        guard (2...3).contains(CommandLine.arguments.count) else { fatalError("Pass the output WAV path") }
        var patch = GroovePatch.preset(1)
        patch.generateRhythm(pulses: 7, rotation: 0, lane: 0)
        patch.steps[2].probability = 0.6
        patch.steps[6].every = 2
        patch.steps[10].cutoffLock = 4200
        patch.steps[14].cutoffLock = 180
        let model = CommandLine.arguments.count == 3 ? Int(CommandLine.arguments[2]) ?? 0 : 0
        if model > 0 {
            patch = .preset(3)
            patch.applyTone(model)
            patch.drums = false
            if model == 4 { patch.tone.bloom = 0.8; patch.tone.motion = 0.35 }
        }
        if model == 6 || model == 7 { patch = .preset(model) }
        var dsp = GrooveDSP(sampleRate: 44_100)
        let musicalFrames = Int((44_100 * 60 / patch.tempo * (model > 0 ? 16 : 32)).rounded())
        let frames = musicalFrames + (model > 0 ? Int(44_100 * ((patch.tone.pad?.release ?? 0) + 2)) : 0)
        var pcm = Data(capacity: frames * 2)
        for frame in 0..<frames {
            if frame == musicalFrames { dsp.releaseLumaVoices() }
            let fade = min(1, min(Double(frame) / 220, Double(frames - frame - 1) / 220))
            var sample = Int16((Double(dsp.nextSample(patch, triggerNotes: frame < musicalFrames)) * fade * 32767).rounded()).littleEndian
            withUnsafeBytes(of: &sample) { pcm.append(contentsOf: $0) }
        }
        var wav = Data()
        func label(_ text: String) { wav.append(contentsOf: text.utf8) }
        func u32(_ number: UInt32) {
            var value = number.littleEndian
            withUnsafeBytes(of: &value) { wav.append(contentsOf: $0) }
        }
        func u16(_ number: UInt16) {
            var value = number.littleEndian
            withUnsafeBytes(of: &value) { wav.append(contentsOf: $0) }
        }
        label("RIFF"); u32(UInt32(36 + pcm.count)); label("WAVE")
        label("fmt "); u32(16); u16(1); u16(1); u32(44_100); u32(88_200); u16(2); u16(16)
        label("data"); u32(UInt32(pcm.count)); wav.append(pcm)
        try wav.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        print("Rendered model \(model) using the app DSP: \(frames) frames")
    }
}
