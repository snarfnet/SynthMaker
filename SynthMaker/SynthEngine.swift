import SwiftUI
import AVFoundation
import AudioToolbox

final class SynthEngine: NSObject, ObservableObject {
    @Published var patch = GroovePatch() { didSet { publishSettings() } }
    @Published private(set) var isPlaying = false
    @Published private(set) var currentStep = -1
    @Published var message: String?
    @Published private(set) var isExporting = false
    @Published var exportURL: URL?
    @Published private(set) var canUndo = false
    private var undoPatch: GroovePatch?

    private var audioEngine = AVAudioEngine()
    private let mailbox = NSLock()
    private var pending = GroovePatch()
    private var requestedPlay = false
    private var revision = 0
    private var reportedStep = -1
    // Only the audio callback accesses the render state below.
    private var cached = GroovePatch()
    private var renderPlay = false
    private var renderRevision = -1
    private var dsp = GrooveDSP(sampleRate: 44_100)
    private var fade = 0.0
    private var configured = false
    private var displayTimer: Timer?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(interrupted),
            name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(routeChanged),
            name: AVAudioSession.routeChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(mediaReset),
            name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(configurationChanged),
            name: .AVAudioEngineConfigurationChange, object: nil)
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.mailbox.lock()
            let step = self.reportedStep
            self.mailbox.unlock()
            self.currentStep = self.isPlaying ? step : -1
        }
    }

    private func publishSettings() {
        mailbox.lock()
        pending = patch
        mailbox.unlock()
    }

    func play() {
        guard patch.isValid else { message = "Invalid pattern settings."; return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
            if !configured {
                let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
                let source = AVAudioSourceNode(format: format) { [weak self] _, _, count, buffers in
                    guard let self = self else {
                        for buffer in UnsafeMutableAudioBufferListPointer(buffers) {
                            if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) }
                        }
                        return noErr
                    }
                    self.render(count, buffers)
                    return noErr
                }
                audioEngine.attach(source)
                audioEngine.connect(source, to: audioEngine.mainMixerNode, format: format)
                configured = true
            }
            if !audioEngine.isRunning { try audioEngine.start() }
            mailbox.lock()
            pending = patch
            requestedPlay = true
            revision += 1
            mailbox.unlock()
            isPlaying = true
        } catch {
            stop()
            message = "Audio could not start: \(error.localizedDescription)"
        }
    }

    func stop() {
        mailbox.lock()
        requestedPlay = false
        mailbox.unlock()
        isPlaying = false
        currentStep = -1
    }

    private func render(_ count: AVAudioFrameCount, _ buffers: UnsafeMutablePointer<AudioBufferList>) {
        // Never wait for the UI thread: keep the previous settings if a write is in progress.
        if mailbox.try() {
            cached = pending
            renderPlay = requestedPlay
            if renderRevision != revision {
                dsp = GrooveDSP(sampleRate: 44_100)
                fade = 0
                renderRevision = revision
            }
            reportedStep = renderPlay ? dsp.stepIndex : -1
            mailbox.unlock()
        }
        let list = UnsafeMutableAudioBufferListPointer(buffers)
        for i in 0..<Int(count) {
            fade += ((renderPlay ? 1.0 : 0.0) - fade) * 0.005
            let value = (renderPlay || fade > 0.00001) ? dsp.nextSample(cached) * Float(fade) : 0
            for buffer in list { buffer.mData?.assumingMemoryBound(to: Float.self)[i] = value }
        }
    }

    func generateRhythm(pulses: Int, rotation: Int, lane: Int) {
        undoPatch = patch
        canUndo = true
        patch.generateRhythm(pulses: pulses, rotation: rotation, lane: lane)
    }

    func mutate() {
        undoPatch = patch
        canUndo = true
        patch.mutate(seed: UInt64.random(in: 0...UInt64.max))
    }

    func undoGeneration() {
        guard let previous = undoPatch else { return }
        patch = previous
        undoPatch = nil
        canUndo = false
    }

    func replacePatch(_ replacement: GroovePatch) {
        stop()
        undoPatch = patch
        canUndo = true
        patch = replacement
    }

    func save(slot: Int) {
        do {
            let data = try JSONEncoder().encode(patch)
            UserDefaults.standard.set(data, forKey: "groove.v1.slot.\(slot)")
            message = "Saved to slot \(slot)."
        } catch { message = "Could not save: \(error.localizedDescription)" }
    }

    func load(slot: Int) {
        guard let data = UserDefaults.standard.data(forKey: "groove.v1.slot.\(slot)") else {
            message = "Slot \(slot) is empty."; return
        }
        do {
            let saved = try JSONDecoder().decode(GroovePatch.self, from: data)
            guard saved.isValid else { message = "This saved pattern is invalid."; return }
            replacePatch(saved)
        } catch { message = "Could not load: \(error.localizedDescription)" }
    }

    func exportWAV() {
        guard !isExporting, patch.isValid else { return }
        isExporting = true
        let snapshot = patch
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let url = try Self.writeWAV(snapshot)
                DispatchQueue.main.async { self?.isExporting = false; self?.exportURL = url }
            } catch {
                DispatchQueue.main.async {
                    self?.isExporting = false
                    self?.message = "Export failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private static func writeWAV(_ snapshot: GroovePatch) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("SynthMaker-Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("SynthMaker-\(UUID().uuidString.prefix(8)).wav")
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        var renderer = GrooveDSP(sampleRate: 44_100)
        let frames = Int((44_100 * 60 / snapshot.tempo * 16).rounded()) // Four bars.
        var position = 0
        while position < frames {
            let length = min(1024, frames - position)
            buffer.frameLength = AVAudioFrameCount(length)
            for i in 0..<length {
                // Short edge fades prevent clicks in the exported file.
                let fade = min(1, min(Double(position + i) / 220, Double(frames - position - i - 1) / 220))
                buffer.floatChannelData![0][i] = renderer.nextSample(snapshot) * Float(fade)
            }
            try file.write(from: buffer)
            position += length
        }
        return url
    }

    @objc private func interrupted(_ notification: Notification) {
        guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              type == AVAudioSession.InterruptionType.began.rawValue else { return }
        DispatchQueue.main.async { [weak self] in self?.stop() }
    }

    @objc private func routeChanged(_ notification: Notification) {
        guard let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
        DispatchQueue.main.async { [weak self] in self?.stop() }
    }

    @objc private func mediaReset(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.stop()
            self?.audioEngine.stop()
            self?.audioEngine = AVAudioEngine()
            self?.configured = false
            self?.message = "Audio service restarted. Press Play to reconnect audio."
        }
    }

    @objc private func configurationChanged(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.audioEngine.isRunning else { return }
            self.stop()
        }
    }

    deinit {
        displayTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        audioEngine.stop()
    }
}
