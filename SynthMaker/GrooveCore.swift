import Foundation

struct GrooveStep: Codable, Equatable {
    var note = 0
    var enabled = true
    var accent = false
    var slide = false
    var kick = false
    var hat = false
    var probability = 1.0
    var every = 1
    var cutoffLock: Double?
    var chord: Int?
}

struct ToneSettings: Codable, Equatable {
    // 0: Acid, 1: Warm analog, 2: FM glass, 3: FM keys, 4: original LUMA-7.
    var pad: LumaPadSettings?
    var model = 0
    var octave = 0
    var color = 0.4
    var bloom = 0.5
    var motion = 0.25
    var tail = 0.8
    var space = 0.0

    var isValid: Bool {
        (pad?.isValid ?? true) && (0...4).contains(model) && (0...3).contains(octave)
            && (0...1).contains(color) && (0...1).contains(bloom)
            && (0...1).contains(motion) && (0.1...3).contains(tail)
            && (0...0.6).contains(space)
    }
}

struct GroovePatch: Codable, Equatable {
    var tone = ToneSettings()
    var tempo = 130.0
    var swing = 0.0
    var cutoff = 1100.0
    var resonance = 4.0
    var envMod = 0.65
    var decay = 0.18
    var drive = 0.3
    var waveform = 0
    var drums = true
    var steps: [GrooveStep] = (0..<16).map { index in
        GrooveStep(note: [0, 0, 12, 0, 7, 0, 10, 12, 0, 3, 0, 7, 12, 10, 7, 3][index],
                   enabled: index % 4 != 1, accent: index % 4 == 0,
                   slide: index == 6 || index == 14, kick: index % 4 == 0,
                   hat: index % 2 == 0)
    }

    init() {}

