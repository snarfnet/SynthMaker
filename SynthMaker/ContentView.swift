import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var synth = SynthEngine()
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedStep = 0
    @State private var slot = 1
    @State private var confirmLoad: Int?
    @State private var confirmSave = false
    @State private var confirmPreset: Int?
    @State private var share = false

    private let amber = Color(red: 1, green: 0.72, blue: 0.22)
    private let cyan = Color(red: 0.22, green: 0.88, blue: 1)
    private let noteNames = ["A", "A♯", "B", "C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯"]

    var body: some View {
        ZStack {
            Color(red: 0.025, green: 0.035, blue: 0.045).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SYNTHMAKER").font(.caption.bold()).foregroundColor(amber)
                            Text("TECHNO").font(.system(size: 34, weight: .black, design: .rounded))
                        }
                        Spacer()
                        Text(synth.isPlaying ? "PLAYING" : "READY")
                            .font(.caption.monospaced()).foregroundColor(cyan)
                    }
                    Text("Press Play. Shape the bass. Build your groove.")
                        .font(.subheadline).foregroundColor(.secondary)
                    transport
                    pattern
                    sound
                    library
                    Text("16 steps · 1 bar · A minor starting pattern\nWAV export: 4 bars · 44.1 kHz · mono")
                        .font(.caption).foregroundColor(.secondary)
                }
                .padding(20)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .tint(amber)
        .onChange(of: scenePhase) { phase in
            if phase != .active { synth.stop() }
        }
        .onChange(of: synth.exportURL) { url in if url != nil { share = true } }
        .sheet(isPresented: $share) {
            if let url = synth.exportURL { ShareSheet(url: url) }
        }
        .alert("SynthMaker", isPresented: Binding(
            get: { synth.message != nil }, set: { if !$0 { synth.message = nil } }
        )) { Button("OK") { synth.message = nil } } message: { Text(synth.message ?? "") }
        .confirmationDialog("Replace the current pattern?", isPresented: Binding(
            get: { confirmLoad != nil || confirmPreset != nil },
            set: { if !$0 { confirmLoad = nil; confirmPreset = nil } }
        ), titleVisibility: .visible) {
            Button("Replace pattern", role: .destructive) {
                if let index = confirmPreset { synth.stop(); synth.patch = .preset(index) }
                if let index = confirmLoad { synth.load(slot: index) }
                confirmLoad = nil; confirmPreset = nil
            }
        }
        .confirmationDialog("Save to slot \(slot)? Any previous save in this slot will be replaced.",
                            isPresented: $confirmSave, titleVisibility: .visible) {
            Button("Save pattern") { synth.save(slot: slot) }
        }
    }

    private var transport: some View {
        VStack(spacing: 16) {
            Button {
                if synth.isPlaying { synth.stop() } else { synth.play() }
            } label: {
                Label(synth.isPlaying ? "STOP" : "PLAY", systemImage: synth.isPlaying ? "stop.fill" : "play.fill")
                    .font(.headline.monospaced()).frame(maxWidth: .infinity, minHeight: 54)
                    .foregroundColor(.black).background(amber).cornerRadius(10)
            }
            parameter("Tempo", value: $synth.patch.tempo, range: 60...180, text: "\(Int(synth.patch.tempo)) BPM", step: 1)
            parameter("Swing", value: $synth.patch.swing, range: 0...0.45, text: "\(Int(synth.patch.swing * 100))%")
            Toggle("Drum machine", isOn: $synth.patch.drums)
        }
        .padding(16).background(panel)
    }

    private var pattern: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading("PATTERN", detail: "Select a step to edit")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(0..<16, id: \.self) { index in
                    Button { selectedStep = index } label: {
                        VStack(spacing: 5) {
                            HStack {
                                Text(String(format: "%02d", index + 1))
                                Spacer()
                                Circle().fill(synth.currentStep == index ? cyan : Color.gray.opacity(0.3)).frame(width: 7, height: 7)
                            }.font(.caption2.monospaced())
                            Text(synth.patch.steps[index].enabled ? noteName(synth.patch.steps[index].note) : "—")
                                .font(.headline.monospaced())
                            Text("\(synth.patch.steps[index].kick ? "K" : "·") \(synth.patch.steps[index].hat ? "H" : "·") \(synth.patch.steps[index].accent ? ">" : "·") \(synth.patch.steps[index].slide ? "↗" : "·")")
                                .font(.caption2.monospaced())
                        }
                        .foregroundColor(selectedStep == index ? .black : .white)
                        .padding(9).frame(maxWidth: .infinity, minHeight: 72)
                        .background(selectedStep == index ? amber : Color.white.opacity(0.07))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(synth.currentStep == index ? cyan : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Step \(index + 1), \(synth.patch.steps[index].enabled ? noteName(synth.patch.steps[index].note) : "rest")")
                    .accessibilityAddTraits(selectedStep == index ? .isSelected : [])
                }
            }
            Divider()
            Text("STEP \(selectedStep + 1)").font(.caption.bold()).foregroundColor(cyan)
            Toggle("Bass note", isOn: $synth.patch.steps[selectedStep].enabled)
            Stepper("Note: \(noteName(synth.patch.steps[selectedStep].note))", value: $synth.patch.steps[selectedStep].note, in: -12...24)
            HStack {
                Toggle("Accent", isOn: $synth.patch.steps[selectedStep].accent)
                Toggle("Slide", isOn: $synth.patch.steps[selectedStep].slide)
            }
            HStack {
                Toggle("Kick", isOn: $synth.patch.steps[selectedStep].kick)
                Toggle("Hi-hat", isOn: $synth.patch.steps[selectedStep].hat)
            }
            Text("Accent adds emphasis. Slide carries this note into the next. K = kick, H = hi-hat.")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding(16).background(panel)
    }

    private var sound: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading("BASS ENGINE", detail: "Sound controls")
            Picker("Waveform", selection: $synth.patch.waveform) {
                Text("Saw").tag(0); Text("Square").tag(1); Text("Triangle").tag(2); Text("Sine").tag(3)
            }.pickerStyle(.segmented)
            parameter("Cutoff", value: $synth.patch.cutoff, range: 40...12000, text: "\(Int(synth.patch.cutoff)) Hz")
            parameter("Resonance", value: $synth.patch.resonance, range: 0...10, text: String(format: "%.1f", synth.patch.resonance))
            parameter("Filter envelope", value: $synth.patch.envMod, range: 0...1, text: "\(Int(synth.patch.envMod * 100))%")
            parameter("Decay", value: $synth.patch.decay, range: 0.03...1, text: String(format: "%.2f s", synth.patch.decay))
            parameter("Drive", value: $synth.patch.drive, range: 0...1, text: "\(Int(synth.patch.drive * 100))%")
        }
        .padding(16).background(panel)
    }

    private var library: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading("PATTERNS & EXPORT", detail: "Keep what you make")
            Menu("Choose a starting pattern") {
                Button("Warehouse · 130 BPM") { confirmPreset = 0 }
                Button("Acid Pressure · 138 BPM") { confirmPreset = 1 }
                Button("Afterhours · 122 BPM") { confirmPreset = 2 }
            }
            Picker("Save slot", selection: $slot) {
                ForEach(1...4, id: \.self) { Text("Slot \($0)").tag($0) }
            }.pickerStyle(.segmented)
            HStack {
                Button("Save") { confirmSave = true }.frame(maxWidth: .infinity)
                Button("Load") { confirmLoad = slot }.frame(maxWidth: .infinity)
            }.buttonStyle(.bordered).controlSize(.large)
            Button { synth.exportWAV() } label: {
                Label(synth.isExporting ? "Rendering…" : "Export 4 bars as WAV", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }.buttonStyle(.bordered).disabled(synth.isExporting)
        }
        .padding(16).background(panel)
    }

    private var panel: some View {
        RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.045))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private func heading(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.bold().monospaced()).foregroundColor(amber)
            Text(detail).font(.caption).foregroundColor(.secondary)
        }
    }

    private func parameter(_ name: String, value: Binding<Double>, range: ClosedRange<Double>, text: String, step: Double = 0.001) -> some View {
        VStack(spacing: 6) {
            HStack { Text(name); Spacer(); Text(text).foregroundColor(cyan).monospacedDigit() }
                .font(.subheadline)
            Slider(value: value, in: range, step: step).accessibilityLabel(name).accessibilityValue(text)
        }
    }

    private func noteName(_ semitone: Int) -> String {
        let midi = 33 + semitone
        return "\(noteNames[(semitone % 12 + 12) % 12])\(midi / 12 - 1)"
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
