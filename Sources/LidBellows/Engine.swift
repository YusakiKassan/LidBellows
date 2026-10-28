import AppKit
import AVFoundation
import BellowsCore
import QuartzCore

/// Runs the 120 Hz loop: read the hinge, update the bellows, feed the synth, publish state
/// for the view.
final class Engine: ObservableObject {
    static let shared = Engine()

    enum SensorStatus: Equatable { case precise, wholeDegrees, missing }

    @Published private(set) var angle: Double?
    @Published private(set) var pressure = 0.0
    @Published private(set) var direction = Bellows.Direction.still
    @Published private(set) var octave = 0
    @Published private(set) var heldNotes: Set<Int> = []
    @Published private(set) var heldChords: Set<Int> = []
    @Published private(set) var manualAir = false
    @Published private(set) var sensorStatus = SensorStatus.missing
    @Published private(set) var audioError: String?

    /// How the bellows feel. Saved between launches.
    /// Sensitivity 1...10; full pressure needs `fullSpeedAtOne / sensitivity` degrees per second.
    @Published var sensitivity = Defaults.sensitivity { didSet { applyFeel() } }
    /// Seconds the air is held after the lid stops.
    @Published var hold = Defaults.hold { didSet { applyFeel() } }
    /// Seconds for the air to leak away after the hold.
    @Published var tail = Defaults.tail { didSet { applyFeel() } }

    enum Defaults {
        static let sensitivity = 3.0
        static let hold = 0.4
        static let tail = 1.5
    }
    static let fullSpeedAtOne = 135.0
    static let sensitivityRange = 1.0...10.0
    static let holdRange = 0.0...1.0
    static let tailRange = 0.3...4.0

    var fullSpeed: Double { Self.fullSpeedAtOne / sensitivity }

    /// Melody base note before octave shifts: C4.
    static let baseMidi = 60
    static let manualAirLevel = 0.6
    /// Simulated hinge for Macs without a sensor, or when the arrow keys are held.
    static let simulatedSpeed = 80.0
    static let simulatedRange = 15.0...130.0

    private var bellows = Bellows()
    private var synth: Synth?
    private var sensor: LidSensor?
    private var timer: Timer?
    private var lastTick = CACurrentMediaTime()
    private var lastReading: Double?
    private var simulating = false
    private var missedReads = 0
    private var frame = 0
    private var sentPressure = -1.0

    /// Voice ids started by each physical key, so key up stops what key down started even if
    /// the octave changed in between.
    private var sounding: [UInt16: [Int]] = [:]
    private var hingeKeys: Set<UInt16> = []
    private var simulatedAngle = 100.0
    private var lastSimulatedFeed = 0.0

    private init() {
        let store = UserDefaults.standard
        func load(_ key: String, _ fallback: Double, _ range: ClosedRange<Double>) -> Double {
            guard store.object(forKey: key) != nil else { return fallback }
            return min(max(store.double(forKey: key), range.lowerBound), range.upperBound)
        }
        sensitivity = load("sensitivity", Defaults.sensitivity, Self.sensitivityRange)
        hold = load("hold", Defaults.hold, Self.holdRange)
        tail = load("tail", Defaults.tail, Self.tailRange)
        applyFeel()
    }

    func resetFeel() {
        sensitivity = Defaults.sensitivity
        hold = Defaults.hold
        tail = Defaults.tail
    }

    private func applyFeel() {
        bellows.tuning.fullSpeed = fullSpeed
        bellows.tuning.hold = hold
        bellows.tuning.tail = tail
        let store = UserDefaults.standard
        store.set(sensitivity, forKey: "sensitivity")
        store.set(hold, forKey: "hold")
        store.set(tail, forKey: "tail")
    }