    private enum CodingKeys: String, CodingKey {
        case tone, tempo, swing, cutoff, resonance, envMod, decay, drive, waveform, drums, steps
    }

    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tone = try c.decodeIfPresent(ToneSettings.self, forKey: .tone) ?? ToneSettings()
        tempo = try c.decode(Double.self, forKey: .tempo)
        swing = try c.decode(Double.self, forKey: .swing)
        cutoff = try c.decode(Double.self, forKey: .cutoff)
        resonance = try c.decode(Double.self, forKey: .resonance)
        envMod = try c.decode(Double.self, forKey: .envMod)
        decay = try c.decode(Double.self, forKey: .decay)
        drive = try c.decode(Double.self, forKey: .drive)
        waveform = try c.decode(Int.self, forKey: .waveform)
        drums = try c.decode(Bool.self, forKey: .drums)
        steps = try c.decode([GrooveStep].self, forKey: .steps)
    }

    mutating func applyTone(_ model: Int) {
        tone = ToneSettings()
        tone.model = model
        tone.octave = model == 0 ? 0 : 2
        tone.space = model == 0 ? 0 : 0.24
        tone.tail = model == 1 ? 0.5 : 1.2
        tone.color = model == 3 ? 0.25 : 0.45
        cutoff = model == 0 ? 1100 : 6500
        resonance = model == 0 ? 4 : 0.8
        envMod = model == 0 ? 0.65 : 0.15
        drive = model == 0 ? 0.3 : 0.04
    }

    var isValid: Bool {
        tone.isValid && steps.count == 16 && (60...180).contains(tempo) && (0...0.45).contains(swing)
            && (40...12000).contains(cutoff) && (0...10).contains(resonance)
            && (0...1).contains(envMod) && (0.03...1).contains(decay)
            && (0...1).contains(drive) && (0...3).contains(waveform)
            && steps.allSatisfy {
                (-12...24).contains($0.note) && (0...1).contains($0.probability)
                    && [1, 2, 4].contains($0.every)
                    && ($0.cutoffLock == nil || (40...12000).contains($0.cutoffLock!))
                    && ($0.chord == nil || (0...8).contains($0.chord!))
            }
    }

    // Distribute hits as evenly as possible. Rotation moves the pattern around the bar.
    static func euclidean(pulses: Int, rotation: Int) -> [Bool] {
        let hits = min(16, max(0, pulses))
        let offset = (rotation % 16 + 16) % 16
        return (0..<16).map { ((($0 - offset + 16) % 16) * hits) % 16 < hits }
    }

    mutating func generateRhythm(pulses: Int, rotation: Int, lane: Int) {
        let rhythm = Self.euclidean(pulses: pulses, rotation: rotation)
        for i in steps.indices {
            switch lane {
            case 1: steps[i].kick = rhythm[i]
            case 2: steps[i].hat = rhythm[i]
            default: steps[i].enabled = rhythm[i]
            }
        }
    }

    mutating func mutate(seed: UInt64) {
        let scale = [0, 3, 5, 7, 10, 12] // A minor pentatonic: every generated pitch fits the key.
        var state = seed
        for i in steps.indices {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            if (state >> 32) % 3 == 0 {
                steps[i].note = scale[Int((state >> 40) % UInt64(scale.count))]
                steps[i].accent = (state & 1) == 0
                steps[i].slide = (state & 6) == 0
            }
        }
    }

    static func preset(_ index: Int) -> GroovePatch {
        var patch = GroovePatch()
        if index == 1 {
            patch.tempo = 138; patch.cutoff = 650; patch.resonance = 7; patch.drive = 0.65
            patch.steps = (0..<16).map { i in
                GrooveStep(note: [0, 12, 0, 3, 0, 7, 10, 12][i % 8],
                           enabled: i != 3 && i != 11, accent: i % 3 == 0,
                           slide: i % 4 == 2, kick: i % 4 == 0, hat: i % 2 == 0)
            }
        } else if index == 2 {
            patch.tempo = 122; patch.swing = 0.22; patch.cutoff = 1500
            patch.resonance = 2; patch.drive = 0.15; patch.waveform = 2
            patch.steps = (0..<16).map { i in
                GrooveStep(note: [0, 7, 10, 3][i / 4], enabled: i % 4 == 0 || i % 4 == 3,
                           accent: i % 4 == 0, kick: i % 4 == 0, hat: i % 4 == 2)
            }
        }
        if index >= 3 {
            patch.applyTone(index == 3 ? 4 : (index == 4 ? 2 : 3))
            patch.tempo = 118
            patch.steps = (0..<16).map { i in
                GrooveStep(note: [0, 7, 10, 3][i / 4], enabled: i % 4 == 0,
                           accent: i == 0, kick: i % 4 == 0, hat: i % 4 == 2)
            }
            if index == 3 { patch.tone.bloom = 0.8; patch.tone.motion = 0.35 }
        }
        if index >= 6 {
            patch.applyTone(4)
            patch.tempo = index == 6 ? 96 : 120
            patch.drums = index != 6
            patch.tone.pad = LumaPadSettings()
            patch.tone.pad?.attack = index == 6 ? 0.7 : 0.03
            patch.tone.pad?.release = index == 6 ? 2.8 : 0.6
            patch.tone.pad?.holdBeats = index == 6 ? 1 : 0.25
            patch.tone.pad?.spread = 1
            patch.tone.bloom = 0.8; patch.tone.color = 0.2; patch.tone.space = 0.3
            patch.envMod = 0.05; patch.cutoff = 4200
            patch.steps = (0..<16).map { i in
                var step = GrooveStep(note: [0, 5, 3, 7][i / 4], enabled: i % 4 == 0,
                                      kick: i % 4 == 0, hat: i % 4 == 2)
                step.chord = [3, 3, 4, 3][i / 4]
                return step
            }
        }
        return patch
    }
}

