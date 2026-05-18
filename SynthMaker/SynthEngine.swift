import SwiftUI
import AVFoundation
import AudioToolbox

final class SynthEngine: NSObject, ObservableObject {
    @Published var frequency: Double = 440 {
        didSet { updateRenderSettings() }
    }
    @Published var waveform: Double = 0 {
        didSet { updateRenderSettings() }
    }
    @Published var filterCutoff: Double = 2000 {
        didSet { updateFilter() }
    }
    @Published var resonance: Double = 1 {
        didSet { updateFilter() }
    }
    @Published var envelopeAmount: Double = 0.5 {
        didSet { updateRenderSettings() }
    }
    @Published var attack: Double = 0.01 {
        didSet { updateRenderSettings() }
    }
    @Published var decay: Double = 0.1 {
        didSet { updateRenderSettings() }
    }
    @Published var sustain: Double = 0.7 {
        didSet { updateRenderSettings() }
    }
    @Published var release: Double = 0.2 {
        didSet { updateRenderSettings() }
    }

    private struct RenderState {
        var frequency: Double = 440
        var waveform: Int = 0
        var envelopeAmount: Double = 0.5
        var attack: Double = 0.01
        var decay: Double = 0.1
        var sustain: Double = 0.7
        var release: Double = 0.2
        var phase: Double = 0
        var sampleRate: Double = 44_100
        var samplePosition: UInt64 = 0
        var noteOnSample: UInt64?
        var releaseStartSample: UInt64?
        var releaseStartLevel: Double = 0
    }

    private let audioEngine = AVAudioEngine()
    private let stateLock = NSLock()
    private var renderState = RenderState()
    private var filterNode: AVAudioUnitEQ?
    private var currentNoteID = 0
    private var isRunning = false

    override init() {
        super.init()
    }

    private func setupAudioEngine() {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(.playback, options: [.duckOthers])
            try audioSession.setPreferredSampleRate(44_100)
            try audioSession.setPreferredIOBufferDuration(0.005)
            try audioSession.setActive(true)

            let sampleRate = audioSession.sampleRate > 0 ? audioSession.sampleRate : 44_100
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

            stateLock.lock()
            renderState.sampleRate = sampleRate
            stateLock.unlock()

            let oscillator = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList in
                self?.render(frameCount: frameCount, audioBufferList: audioBufferList)
                return noErr
            }

            let filter = AVAudioUnitEQ(numberOfBands: 1)
            filter.bands[0].filterType = .lowPass
            filter.bands[0].frequency = Float(filterCutoff)
            filter.bands[0].bandwidth = 1.0
            filter.bands[0].gain = 0

            audioEngine.attach(oscillator)
            audioEngine.attach(filter)
            audioEngine.connect(oscillator, to: filter, format: format)
            audioEngine.connect(filter, to: audioEngine.mainMixerNode, format: format)

            try audioEngine.start()

            filterNode = filter
            isRunning = true
        } catch {
            print("Error setting up audio engine: \(error)")
        }
    }

    func playNote(frequency: Double) {
        self.frequency = frequency
        updateFilter()

        if !isRunning {
            setupAudioEngine()
        }

        guard isRunning else { return }

        stateLock.lock()
        currentNoteID += 1
        let noteID = currentNoteID
        renderState.frequency = frequency
        renderState.waveform = Int(waveform.rounded())
        renderState.noteOnSample = renderState.samplePosition
        renderState.releaseStartSample = nil
        renderState.releaseStartLevel = 0
        stateLock.unlock()

        let gateLength = max(0.08, min(1.2, attack + decay + release + 0.08))
        DispatchQueue.main.asyncAfter(deadline: .now() + gateLength) { [weak self] in
            self?.beginRelease(for: noteID)
        }
    }

    private func render(frameCount: AVAudioFrameCount, audioBufferList: UnsafeMutablePointer<AudioBufferList>) {
        stateLock.lock()
        var state = renderState
        stateLock.unlock()

        let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)

        for frame in 0..<Int(frameCount) {
            let level = envelopeLevel(for: state, at: state.samplePosition)
            let oscillator = sampleValue(phase: state.phase, waveform: state.waveform)
            let output = Float(oscillator * level * (0.18 + state.envelopeAmount * 0.26))

            for buffer in bufferList {
                let pointer = buffer.mData?.assumingMemoryBound(to: Float.self)
                pointer?[frame] = output
            }

            state.phase += state.frequency / state.sampleRate
            if state.phase >= 1 {
                state.phase -= floor(state.phase)
            }

            state.samplePosition += 1
        }

        stateLock.lock()
        renderState.phase = state.phase
        renderState.samplePosition = state.samplePosition
        stateLock.unlock()
    }

    private func sampleValue(phase: Double, waveform: Int) -> Double {
        switch min(max(waveform, 0), 3) {
        case 0:
            return phase * 2 - 1
        case 1:
            return phase < 0.5 ? 1 : -1
        case 2:
            return 1 - 4 * abs(phase - 0.5)
        default:
            return sin(phase * 2 * .pi)
        }
    }

    private func envelopeLevel(for state: RenderState, at samplePosition: UInt64) -> Double {
        guard let noteOnSample = state.noteOnSample else { return 0 }

        if let releaseStartSample = state.releaseStartSample {
            let elapsed = seconds(from: releaseStartSample, to: samplePosition, sampleRate: state.sampleRate)
            guard state.release > 0 else { return 0 }
            return max(0, state.releaseStartLevel * (1 - elapsed / state.release))
        }

        let elapsed = seconds(from: noteOnSample, to: samplePosition, sampleRate: state.sampleRate)
        if elapsed < state.attack {
            guard state.attack > 0 else { return 1 }
            return elapsed / state.attack
        }

        let decayElapsed = elapsed - state.attack
        if decayElapsed < state.decay {
            guard state.decay > 0 else { return state.sustain }
            let decayProgress = decayElapsed / state.decay
            return 1 - (1 - state.sustain) * decayProgress
        }

        return state.sustain
    }

    private func seconds(from start: UInt64, to end: UInt64, sampleRate: Double) -> Double {
        Double(end >= start ? end - start : 0) / sampleRate
    }

    private func beginRelease(for noteID: Int) {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard noteID == currentNoteID, renderState.releaseStartSample == nil else { return }

        renderState.releaseStartSample = renderState.samplePosition
        renderState.releaseStartLevel = envelopeLevel(for: renderState, at: renderState.samplePosition)
    }

    private func updateRenderSettings() {
        stateLock.lock()
        renderState.frequency = frequency
        renderState.waveform = Int(waveform.rounded())
        renderState.envelopeAmount = envelopeAmount
        renderState.attack = attack
        renderState.decay = decay
        renderState.sustain = sustain
        renderState.release = release
        stateLock.unlock()
    }

    private func updateFilter() {
        guard let band = filterNode?.bands.first else { return }

        band.frequency = Float(filterCutoff)
        band.bandwidth = Float(max(0.05, 1.4 - resonance * 0.11))
    }

    deinit {
        audioEngine.stop()
    }
}
