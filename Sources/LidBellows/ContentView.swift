import BellowsCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var engine: Engine

    var body: some View {
        VStack(spacing: 18) {
            header
            BellowsMeter(pressure: engine.pressure, angle: engine.angle, direction: engine.direction,
                         manualAir: engine.manualAir)
            FeelPanel()
            PianoKeys(held: engine.heldNotes, octave: engine.octave)
            ChordRow(held: engine.heldChords)
            Text("按住琴键，轻轻推拉屏幕。Z / X 换八度 · 空格 持续供气 · ← → 模拟开合 · Esc 全部止音")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 720)
        .background(Color(red: 0.10, green: 0.10, blue: 0.13))
        .background(KeyCatcher())
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("LidBellows")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text("风箱")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(sensorText).foregroundStyle(engine.sensorStatus == .missing ? .orange : .green)
                if let error = engine.audioError { Text(error).foregroundStyle(.red) }
            }
            .font(.system(size: 12, design: .monospaced))
        }
    }

    private var sensorText: String {
        switch engine.sensorStatus {
        case .precise: return "开合传感器 · 0.01°"
        case .wholeDegrees: return "开合传感器 · 1°"
        case .missing: return "没找到传感器，用 ← → 模拟"
        }
    }
}

private struct BellowsMeter: View {
    let pressure: Double
    let angle: Double?
    let direction: Bellows.Direction
    let manualAir: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(angle.map { String(format: "%6.1f°", $0) } ?? "   —  ")
                Text(directionText).foregroundStyle(.secondary)
                Spacer()
                Text(manualAir ? "持续供气" : String(format: "风压 %3.0f%%", pressure * 100))
            }
            .font(.system(size: 14, design: .monospaced))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(colors: [.teal, .green, .yellow], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(geo.size.width * pressure, pressure > 0 ? 8 : 0))
                }
            }
            .frame(height: 14)
        }
    }

    private var directionText: String {
        switch direction {
        case .opening: return "拉开 ↑"
        case .closing: return "合拢 ↓"
        case .still: return "静止"
        }
    }
}

/// Sliders for how the lid drives the air.
private struct FeelPanel: View {
    @EnvironmentObject private var engine: Engine

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            setting("灵敏度", String(format: "%.1f · %.0f°/s 满风压", engine.sensitivity, engine.fullSpeed),
                    value: $engine.sensitivity, range: Engine.sensitivityRange)
            setting("换向保持", String(format: "%.2f 秒", engine.hold),
                    value: $engine.hold, range: Engine.holdRange)
            setting("余气", String(format: "%.1f 秒漏完", engine.tail),
                    value: $engine.tail, range: Engine.tailRange)
            Button("默认") { engine.resetFeel() }
                .focusable(false)
                .padding(.top, 14)
        }
    }

    private func setting(_ title: String, _ detail: String, value: Binding<Double>,
                         range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(.system(size: 12, weight: .medium))
                Spacer()
                Text(detail).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            }
            // Not focusable, so the keyboard keeps playing notes after a slider is dragged.
            Slider(value: value, in: range)
                .focusable(false)
                .controlSize(.small)
        }
    }
}

private struct PianoKeys: View {
    let held: Set<Int>
    let octave: Int

    private static let whiteWidth = 56.0
    private static let whites = Keymap.noteLabels.filter { !Keymap.isBlack($0.semitone) }
    private static let blacks = Keymap.noteLabels.filter { Keymap.isBlack($0.semitone) }

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topLeading) {
                HStack(spacing: 4) {
                    ForEach(Self.whites, id: \.semitone) { key in
                        keyFace(key, black: false)
                            .frame(width: Self.whiteWidth, height: 130)
                    }
                }
                ForEach(Self.blacks, id: \.semitone) { key in
                    keyFace(key, black: true)
                        .frame(width: 36, height: 80)
                        .offset(x: blackOffset(key.semitone))
                }
            }
            Text("八度 \(octave >= 0 ? "+" : "")\(octave)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func keyFace(_ key: (semitone: Int, key: String), black: Bool) -> some View {
        let on = held.contains(key.semitone)
        return RoundedRectangle(cornerRadius: 6)
            .fill(on ? Color.green : black ? Color(white: 0.16) : Color(white: 0.92))
            .overlay(alignment: .bottom) {
                VStack(spacing: 1) {
                    Text(key.key).font(.system(size: 14, weight: .semibold, design: .monospaced))
                    Text(noteName(key.semitone)).font(.system(size: 10))
                }
                .foregroundStyle(black || on ? Color.white : Color.black.opacity(0.75))
                .padding(.bottom, 6)
            }
    }

    /// Black keys sit over the gap after the white key just below them.
    private func blackOffset(_ semitone: Int) -> Double {
        let whitesBelow = Self.whites.filter { $0.semitone < semitone }.count
        return Double(whitesBelow) * (Self.whiteWidth + 4) - 20
    }

    private func noteName(_ semitone: Int) -> String {
        let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        return names[semitone % 12] + String(4 + octave + semitone / 12)
    }
}

private struct ChordRow: View {
    let held: Set<Int>

    var body: some View {
        HStack(spacing: 8) {
            Text("低音和弦")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            ForEach(Chord.all.indices, id: \.self) { index in
                let on = held.contains(index)
                VStack(spacing: 2) {
                    Text(Chord.all[index].name).font(.system(size: 15, weight: .semibold))
                    Text("\(index + 1)").font(.system(size: 10, design: .monospaced)).opacity(0.7)
                }
                .frame(width: 54, height: 44)
                .background(RoundedRectangle(cornerRadius: 8).fill(on ? Color.green : Color.white.opacity(0.08)))
            }
        }
    }
}