// The audio thread owns this state. No timers, locks, allocation or UI calls occur in nextSample.
struct GrooveDSP {
    let sampleRate: Double
    private(set) var stepIndex = -1
    private(set) var stepCount = 0
    private var remaining = 0.0
    private var duration = 1.0
    private var elapsed = 0.0
    private var phase = 0.0
    private var secondPhase = 0.0
    private var lumaPhases = SevenPhases()
    private var hasToneVoice = false
    private var modulatorPhase = 0.0
    private var motionPhase = 0.0
    private var voiceAge = 100.0
    private var voiceAccent = false
    private var toneEnvelope = 0.0
    private let echo: GrooveEcho
    private let lumaBank: LumaPolyphony
    private var wasPolyphonic = false
    var activeLumaVoices: Int { lumaBank.activeCount }
    private var frequency = 55.0
    private var targetFrequency = 55.0
    private var envelope = 0.0
    private var accent = false
    private var slide = false
    private var active = false
    private var low = 0.0
    private var band = 0.0
    private var g = 0.0
    private var filterTick = 0
    private var kickAge = 100.0
    private var kickPhase = 0.0
    private var hatAge = 100.0
    private var lastNoise = 0.0
    private var chanceState: UInt32 = 0xABCDEF01
    private var lockedCutoff: Double?
    private var noiseState: UInt32 = 0x12345678

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        self.echo = GrooveEcho(sampleRate: sampleRate)
        self.lumaBank = LumaPolyphony(sampleRate: sampleRate)
    }

    private init(sampleRate: Double, echo: GrooveEcho, lumaBank: LumaPolyphony) {
        self.sampleRate = sampleRate
        self.echo = echo
        self.lumaBank = lumaBank
    }

    mutating func reset() {
        // Reuse the preallocated delay memory when transport restarts.
        echo.reset()
        lumaBank.reset()
        self = GrooveDSP(sampleRate: sampleRate, echo: echo, lumaBank: lumaBank)
    }

    func releaseLumaVoices() { lumaBank.releaseAll() }

    mutating func nextSample(_ patch: GroovePatch, triggerNotes: Bool = true) -> Float {
        let polyphonic = patch.tone.model == 4 && patch.tone.pad != nil
        if polyphonic != wasPolyphonic { lumaBank.reset(); wasPolyphonic = polyphonic }
        if remaining <= 0 {
            let previousSlide = slide && active
            stepIndex = (stepIndex + 1) % 16
            stepCount += 1
            let step = patch.steps[stepIndex]
            duration = sampleRate * 60 / patch.tempo / 4 * (stepIndex % 2 == 0 ? 1 + patch.swing : 1 - patch.swing)
            remaining += duration // Preserve fractional samples to avoid cumulative tempo drift.
            elapsed = 0
            chanceState = chanceState &* 1664525 &+ 1013904223
            let chance = Double(chanceState) / (Double(UInt32.max) + 1)
            let cycle = (stepCount - 1) / 16
            active = triggerNotes && step.enabled && chance < step.probability && cycle % step.every == 0
            lockedCutoff = step.cutoffLock
            filterTick = 0
            slide = step.slide
            accent = step.accent
            if active || patch.tone.model == 0 {
                targetFrequency = 55 * pow(2, Double(step.note) / 12 + Double(patch.tone.octave))
                if !previousSlide { frequency = targetFrequency }
            }
            if active && !previousSlide {
                hasToneVoice = true
                voiceAge = 0
                voiceAccent = step.accent
            }
            if active && !previousSlide { envelope = 0 }
            if polyphonic && active, let pad = patch.tone.pad {
                lumaBank.trigger(root: targetFrequency, chord: step.chord ?? pad.chord,
                                 settings: pad, tempo: patch.tempo, accent: step.accent)
            }
            if triggerNotes && patch.drums && step.kick { kickAge = 0; kickPhase = 0 }
            if triggerNotes && patch.drums && step.hat { hatAge = 0 }
        }
        let gate = active && (slide || elapsed < duration * 0.65)
        let targetLevel = gate ? 1.0 : 0.0
        envelope += (targetLevel - envelope) * (gate ? 0.012 : 0.003)
        frequency += (targetFrequency - frequency) * 0.002
        let dt = min(0.45, frequency / sampleRate)
        var osc: Double
        switch patch.waveform {
        case 1:
            let shifted = (phase + 0.5).truncatingRemainder(dividingBy: 1)
            osc = (phase < 0.5 ? 1.0 : -1.0) + blep(phase, dt) - blep(shifted, dt)
        case 2: osc = 1 - 4 * abs(phase - 0.5)
        case 3: osc = sin(2 * .pi * phase)
        default: osc = 2 * phase - 1 - blep(phase, dt)
        }
        var level = envelope
        if patch.tone.model != 0 && !polyphonic {
            let t = patch.tone
            motionPhase += (0.12 + t.motion * 0.9) / sampleRate
            motionPhase -= floor(motionPhase)
            let drift = sin(2 * .pi * motionPhase)
            secondPhase += dt * pow(2, (3 + t.motion * 9) / 1200)
            secondPhase -= floor(secondPhase)
            let ratio = t.model == 2 ? 2.41421356237 : 1.0
            modulatorPhase += dt * ratio
            modulatorPhase -= floor(modulatorPhase)
            let amplitude = hasToneVoice ? (1 - exp(-voiceAge * (t.model == 1 ? 35 : 600)))
                * exp(-voiceAge / t.tail) : 0
            switch t.model {
            case 1:
                let sawA = 2 * phase - 1 - blep(phase, dt)
                let secondDT = dt * pow(2, (3 + t.motion * 9) / 1200)
                let sawB = 2 * secondPhase - 1 - blep(secondPhase, secondDT)
                osc = (sawA + sawB) * (0.18 + t.color * 0.22)
                    - sin(2 * .pi * phase) * (0.64 - t.color * 0.44)
            case 2:
                let index = (0.2 + t.color * 2.4) * exp(-voiceAge / (0.08 + t.bloom * 1.4))
                osc = sin(2 * .pi * phase + sin(2 * .pi * modulatorPhase) * index)
            case 3:
                let index = (0.4 + t.color * 1.7) * exp(-voiceAge / (0.06 + t.bloom * 0.4))
                osc = 0.85 * sin(2 * .pi * phase + index * sin(4 * .pi * modulatorPhase))
                    + 0.15 * sin(6 * .pi * phase) * exp(-voiceAge * 12)
            default:
                // LUMA-7: seven independent-ratio partials with a delayed spectral bloom.
                // Each partial owns its phase so Color changes preserve phase continuity.
                let opening = (1 - exp(-voiceAge / (0.025 + t.bloom * 0.45)))
                    * exp(-voiceAge / (0.3 + t.tail))
                var spectrum = 0.0
                var normalization = 0.0
                for partial in 1...7 {
                    let h = Double(partial)
                    let stretch = h * sqrt(1 + t.color * 0.006 * (h * h - 1))
                    let brightness = partial == 1 ? 1 : (0.12 + opening * t.bloom * 1.8)
                    let weight = brightness / pow(h, 1.5 - t.color * 0.45)
                    let safeWeight = frequency * stretch < sampleRate * 0.4 ? weight : 0
                    let partialPhase = lumaPhases.advance(partial - 1, by: dt * stretch * (1 + drift * t.motion * 0.0015))
                    spectrum += sin(2 * .pi * partialPhase
                        + drift * t.motion * h * 0.12) * safeWeight
                    normalization += weight
                }
                osc = spectrum / max(1, normalization)
            }
            toneEnvelope += (amplitude - toneEnvelope) * 0.015
            level = toneEnvelope
        }
        phase += dt
        phase -= floor(phase)
        voiceAge = min(100, voiceAge + 1 / sampleRate)
        // A resonant TPT state-variable filter. Env Mod now moves the cutoff.
        if filterTick == 0 {
            let modulation = patch.envMod * 5000 * exp(-elapsed / sampleRate / patch.decay) * (accent ? 1.35 : 1)
            let hz = min(sampleRate * 0.4, (lockedCutoff ?? patch.cutoff) + modulation)
            g = tan(.pi * hz / sampleRate)
        }
        filterTick = (filterTick + 1) % 32
        let k = 1 / (0.7 + patch.resonance * 0.7)
        let input = polyphonic ? lumaBank.render(patch.tone) : osc * level * (patch.tone.model == 0 ? (accent ? 0.32 : 0.23) : (voiceAccent ? 0.65 : 0.52))
        let v1 = (band + g * (input - low)) / (1 + g * (g + k))
        let v2 = low + g * v1
        band = 2 * v1 - band
        low = 2 * v2 - low
        let dry = tanh(v2 * (1 + patch.drive * 7)) * 0.5
        let echoSample = echo.process(dry, tempo: patch.tempo)
        var output = dry + echoSample * patch.tone.space
        if patch.drums {
            let kickFrequency = 48 + 110 * exp(-kickAge * 35)
            kickPhase += kickFrequency / sampleRate
            kickPhase -= floor(kickPhase)
            output += sin(2 * .pi * kickPhase) * exp(-kickAge * 14) * 0.55
            noiseState = noiseState &* 1664525 &+ 1013904223
            let noise = Double(noiseState) / Double(UInt32.max) * 2 - 1
            output += (noise - lastNoise) * exp(-hatAge * 70) * 0.12
            lastNoise = noise
        }
        kickAge += 1 / sampleRate; hatAge += 1 / sampleRate
        elapsed += 1; remaining -= 1
        return Float(tanh(output) * 0.85)
    }

    private func blep(_ t: Double, _ dt: Double) -> Double {
        if t < dt { let x = t / dt; return x + x - x * x - 1 }
        if t > 1 - dt { let x = (t - 1) / dt; return x * x + x + x + 1 }
        return 0
    }
}

