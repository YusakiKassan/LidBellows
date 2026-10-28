import Foundation

/// Turns lid-angle samples into bellows air pressure.
///
/// The sensor refreshes at roughly 10 Hz and, while the lid is still, jitters by a few
/// hundredths of a degree. Velocity is the least-squares slope of the samples from the last
/// quarter second, which rides over both the coarse sample rate and the jitter. Once samples
/// stop arriving the lid is taken to be resting where it was last seen, so the slope falls to
/// zero by itself.
///
/// Pressure chases the lid speed with a fast attack and a slow leak. When the lid stops,
/// pressure is held for a moment before it starts leaking, so turning the lid around does not
/// empty the bellows.
public struct Bellows {
    public enum Direction: Equatable { case closing, still, opening }

    public struct Tuning {
        /// Lid speed (degrees per second) below which there is no air: sensor jitter, not motion.
        /// The precise sensor jitters by about 1 deg/s; whole-degree sensors need a wider band.
        public var deadzone = 2.0
        /// Lid speed that gives full pressure. Lower is more sensitive.
        public var fullSpeed = 45.0
        /// Shapes the speed-to-pressure curve; under 1 makes gentle motion audible sooner.
        public var curve = 0.6
        /// Time constant while pressure rises.
        public var attack = 0.04
        /// Seconds the pressure is held, without leaking, after the lid stops. Covers the pause
        /// while the hand turns the lid around.
        public var hold = 0.4
        /// Seconds for pressure to fall to 5 percent, once the hold is over or while the lid slows.
        public var tail = 1.5
        /// Seconds of samples the velocity is fitted over.
        public var window = 0.25
        /// No new sample for this long means the lid is resting where it was last seen.
        public var staleAfter = 0.16
        /// A gap longer than this restarts velocity tracking instead of reading as one fast swing.
        public var gap = 0.5

        public init() {}
    }

    public var tuning: Tuning
    public private(set) var angle: Double?
    /// Degrees per second, positive while opening.
    public private(set) var velocity = 0.0
    /// 0...1
    public private(set) var pressure = 0.0
    public private(set) var direction = Direction.still

    /// Recent samples, oldest first, at most `tuning.window` old.
    private var history: [(angle: Double, time: Double)] = []
    /// Direction of the last real stroke, kept through pauses so a reversal can be spotted.
    private var stroke = Direction.still
    private var lastMotionTime = -Double.infinity

    public init(tuning: Tuning = Tuning()) {
        self.tuning = tuning
        history.reserveCapacity(16)
    }

    /// Feed a sensor sample. Call only when the reading changes, with a monotonic time in seconds.
    public mutating func ingest(angle: Double, time: Double) {
        if let newest = history.last, time - newest.time > tuning.gap || time < newest.time {
            history.removeAll(keepingCapacity: true)
        }
        history.append((angle, time))
        self.angle = angle
    }

    /// Start velocity tracking over from `angle`, e.g. when switching between the simulated
    /// hinge and the real one, so the jump between them does not read as a swing.
    public mutating func resync(angle: Double, time: Double) {
        history.removeAll(keepingCapacity: true)
        history.append((angle, time))
        self.angle = angle
    }

    /// Advance the model. `manualAir` (0...1) is a floor on pressure, e.g. while Space is held.
    /// Returns true on the tick the lid reverses direction, the moment an accordionist's
    /// bellows change re-articulates the held notes.
    @discardableResult
    public mutating func tick(now: Double, dt: Double, manualAir: Double = 0) -> Bool {
        let dt = max(dt, 0)
        history.removeAll { now - $0.time > tuning.window }
        velocity = fittedSlope(now: now)

        let speed = abs(velocity)
        // Schmitt trigger: start a stroke above the deadzone, end it below half of it.
        let moving = direction == .still ? speed > tuning.deadzone : speed > tuning.deadzone / 2
        var reversed = false
        if moving {
            direction = velocity > 0 ? .opening : .closing
            reversed = stroke != .still && stroke != direction
            stroke = direction
            lastMotionTime = now
        } else {
            direction = .still
        }

        let span = max(tuning.fullSpeed - tuning.deadzone, 1)
        let level = min(max((speed - tuning.deadzone) / span, 0), 1)
        let target = max(pow(level, tuning.curve), min(max(manualAir, 0), 1))
        if target > pressure {
            pressure += (target - pressure) * (1 - exp(-dt / tuning.attack))
        } else if moving || now - lastMotionTime >= tuning.hold {
            // An exponential leak reaches 5 percent after three time constants.
            pressure += (target - pressure) * (1 - exp(-dt / max(tuning.tail / 3, 0.01)))
        }
        if pressure < 0.0005 { pressure = 0 }
        return reversed
    }

    /// Least-squares slope of angle over time across the recent samples. When the newest sample
    /// is stale, a point at `now` with the same angle stands in for the readings that did not come.
    private func fittedSlope(now: Double) -> Double {
        guard let newest = history.last else { return 0 }
        let resting = now - newest.time > tuning.staleAfter
        let count = Double(history.count + (resting ? 1 : 0))
        guard count >= 2 else { return 0 }

        // Times relative to `now` keep the sums well conditioned.
        var sumT = 0.0, sumA = 0.0, sumTT = 0.0, sumTA = 0.0
        func add(_ angle: Double, _ time: Double) {
            let t = time - now
            sumT += t
            sumA += angle
            sumTT += t * t
            sumTA += t * angle
        }
        for sample in history { add(sample.angle, sample.time) }
        if resting { add(newest.angle, now) }

        let denominator = count * sumTT - sumT * sumT
        guard denominator > 1e-9 else { return 0 }
        return (count * sumTA - sumT * sumA) / denominator
    }
}
