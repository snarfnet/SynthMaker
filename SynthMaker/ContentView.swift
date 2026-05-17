import SwiftUI

struct ContentView: View {
    @StateObject private var synth = SynthEngine()
    @State private var selectedStep = 0

    private let steps = [0, 3, 7, 10, 12, 10, 7, 3]
    private let rootFrequency = 110.0

    var body: some View {
        VStack(spacing: 0) {
            AcidBackdrop()
                .overlay {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            HeaderView(frequency: synth.frequency)

                            SignalScope(
                                waveform: Int(synth.waveform.rounded()),
                                cutoff: synth.filterCutoff,
                                resonance: synth.resonance
                            )

                            ControlPanel(title: "OSCILLATOR", systemImage: "waveform.path.ecg") {
                                ParameterSlider(
                                    title: "Tune",
                                    value: $synth.frequency,
                                    range: 20...2000,
                                    displayValue: format(synth.frequency, suffix: " Hz")
                                )

                                WaveformPicker(selection: $synth.waveform)
                            }

                            ControlPanel(title: "FILTER", systemImage: "slider.horizontal.3") {
                                ParameterSlider(
                                    title: "Cutoff",
                                    value: $synth.filterCutoff,
                                    range: 20...20000,
                                    displayValue: format(synth.filterCutoff, suffix: " Hz")
                                )

                                ParameterSlider(
                                    title: "Resonance",
                                    value: $synth.resonance,
                                    range: 0...10,
                                    displayValue: format(synth.resonance, suffix: " dB")
                                )

                                ParameterSlider(
                                    title: "Env Mod",
                                    value: $synth.envelopeAmount,
                                    range: 0...1,
                                    displayValue: percent(synth.envelopeAmount)
                                )
                            }

                            ControlPanel(title: "ENVELOPE", systemImage: "point.topleft.down.curvedto.point.bottomright.up") {
                                EnvelopeGrid(synth: synth)
                            }

                            KeyboardView(synth: synth)

                            StepSequencer(
                                selectedStep: $selectedStep,
                                steps: steps,
                                rootFrequency: rootFrequency,
                                play: playStep
                            )
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 20)
                        .padding(.bottom, 28)
                    }
                }

            AdMobBannerView()
                .background(Color.black)
        }
        .ignoresSafeArea(.keyboard)
    }

    private func playStep(_ index: Int) {
        selectedStep = index
        let semitone = steps[index]
        let frequency = rootFrequency * pow(2.0, Double(semitone) / 12.0)
        synth.playNote(frequency: frequency)
    }

    private func format(_ value: Double, suffix: String) -> String {
        value >= 100 ? String(format: "%.0f%@", value, suffix) : String(format: "%.1f%@", value, suffix)
    }

    private func percent(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }
}

private struct AcidBackdrop: View {
    var body: some View {
        ZStack {
            Image("AcidPanel")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.28),
                    Color(red: 0.02, green: 0.03, blue: 0.04).opacity(0.88)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.cyan.opacity(0.14),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 360
            )
            .ignoresSafeArea()
        }
        .background(Color(red: 0.015, green: 0.018, blue: 0.02))
    }
}

private struct HeaderView: View {
    let frequency: Double

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("SYNTHMAKER")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.amber)
                    .tracking(3)

                Text("ACID BASS UNIT")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(.panelText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 8) {
                StatusPill(text: "LIVE", color: .signalRed)

                Text(String(format: "%.1f Hz", frequency))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
            }
        }
    }
}

private struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: color, radius: 6)

            Text(text)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundColor(.panelText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.46))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct SignalScope: View {
    let waveform: Int
    let cutoff: Double
    let resonance: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("SIGNAL", systemImage: "dot.radiowaves.left.and.right")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(.amber)

                Spacer()

                Text(scopeLabel)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
            }

            GeometryReader { proxy in
                ZStack {
                    ScopeGrid()

                    ScopeWaveform(waveform: waveform, cutoff: cutoff, resonance: resonance)
                        .stroke(
                            LinearGradient(colors: [.cyan, .amber], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: .cyan.opacity(0.5), radius: 10)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .frame(height: 128)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.34))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.cyan.opacity(0.22), lineWidth: 1)
        )
    }

    private var scopeLabel: String {
        ["SAW", "SQUARE", "TRI", "SINE"][min(max(waveform, 0), 3)]
    }
}