// A damped, softly saturated dotted-eighth echo. This is not a convolution reverb.
// Storage is allocated once; reset invalidates history without clearing/allocating in render.
private final class GrooveEcho {
    private let sampleRate: Double
    private var memory: [Double]
    private var index = 0
    private var valid = 0
    private var delayed = 0.0
    private var filtered = 0.0

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        memory = Array(repeating: 0, count: Int(sampleRate * 2) + 2)
    }

    func reset() {
        index = 0; valid = 0; delayed = 0; filtered = 0
    }

    func process(_ input: Double, tempo: Double) -> Double {
        let target = sampleRate * 60 / tempo * 0.75
        delayed = delayed == 0 ? target : delayed + (target - delayed) * 0.0002
        var position = Double(index) - delayed
        if position < 0 { position += Double(memory.count) }
        let lower = Int(position)
        let upper = (lower + 1) % memory.count
        let fraction = position - Double(lower)
        let tap = valid > Int(ceil(delayed))
            ? memory[lower] * (1 - fraction) + memory[upper] * fraction : 0
        filtered += (tap - filtered) * 0.18
        memory[index] = tanh(input + filtered * 0.42)
        index = (index + 1) % memory.count
        valid = min(memory.count, valid + 1)
        return filtered
    }
}

// Value storage avoids allocating oscillator arrays on transport reset.
private struct SevenPhases {
    private var p0 = 0.0, p1 = 0.0, p2 = 0.0, p3 = 0.0, p4 = 0.0, p5 = 0.0, p6 = 0.0