    func start() {
        guard timer == nil else { return }
        let synth = Synth()
        self.synth = synth
        audioError = synth.error
        connectSensor()

        let center = NSWorkspace.shared.notificationCenter
        // The HID handle can go stale across sleep.
        center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.connectSensor()
        }
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main
        ) { [weak self] _ in
            self?.synth?.restartIfNeeded()
        }

        let loop = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in self?.tick() }
        // .common keeps the loop running while a window drag or menu is tracking events.
        RunLoop.main.add(loop, forMode: .common)
        timer = loop
    }

    // MARK: Keys

    func keyDown(_ code: UInt16) {
        guard let action = Keymap.action(forKeyCode: code) else { return }
        switch action {
        case let .note(semitone):
            guard sounding[code] == nil else { return }
            let id = Int(code)
            sounding[code] = [id]
            synth?.send(.noteOn(id: id, midi: Self.baseMidi + octave * 12 + semitone, bank: .melody))
            heldNotes.insert(semitone)
        case let .chord(index):
            guard sounding[code] == nil else { return }
            let notes = Chord.all[index].midiNotes
            let ids = notes.indices.map { 10_000 + Int(code) * 8 + $0 }
            sounding[code] = ids
            for (id, midi) in zip(ids, notes) { synth?.send(.noteOn(id: id, midi: midi, bank: .bass)) }
            heldChords.insert(index)
        case .octaveDown:
            octave = max(octave - 1, -2)
        case .octaveUp:
            octave = min(octave + 1, 2)
        case .manualAir:
            manualAir = true
        case .hingeClose, .hingeOpen:
            if hingeKeys.isEmpty, let angle { simulatedAngle = angle }
            hingeKeys.insert(code)
        case .panic:
            releaseAll()
        }
    }

    func keyUp(_ code: UInt16) {
        hingeKeys.remove(code)
        if Keymap.action(forKeyCode: code) == .manualAir { manualAir = false }
        guard let ids = sounding.removeValue(forKey: code) else { return }
        for id in ids { synth?.send(.noteOff(id: id)) }
        switch Keymap.action(forKeyCode: code) {
        case let .note(semitone)?: heldNotes.remove(semitone)
        case let .chord(index)?: heldChords.remove(index)
        default: break
        }
    }

    func releaseAll() {
        sounding.removeAll()
        hingeKeys.removeAll()
        heldNotes.removeAll()
        heldChords.removeAll()
        manualAir = false
        synth?.send(.allOff)
    }

    // MARK: Loop

    private func connectSensor() {
        sensor = LidSensor()
        missedReads = 0
        sensorStatus = sensor == nil ? .missing : sensor!.isPrecise ? .precise : .wholeDegrees
        // A whole-degree sensor flickers by 1 degree between 10 Hz samples, which reads as 10 deg/s.
        bellows.tuning.deadzone = sensorStatus == .wholeDegrees ? 12 : 2
    }

    private func tick() {
        let now = CACurrentMediaTime()
        let dt = now - lastTick
        lastTick = now

        let hingeDirection = (hingeKeys.contains(124) ? 1.0 : 0) - (hingeKeys.contains(123) ? 1.0 : 0)
        if sensor == nil || !hingeKeys.isEmpty {
            simulateHinge(direction: hingeDirection, now: now, dt: dt)
            simulating = true
        } else {
            readSensor(now: now)
        }

        let reversed = bellows.tick(now: now, dt: dt, manualAir: manualAir ? Self.manualAirLevel : 0)
        if reversed, !sounding.isEmpty { synth?.send(.bellowsChange) }
        if abs(bellows.pressure - sentPressure) > 0.0005 {
            sentPressure = bellows.pressure
            synth?.send(.pressure(sentPressure))
        }

        // The view only needs about 30 updates a second.
        frame &+= 1
        if frame % 4 == 0 { publish() }
    }

    private func readSensor(now: Double) {
        guard let sensor else { return }
        if let reading = sensor.readAngle() {
            missedReads = 0
            // The sensor refreshes at about 10 Hz; repeats of the same value carry no motion.
            if simulating {
                // Back from the arrow keys: the hinge did not really jump to where it is.
                simulating = false
                lastReading = reading
                bellows.resync(angle: reading, time: now)
            } else if reading != lastReading {
                lastReading = reading
                bellows.ingest(angle: reading, time: now)
            }
        } else {
            missedReads += 1
            // Reads keep failing: reopen the device about every two seconds.
            if missedReads >= 240 { connectSensor() }
        }
    }

    private func simulateHinge(direction: Double, now: Double, dt: Double) {
        simulatedAngle += direction * Self.simulatedSpeed * dt
        simulatedAngle = min(max(simulatedAngle, Self.simulatedRange.lowerBound), Self.simulatedRange.upperBound)
        // Feed at the real sensor's pace so the bellows sees the same kind of input.
        if now - lastSimulatedFeed >= 0.05 {
            lastSimulatedFeed = now
            bellows.ingest(angle: simulatedAngle, time: now)
        }
    }

    private func publish() {
        if angle != bellows.angle { angle = bellows.angle }
        if abs(pressure - bellows.pressure) > 0.003 || (bellows.pressure == 0 && pressure != 0) {
            pressure = bellows.pressure
        }
        if direction != bellows.direction { direction = bellows.direction }
    }
}
