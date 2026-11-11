import Foundation

@main
struct RenderDemo {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else { fatalError("Pass the output WAV path") }
        var patch = GroovePatch.preset(1)
        patch.generateRhythm(pulses: 7, rotation: 0, lane: 0)
        patch.steps[2].probability = 0.6
        patch.steps[6].every = 2
        patch.steps[10].cutoffLock = 4200
        patch.steps[14].cutoffLock = 180
        var dsp = GrooveDSP(sampleRate: 44_100)
        let frames = Int((44_100 * 60 / patch.tempo * 32).rounded())
        var pcm = Data(capacity: frames * 2)
        for frame in 0..<frames {
            let fade = min(1, min(Double(frame) / 220, Double(frames - frame - 1) / 220))
            var sample = Int16((Double(dsp.nextSample(patch)) * fade * 32767).rounded()).littleEndian
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
        print("Rendered 8 bars at 138 BPM using the app DSP: \(frames) frames")
    }
}