    mutating func advance(_ index: Int, by delta: Double) -> Double {
        switch index {
        case 0: return Self.step(&p0, delta)
        case 1: return Self.step(&p1, delta)
        case 2: return Self.step(&p2, delta)
        case 3: return Self.step(&p3, delta)
        case 4: return Self.step(&p4, delta)
        case 5: return Self.step(&p5, delta)
        default: return Self.step(&p6, delta)
        }
    }

    private static func step(_ phase: inout Double, _ delta: Double) -> Double {
        phase += delta
        phase -= floor(phase)
        return phase
    }
}


struct LumaPadSettings: Codable, Equatable {
    var chord = 3
    var attack = 0.4
    var release = 2.0
    var holdBeats = 1.0
    var spread = 0
    var detune = 4.0

    var isValid: Bool {
        (0...8).contains(chord) && (0.005...3).contains(attack)
            && (0.05...6).contains(release) && (0.25...8).contains(holdBeats)
            && (0...2).contains(spread) && (0...15).contains(detune)
    }
}

enum LumaHarmony {
    static let names = ["Single", "Minor", "Major", "Minor 7", "Major 7", "Sus 2", "Sus 4", "Add 9", "Minor 9"]

    static func count(_ chord: Int) -> Int {
        if chord == 0 { return 1 }
        if chord == 8 { return 5 }
        return chord == 3 || chord == 4 || chord == 7 ? 4 : 3
    }

