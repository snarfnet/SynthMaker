import SwiftUI
import AVFoundation

final class SynthEngine: NSObject, ObservableObject {
    @Published var frequency: Double = 440
    @Published var waveform: Double = 0
    @Published var filterCutoff: Double = 2000 {
        didSet { updateFilter() }
    }
    @Published var resonance: Double = 1 {
        didSet { updateFilter() }
    }
    @Published var envelopeAmount: Double = 0.5
    @Published var attack: Double = 0.01
    @Published var decay: Double = 0.1
    @Published var sustain: Double = 0.7
    @Published var release: Double = 0.2

    private let audioEngine = AVAudioEngine()
    private var oscillatorNode: AVAudioUnitSampler?
    private var filterNode: AVAudioUnitEQ?
    private var activeNote: UInt8?
    private var isRunning = false

    override init() {
        super.init()
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(.playback, options: .duckOthers)
            try audioSession.setActive(true)

            let oscillator = AVAudioUnitSampler()
            let filter = AVAudioUnitEQ(numberOfBands: 1)

            filter.bands[0].filterType = .lowPass
            filter.bands[0].frequency = Float(filterCutoff)
            filter.bands[0].bandwidth = 1.0
            filter.bands[0].gain = 0

            audioEngine.attach(oscillator)
            audioEngine.attach(filter)
            audioEngine.connect(oscillator, to: filter, format: nil)
            audioEngine.connect(filter, to: audioEngine.mainMixerNode, format: nil)

            try audioEngine.start()

            oscillatorNode = oscillator
            filterNode = filter
            isRunning = true
        } catch {
            print("Error setting up audio engine: \(error)")
        }
    }

    func playNote(frequency: Double) {
        self.frequency = frequency
        updateFilter()

        guard isRunning, let oscillatorNode else { return }

        if let activeNote {
            oscillatorNode.stopNote(activeNote, onChannel: 0)
        }

        let midiNote = midiNoteNumber(for: frequency)
        activeNote = midiNote
        oscillatorNode.startNote(midiNote, withVelocity: 108, onChannel: 0)

        let gateLength = max(0.08, min(1.2, decay + release + 0.08))
        DispatchQueue.main.asyncAfter(deadline: .now() + gateLength) { [weak self] in
            guard self?.activeNote == midiNote else { return }
            oscillatorNode.stopNote(midiNote, onChannel: 0)
            self?.activeNote = nil
        }
    }

    private func updateFilter() {
        guard let band = filterNode?.bands.first else { return }

        band.frequency = Float(filterCutoff)
        band.bandwidth = Float(max(0.05, 1.4 - resonance * 0.11))
    }

    private func midiNoteNumber(for frequency: Double) -> UInt8 {
        let rawValue = 69 + 12 * log2(frequency / 440.0)
        let clamped = min(127, max(0, Int(rawValue.rounded())))
        return UInt8(clamped)
    }

    deinit {
        audioEngine.stop()
    }
}
