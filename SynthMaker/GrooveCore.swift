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
}

struct GroovePatch: Codable, Equatable {
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

    var isValid: Bool {
        steps.count == 16 && (60...180).contains(tempo) && (0...0.45).contains(swing)
            && (40...12000).contains(cutoff) && (0...10).contains(resonance)
            && (0...1).contains(envMod) && (0.03...1).contains(decay)
            && (0...1).contains(drive) && (0...3).contains(waveform)
            && steps.allSatisfy {
                (-12...24).contains($0.note) && (0...1).contains($0.probability)
                    && [1, 2, 4].contains($0.every)
                    && ($0.cutoffLock == nil || (40...12000).contains($0.cutoffLock!))
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

    init(sampleRate: Double) { self.sampleRate = sampleRate }

    mutating func nextSample(_ patch: GroovePatch) -> Float {
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
            active = step.enabled && chance < step.probability && cycle % step.every == 0
            lockedCutoff = step.cutoffLock
            filterTick = 0
            slide = step.slide
            accent = step.accent
            targetFrequency = 55 * pow(2, Double(step.note) / 12)
            if !previousSlide { frequency = targetFrequency }
            if active && !previousSlide { envelope = 0 }
            if patch.drums && step.kick { kickAge = 0; kickPhase = 0 }
            if patch.drums && step.hat { hatAge = 0 }
        }
        let gate = active && (slide || elapsed < duration * 0.65)
        let targetLevel = gate ? 1.0 : 0.0
        envelope += (targetLevel - envelope) * (gate ? 0.012 : 0.003)
        frequency += (targetFrequency - frequency) * 0.002
        let dt = min(0.45, frequency / sampleRate)
        let osc: Double
        switch patch.waveform {
        case 1:
            let shifted = (phase + 0.5).truncatingRemainder(dividingBy: 1)
            osc = (phase < 0.5 ? 1.0 : -1.0) + blep(phase, dt) - blep(shifted, dt)
        case 2: osc = 1 - 4 * abs(phase - 0.5)
        case 3: osc = sin(2 * .pi * phase)
        default: osc = 2 * phase - 1 - blep(phase, dt)
        }
        phase += dt
        phase -= floor(phase)
        // A resonant TPT state-variable filter. Env Mod now moves the cutoff.
        if filterTick == 0 {
            let modulation = patch.envMod * 5000 * exp(-elapsed / sampleRate / patch.decay) * (accent ? 1.35 : 1)
            let hz = min(sampleRate * 0.4, (lockedCutoff ?? patch.cutoff) + modulation)
            g = tan(.pi * hz / sampleRate)
        }
        filterTick = (filterTick + 1) % 32
        let k = 1 / (0.7 + patch.resonance * 0.7)
        let input = osc * envelope * (accent ? 0.32 : 0.23)
        let v1 = (band + g * (input - low)) / (1 + g * (g + k))
        let v2 = low + g * v1
        band = 2 * v1 - band
        low = 2 * v2 - low
        var output = tanh(v2 * (1 + patch.drive * 7)) * 0.5
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