    static func interval(_ chord: Int, voice: Int, spread: Int) -> Int {
        let note: Int
        switch chord {
        case 1: note = voice == 0 ? 0 : (voice == 1 ? 3 : 7)
        case 2: note = voice == 0 ? 0 : (voice == 1 ? 4 : 7)
        case 3, 8: note = voice == 0 ? 0 : (voice == 1 ? 3 : (voice == 2 ? 7 : (voice == 3 ? 10 : 14)))
        case 4: note = voice == 0 ? 0 : (voice == 1 ? 4 : (voice == 2 ? 7 : 11))
        case 5: note = voice == 0 ? 0 : (voice == 1 ? 2 : 7)
        case 6: note = voice == 0 ? 0 : (voice == 1 ? 5 : 7)
        case 7: note = voice == 0 ? 0 : (voice == 1 ? 4 : (voice == 2 ? 7 : 14))
        default: note = 0
        }
        let lift = spread == 1 ? (voice == 1 ? 12 : 0) : (spread == 2 && voice > 0 ? 12 : 0)
        return note + lift
    }
}

// One pool per renderer, allocated once. Old chords keep their own pitch and release.
private final class LumaPolyphony {
    static let capacity = 24
    let sampleRate: Double
    private var voices = Array(repeating: LumaPadVoice(), count: capacity)
    private var ratios = Array(repeating: 1.0, count: 7)
    private var weights = Array(repeating: 1.0, count: 7)
    private var generation: UInt64 = 0
    private var coefficientTick = 0
    var activeCount: Int { voices.reduce(0) { $0 + ($1.active ? 1 : 0) } }

    init(sampleRate: Double) { self.sampleRate = sampleRate }

    func reset() {
        for i in voices.indices { voices[i] = LumaPadVoice() }
        coefficientTick = 0; generation = 0
    }

    func releaseAll() {
        for i in voices.indices { voices[i].beginRelease() }
    }

    func trigger(root: Double, chord: Int, settings: LumaPadSettings, tempo: Double, accent: Bool) {
        let count = LumaHarmony.count(chord)
        generation &+= 1
        for note in 0..<count {
            var slot = -1
            for i in voices.indices {
                if !voices[i].active { slot = i; break }
                if voices[i].generation == generation { continue }
                if slot == -1 { slot = i; continue }
                if voices[i].level < voices[slot].level
                    || (voices[i].level == voices[slot].level && voices[i].age > voices[slot].age) { slot = i }
            }
            let cents = count == 1 ? 0 : (Double(note) / Double(count - 1) * 2 - 1) * settings.detune
            let semitone = LumaHarmony.interval(chord, voice: note, spread: settings.spread)
            let hz = root * pow(2, Double(semitone) / 12 + cents / 1200)
            let oldSample = voices[slot].lastSample
            voices[slot] = LumaPadVoice()
            voices[slot].generation = generation
            voices[slot].start(frequency: hz, settings: settings, tempo: tempo,
                               sampleRate: sampleRate, gain: (accent ? 0.43 : 0.36) / sqrt(Double(count)),
                               seed: Double(note) * 0.17, stolenSample: oldSample)
        }
    }