private struct ScopeGrid: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.58)

            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 1)
                    Spacer()
                }
            }

            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 1)
                    Spacer()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct ScopeWaveform: Shape {
    let waveform: Int
    let cutoff: Double
    let resonance: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sampleCount = 96
        let amplitude = rect.height * CGFloat(0.22 + min(resonance, 10) * 0.018)
        let cycles = 2.0 + min(cutoff / 7000, 2.2)
        let midY = rect.midY

        for sample in 0...sampleCount {
            let progress = Double(sample) / Double(sampleCount)
            let phase = (progress * cycles).truncatingRemainder(dividingBy: 1)
            let x = rect.minX + rect.width * CGFloat(progress)
            let y = midY - CGFloat(waveValue(phase)) * amplitude
            let point = CGPoint(x: x, y: y)

            if sample == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }

    private func waveValue(_ phase: Double) -> Double {
        switch waveform {
        case 1:
            return phase < 0.5 ? 1 : -1
        case 2:
            return 1 - abs(phase * 4 - 2)
        case 3:
            return sin(phase * Double.pi * 2)
        default:
            return 1 - phase * 2
        }
    }
}

private struct ControlPanel<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.cyan)
                    .frame(width: 24, height: 24)
                    .background(Color.cyan.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                Text(title)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(.amber)
                    .tracking(2)

                Spacer()
            }

            content
        }
        .padding(16)
        .background(Color.black.opacity(0.48))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.24), radius: 18, x: 0, y: 12)
    }
}

private struct ParameterSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let displayValue: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.panelMuted)

                Spacer()

                Text(displayValue)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.panelText)
            }

            Slider(value: $value, in: range)
                .tint(.amber)
        }
    }
}

private struct WaveformPicker: View {
    @Binding var selection: Double
    private let options = ["SAW", "SQR", "TRI", "SIN"]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options.indices, id: \.self) { index in
                Button {
                    selection = Double(index)
                } label: {
                    Text(options[index])
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(Int(selection.rounded()) == index ? .black : .panelText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(Int(selection.rounded()) == index ? Color.amber : Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.white.opacity(0.13), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct EnvelopeGrid: View {
    @ObservedObject var synth: SynthEngine

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            ParameterSlider(
                title: "Attack",
                value: $synth.attack,
                range: 0...1,
                displayValue: String(format: "%.2f s", synth.attack)
            )

            ParameterSlider(
                title: "Decay",
                value: $synth.decay,
                range: 0...2,
                displayValue: String(format: "%.2f s", synth.decay)
            )

            ParameterSlider(
                title: "Sustain",
                value: $synth.sustain,
                range: 0...1,
                displayValue: String(format: "%.0f%%", synth.sustain * 100)
            )

            ParameterSlider(
                title: "Release",
                value: $synth.release,
                range: 0...2,
                displayValue: String(format: "%.2f s", synth.release)
            )
        }
    }
}

private struct KeyboardView: View {
    @ObservedObject var synth: SynthEngine

    private let notes = [
        Note(name: "C", frequency: 130.81),
        Note(name: "D", frequency: 146.83),
        Note(name: "E", frequency: 164.81),
        Note(name: "F", frequency: 174.61),
        Note(name: "G", frequency: 196.00),
        Note(name: "A", frequency: 220.00),
        Note(name: "B", frequency: 246.94)
    ]

    var body: some View {
        ControlPanel(title: "KEYBOARD", systemImage: "pianokeys") {
            HStack(spacing: 7) {
                ForEach(notes) { note in
                    Button {
                        synth.playNote(frequency: note.frequency)
                    } label: {
                        VStack(spacing: 4) {
                            Text(note.name)
                                .font(.system(size: 16, weight: .black, design: .rounded))
                            Text("BASS")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(.panelMuted)
                        }
                        .foregroundColor(.panelText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(note.name == "C" ? Color.cyan.opacity(0.22) : Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct StepSequencer: View {
    @Binding var selectedStep: Int
    let steps: [Int]
    let rootFrequency: Double
    let play: (Int) -> Void

    var body: some View {
        ControlPanel(title: "PATTERN", systemImage: "square.grid.3x3.fill") {
            HStack(spacing: 8) {
                ForEach(steps.indices, id: \.self) { index in
                    Button {
                        play(index)
                    } label: {
                        VStack(spacing: 6) {
                            Capsule()
                                .fill(selectedStep == index ? Color.signalRed : Color.white.opacity(0.16))
                                .frame(width: 16, height: 4)

                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .black, design: .monospaced))

                            Text(noteName(for: steps[index]))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.panelMuted)
                        }
                        .foregroundColor(selectedStep == index ? .black : .panelText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 68)
                        .background(selectedStep == index ? Color.amber : Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func noteName(for semitone: Int) -> String {
        let names = ["A", "A#", "B", "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#"]
        return names[semitone % names.count]
    }
}

private struct Note: Identifiable {
    let id = UUID()
    let name: String
    let frequency: Double
}

private extension Color {
    static let amber = Color(red: 1.0, green: 0.72, blue: 0.22)
    static let signalRed = Color(red: 1.0, green: 0.2, blue: 0.12)
    static let panelText = Color(red: 0.94, green: 0.96, blue: 0.92)
    static let panelMuted = Color(red: 0.58, green: 0.64, blue: 0.62)
}

#Preview {
    ContentView()
}
