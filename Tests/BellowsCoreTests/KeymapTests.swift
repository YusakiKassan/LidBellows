import Testing
@testable import BellowsCore

@Test func homeRowIsAChromaticRun() {
    // A W S E D F T G Y H U J K: C up to the next C, every semitone once.
    let codes: [UInt16] = [0, 13, 1, 14, 2, 3, 17, 5, 16, 4, 32, 38, 40]
    let semitones = codes.compactMap { code -> Int? in
        if case let .note(s)? = Keymap.action(forKeyCode: code) { return s }
        return nil
    }
    #expect(semitones == Array(0...12))
}

@Test func everyLabelMapsToItsNote() {
    let mapped = Set(Keymap.notes.values)
    #expect(mapped == Set(Keymap.noteLabels.map(\.semitone)))
    #expect(Keymap.notes.count == Keymap.noteLabels.count)
}

@Test func noKeyHasTwoJobs() {
    let noteKeys = Set(Keymap.notes.keys)
    let chordKeys = Set(Keymap.chords.keys)
    let controls: Set<UInt16> = [6, 7, 49, 123, 124, 53]
    #expect(noteKeys.isDisjoint(with: chordKeys))
    #expect(noteKeys.isDisjoint(with: controls))
    #expect(chordKeys.isDisjoint(with: controls))
}

@Test func chordsAreVoicedInTheBassRegister() {
    #expect(Chord.all[0].midiNotes == [36, 48, 52, 55]) // C: C2 + C3 E3 G3
    #expect(Chord.all[5].midiNotes == [45, 48, 52, 57]) // Am: A2 + C3 E3 A3
    for chord in Chord.all {
        let notes = chord.midiNotes
        #expect((36...47).contains(notes[0]))
        #expect(notes.dropFirst().allSatisfy { (48...59).contains($0) })
    }
}

@Test func concertA() {
    #expect(abs(Pitch.frequency(midi: 69) - 440) < 1e-9)
    #expect(abs(Pitch.frequency(midi: 60) - 261.6256) < 1e-3)
}