    func render(_ tone: ToneSettings) -> Double {
        if coefficientTick == 0 {
            for i in 0..<7 {
                let h = Double(i + 1)
                ratios[i] = h * sqrt(1 + tone.color * 0.006 * (h * h - 1))
                weights[i] = 1 / pow(h, 1.5 - tone.color * 0.45)
            }
        }
        coefficientTick = (coefficientTick + 1) % 32
        var sum = 0.0
        for i in voices.indices where voices[i].active {
            sum += voices[i].render(tone, ratios: ratios, weights: weights, sampleRate: sampleRate)
        }
        return sum
    }
}

private struct LumaPadVoice {
    var generation: UInt64 = 0
    var active = false
    var age = 0.0
    var level = 0.0
    var lastSample = 0.0
    private var frequency = 0.0
    private var gain = 0.0
    private var phases = SevenPhases()
    private var motionPhase = 0.0
    private var attackFrames = 1.0
    private var gateFrames = 1.0
    private var releaseFrames = 1.0
    private var releaseAge = 0.0
    private var releasing = false
    private var releaseLevel = 0.0
    private var stolenSample = 0.0

    mutating func start(frequency: Double, settings: LumaPadSettings, tempo: Double,
                        sampleRate: Double, gain: Double, seed: Double, stolenSample: Double) {
        active = true
        self.frequency = frequency; self.gain = gain; self.motionPhase = seed
        attackFrames = max(1, settings.attack * sampleRate)
        gateFrames = attackFrames + settings.holdBeats * 60 / tempo * sampleRate
        releaseFrames = max(1, settings.release * sampleRate)
        self.stolenSample = stolenSample
    }

    mutating func beginRelease() {
        guard active && !releasing else { return }
        releasing = true; releaseAge = 0; releaseLevel = level
    }

    mutating func render(_ tone: ToneSettings, ratios: [Double], weights: [Double], sampleRate: Double) -> Double {
        if age >= gateFrames { beginRelease() }
        if releasing {
            let remaining = max(0, 1 - releaseAge / releaseFrames)
            level = releaseLevel * remaining * remaining
            releaseAge += 1
            if remaining == 0 { active = false; lastSample = 0; return 0 }
        } else {
            let progress = min(1, age / attackFrames)
            level = progress * progress * (3 - 2 * progress)
        }
        motionPhase += (0.12 + tone.motion * 0.9) / sampleRate
        motionPhase -= floor(motionPhase)
        let drift = sin(2 * .pi * motionPhase)
        let seconds = age / sampleRate
        let opening = 1 - exp(-seconds / (0.025 + tone.bloom * 0.45))
        var spectrum = 0.0
        var normalization = 0.0
        for i in 0..<7 {
            let brightness = i == 0 ? 1 : (0.12 + opening * tone.bloom * 1.8)
            let weight = weights[i] * brightness
            let hz = frequency * ratios[i]
            let phase = phases.advance(i, by: hz / sampleRate * (1 + drift * tone.motion * 0.0015))
            if hz < sampleRate * 0.4 {
                spectrum += sin(2 * .pi * phase + drift * tone.motion * Double(i + 1) * 0.12) * weight
            }
            normalization += weight
        }
        // A short ramp preserves continuity if a fully occupied pool must steal a voice.
        let stealFade = max(0, 1 - age / (sampleRate * 0.005))
        lastSample = spectrum / max(1, normalization) * level * gain + stolenSample * stealFade
        age += 1
        return lastSample
    }
}
