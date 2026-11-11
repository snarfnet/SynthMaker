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
    @State private var pulses = 5
    @State private var rotation = 0
    @State private var lane = 0
    @State private var includePadTail = true
    private var isPad: Bool { synth.patch.tone.model == 4 && synth.patch.tone.pad != nil }

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
                    Text("Press Play. Shape your sound. Build your groove.")
                        .font(.subheadline).foregroundColor(.secondary)
                    transport
                    pattern
                    evolution
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
                if let index = confirmPreset { synth.replacePatch(.preset(index)) }
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
            Toggle("Instrument note", isOn: $synth.patch.steps[selectedStep].enabled)
            Stepper("Note: \(noteName(synth.patch.steps[selectedStep].note))", value: $synth.patch.steps[selectedStep].note, in: -12...24)
            HStack {
                Toggle("Accent", isOn: $synth.patch.steps[selectedStep].accent)
                if !isPad { Toggle("Slide", isOn: $synth.patch.steps[selectedStep].slide) }
            }
            if isPad {
                Picker("Step chord", selection: Binding(
                    get: { synth.patch.steps[selectedStep].chord ?? -1 },
                    set: { synth.patch.steps[selectedStep].chord = $0 == -1 ? nil : $0 }
                )) {
                    Text("Use instrument chord").tag(-1)
                    ForEach(0..<LumaHarmony.names.count, id: \.self) { Text(LumaHarmony.names[$0]).tag($0) }
                }.pickerStyle(.menu)
            }
            HStack {
                Toggle("Kick", isOn: $synth.patch.steps[selectedStep].kick)
                Toggle("Hi-hat", isOn: $synth.patch.steps[selectedStep].hat)
            }
            parameter("Note probability", value: $synth.patch.steps[selectedStep].probability,
                      range: 0...1, text: "\(Int(synth.patch.steps[selectedStep].probability * 100))%", step: 0.05)
            Picker("Play note", selection: $synth.patch.steps[selectedStep].every) {
                Text("Every loop").tag(1); Text("Every 2nd").tag(2); Text("Every 4th").tag(4)
            }.pickerStyle(.segmented)
            Toggle("Lock cutoff for this step", isOn: Binding(
                get: { synth.patch.steps[selectedStep].cutoffLock != nil },
                set: { synth.patch.steps[selectedStep].cutoffLock = $0 ? synth.patch.cutoff : nil }
            ))
            if synth.patch.steps[selectedStep].cutoffLock != nil {
                parameter("Step cutoff", value: Binding(
                    get: { synth.patch.steps[selectedStep].cutoffLock ?? synth.patch.cutoff },
                    set: { synth.patch.steps[selectedStep].cutoffLock = $0 }
                ), range: 40...12000, text: "\(Int(synth.patch.steps[selectedStep].cutoffLock ?? synth.patch.cutoff)) Hz")
            }
            Text("Probability and loop conditions affect the instrument only. Conditional notes start on loop 1. A cutoff lock overrides the main cutoff for this step.")
                .font(.caption).foregroundColor(.secondary)
            Text("Accent adds emphasis. Slide carries this note into the next. K = kick, H = hi-hat.")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding(16).background(panel)
    }

    private var evolution: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading("EVOLUTION", detail: "Generate rhythms and variations")
            Text("Euclidean rhythm").font(.headline)
            Picker("Rhythm lane", selection: $lane) {
                Text("Melody").tag(0); Text("Kick").tag(1); Text("Hi-hat").tag(2)
            }.pickerStyle(.segmented)
            Stepper("Hits: \(pulses) / 16", value: $pulses, in: 0...16)
            Stepper("Rotation: \(rotation)", value: $rotation, in: 0...15)
            Button("Apply rhythm to selected lane") {
                synth.generateRhythm(pulses: pulses, rotation: rotation, lane: lane)
            }.buttonStyle(.bordered).controlSize(.large)
            Text("Space hits evenly across 16 steps. Try 5 bass notes against a 4-hit kick.")
                .font(.caption).foregroundColor(.secondary)
            Divider()
            Button("Mutate melody · A minor pentatonic") { synth.mutate() }
                .buttonStyle(.bordered).controlSize(.large)
            Text("Changes some notes, accents and slides while keeping the rhythm and drums. Changes apply during playback.")
                .font(.caption).foregroundColor(.secondary)
            Button("Undo last generation / preset") { synth.undoGeneration() }
                .disabled(!synth.canUndo)
            Text("Undo restores the full pattern from before the last generation, instrument choice or load, including any edits made since then.")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding(16).background(panel)
    }

    private var sound: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading("INSTRUMENT", detail: "Choose a voice, then make it yours")
            Picker("Instrument", selection: Binding(
                get: { synth.patch.tone.model }, set: { synth.selectTone($0) }
            )) {
                Text("Acid · original bass").tag(0)
                Text("Warm Analog · detuned oscillators").tag(1)
                Text("Glass Bell · FM synthesis").tag(2)
                Text("Soft Keys · FM electric piano").tag(3)
                Text("LUMA-7 · original spectral instrument").tag(4)
            }.pickerStyle(.menu)
            Text("Choosing an instrument sets its tone controls and octave, preserving your rhythm. Undo restores the previous patch.")
                .font(.caption).foregroundColor(.secondary)
            Stepper("Octave: +\(synth.patch.tone.octave)", value: $synth.patch.tone.octave, in: 0...3)
            if synth.patch.tone.model != 0 {
                if synth.patch.tone.model == 4 {
                    Text("LUMA-7").font(.system(size: 28, weight: .light, design: .rounded)).foregroundColor(cyan)
                    Text("Seven partials. A slow bloom. A little instability. Our original instrument — from soft light to layered chords.")
                        .font(.caption).foregroundColor(.secondary)
                }
                parameter("Color", value: $synth.patch.tone.color, range: 0...1, text: "\(Int(synth.patch.tone.color * 100))%")
                if synth.patch.tone.model != 1 {
                    parameter("Bloom", value: $synth.patch.tone.bloom, range: 0...1, text: "\(Int(synth.patch.tone.bloom * 100))%")
                }
                if synth.patch.tone.model == 1 || synth.patch.tone.model == 4 {
                    parameter("Motion", value: $synth.patch.tone.motion, range: 0...1, text: "\(Int(synth.patch.tone.motion * 100))%")
                }
                if !isPad { parameter("Tone tail", value: $synth.patch.tone.tail, range: 0.1...3, text: String(format: "%.2f s", synth.patch.tone.tail)) }
                if !isPad { Text("These are synthesis models, not exact replicas of named hardware. One melodic voice; new notes retune the current voice.")
                    .font(.caption).foregroundColor(.secondary) }
                if synth.patch.tone.model == 4 { padControls }
            }
            parameter("Tape echo", value: $synth.patch.tone.space, range: 0...0.6, text: "\(Int(synth.patch.tone.space * 100))%")
            Text("Dotted-eighth echoes follow the tempo. Warm, damped repeats affect the instrument only.")
                .font(.caption).foregroundColor(.secondary)
            if synth.patch.tone.model == 0 {
            Picker("Waveform", selection: $synth.patch.waveform) {
                Text("Saw").tag(0); Text("Square").tag(1); Text("Triangle").tag(2); Text("Sine").tag(3)
            }.pickerStyle(.segmented)
            }
            parameter("Cutoff", value: $synth.patch.cutoff, range: 40...12000, text: "\(Int(synth.patch.cutoff)) Hz")
            parameter("Resonance", value: $synth.patch.resonance, range: 0...10, text: String(format: "%.1f", synth.patch.resonance))
            parameter("Filter envelope", value: $synth.patch.envMod, range: 0...1, text: "\(Int(synth.patch.envMod * 100))%")
            parameter("Decay", value: $synth.patch.decay, range: 0.03...1, text: String(format: "%.2f s", synth.patch.decay))
            parameter("Drive", value: $synth.patch.drive, range: 0...1, text: "\(Int(synth.patch.drive * 100))%")
        }
        .padding(16).background(panel)
    }

    private func padValue<Value>(_ key: WritableKeyPath<LumaPadSettings, Value>) -> Binding<Value> {
        Binding(get: { (synth.patch.tone.pad ?? LumaPadSettings())[keyPath: key] }, set: { value in
            var settings = synth.patch.tone.pad ?? LumaPadSettings()
            settings[keyPath: key] = value
            synth.patch.tone.pad = settings
        })
    }

    private var padControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Polyphonic chords & pads", isOn: Binding(
                get: { isPad }, set: { synth.patch.tone.pad = $0 ? LumaPadSettings() : nil }
            ))
            if let pad = synth.patch.tone.pad {
                Picker("Default chord", selection: padValue(\.chord)) {
                    ForEach(0..<LumaHarmony.names.count, id: \.self) { Text(LumaHarmony.names[$0]).tag($0) }
                }.pickerStyle(.menu)
                Picker("Voicing", selection: padValue(\.spread)) {
                    Text("Close").tag(0); Text("Open").tag(1); Text("Wide").tag(2)
                }.pickerStyle(.segmented)
                parameter("Pad attack", value: padValue(\.attack), range: 0.005...3, text: String(format: "%.2f s", pad.attack))
                parameter("Hold after attack", value: padValue(\.holdBeats), range: 0.25...8, text: String(format: "%.2f beats", pad.holdBeats), step: 0.25)
                parameter("Pad release", value: padValue(\.release), range: 0.05...6, text: String(format: "%.2f s", pad.release))
                parameter("Detune", value: padValue(\.detune), range: 0...15, text: String(format: "%.1f cents", pad.detune))
                Text("Up to 24 overlapping voices. Each chord keeps its own pitch and release. Choose a chord on each step to make a progression. Slide is replaced by overlapping notes in this mode. Output is mono; voicing changes register, not stereo width.")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
    }

    private var library: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading("PATTERNS & EXPORT", detail: "Keep what you make")
            Menu("Choose a starting pattern") {
                Button("Warehouse · 130 BPM") { confirmPreset = 0 }
                Button("Acid Pressure · 138 BPM") { confirmPreset = 1 }
                Button("Afterhours · 122 BPM") { confirmPreset = 2 }
                Button("LUMA-7 · First Light") { confirmPreset = 3 }
                Button("Glass Bell · Starlight") { confirmPreset = 4 }
                Button("Soft Keys · Night Transit") { confirmPreset = 5 }
                Button("LUMA-7 · Cloud Garden Pad") { confirmPreset = 6 }
                Button("LUMA-7 · Velvet Chords") { confirmPreset = 7 }
            }
            Picker("Save slot", selection: $slot) {
                ForEach(1...4, id: \.self) { Text("Slot \($0)").tag($0) }
            }.pickerStyle(.segmented)
            HStack {
                Button("Save") { confirmSave = true }.frame(maxWidth: .infinity)
                Button("Load") { confirmLoad = slot }.frame(maxWidth: .infinity)
            }.buttonStyle(.bordered).controlSize(.large)
            if isPad { Toggle("Include release tail in WAV", isOn: $includePadTail) }
            Button { synth.exportWAV(includeTail: isPad && includePadTail) } label: {
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
        let midi = 33 + semitone + 12 * synth.patch.tone.octave
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
