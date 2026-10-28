import Foundation

/// What a physical key does. Keys are matched by macOS virtual key code, so the layout works
/// the same under any input method or keyboard language setting.
public enum KeyAction: Equatable {
    /// Semitones above the melody's base C.
    case note(Int)
    /// Index into `Chord.all`.
    case chord(Int)
    case octaveDown, octaveUp
    case manualAir
    case hingeClose, hingeOpen
    case panic
}

public enum Keymap {
    /// ANSI key codes, piano style: the home row is white keys, the row above is black keys.
    static let notes: [UInt16: Int] = [
        0: 0,   // A  C
        13: 1,  // W  C#
        1: 2,   // S  D
        14: 3,  // E  D#
        2: 4,   // D  E
        3: 5,   // F  F
        17: 6,  // T  F#
        5: 7,   // G  G
        16: 8,  // Y  G#
        4: 9,   // H  A
        32: 10, // U  A#
        38: 11, // J  B
        40: 12, // K  C
        31: 13, // O  C#
        37: 14, // L  D
        35: 15, // P  D#
        41: 16, // ;  E
        39: 17, // '  F
    ]

    /// Number row 1...7 picks a bass chord.
    static let chords: [UInt16: Int] = [18: 0, 19: 1, 20: 2, 21: 3, 23: 4, 22: 5, 26: 6]

    public static func action(forKeyCode code: UInt16) -> KeyAction? {
        if let semitone = notes[code] { return .note(semitone) }
        if let index = chords[code] { return .chord(index) }
        switch code {
        case 6: return .octaveDown   // Z
        case 7: return .octaveUp     // X
        case 49: return .manualAir   // Space
        case 123: return .hingeClose // Left arrow
        case 124: return .hingeOpen  // Right arrow
        case 53: return .panic       // Esc
        default: return nil
        }
    }

    /// Label printed on the key for each melody semitone, for drawing the keyboard.
    public static let noteLabels: [(semitone: Int, key: String)] = [
        (0, "A"), (1, "W"), (2, "S"), (3, "E"), (4, "D"), (5, "F"), (6, "T"), (7, "G"), (8, "Y"),
        (9, "H"), (10, "U"), (11, "J"), (12, "K"), (13, "O"), (14, "L"), (15, "P"), (16, ";"), (17, "'"),
    ]

    public static func isBlack(_ semitone: Int) -> Bool {
        [1, 3, 6, 8, 10].contains(((semitone % 12) + 12) % 12)
    }
}

/// A bass button: a low root note plus a triad voiced in the octave above it, like the
/// left-hand side of a Stradella accordion.
public struct Chord: Equatable {
    public let name: String
    /// Pitch class of the root, 0 = C.
    public let root: Int
    public let intervals: [Int]

    public static let all: [Chord] = [
        Chord(name: "C", root: 0, intervals: [0, 4, 7]),
        Chord(name: "Dm", root: 2, intervals: [0, 3, 7]),
        Chord(name: "Em", root: 4, intervals: [0, 3, 7]),
        Chord(name: "F", root: 5, intervals: [0, 4, 7]),
        Chord(name: "G", root: 7, intervals: [0, 4, 7]),
        Chord(name: "Am", root: 9, intervals: [0, 3, 7]),
        Chord(name: "G7", root: 7, intervals: [0, 4, 10]),
    ]

    /// Bass root in octave 2 (MIDI 36...47), chord tones folded into octave 3 (48...59)
    /// so every chord sits in the same register.
    public var midiNotes: [Int] {
        let bass = 36 + root
        let tones = intervals.map { 48 + (root + $0) % 12 }
        return [bass] + tones.sorted()
    }
}

public enum Pitch {
    public static func frequency(midi: Int) -> Double {
        440 * pow(2, Double(midi - 69) / 12)
    }
}
