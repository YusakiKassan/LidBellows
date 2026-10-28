import Foundation
import Testing
@testable import BellowsCore

/// Drives the bellows the way the app does: 120 Hz ticks, with sensor samples arriving
/// every 0.1 s like the real hinge sensor.
private func run(
    _ bellows: inout Bellows, seconds: Double, start: Double = 0, angle: (Double) -> Double,
    manualAir: Double = 0
) -> (end: Double, reversals: Int) {
    let dt = 1.0 / 120
    var t = start
    var lastSample = -1.0
    var reversals = 0
    while t < start + seconds {
        if t - lastSample >= 0.1 {
            lastSample = t
            bellows.ingest(angle: angle(t), time: t)
        }
        if bellows.tick(now: t, dt: dt, manualAir: manualAir) { reversals += 1 }
        t += dt
    }
    return (t, reversals)
}

@Test func stillLidWithJitterIsSilent() {
    var b = Bellows()
    // ±0.05° of sensor noise, the size measured on a real MacBook at rest.
    _ = run(&b, seconds: 2) { t in 107 + 0.05 * sin(t * 37) }
    #expect(b.pressure == 0)
    #expect(b.direction == .still)
}

@Test func fasterMotionMakesMorePressure() {
    var slow = Bellows()
    var fast = Bellows()
    _ = run(&slow, seconds: 1) { 60 + 20 * $0 }
    _ = run(&fast, seconds: 1) { 60 + 60 * $0 }
    #expect(slow.pressure > 0.1)
    #expect(fast.pressure > slow.pressure + 0.2)
    #expect(fast.direction == .opening)
}

@Test func fullSpeedSaturates() {
    var b = Bellows()
    _ = run(&b, seconds: 0.8) { 40 + 150 * $0 }
    #expect(b.pressure > 0.97)
    #expect(b.pressure <= 1)
}

@Test func pressureIsHeldThenLeaksAfterTheLidStops() {
    var b = Bellows()
    let tuning = b.tuning
    let (end, _) = run(&b, seconds: 0.6) { 60 + 60 * $0 }
    let peak = b.pressure
    let stopAngle = 60 + 60 * end
    // During the hold the air barely drops...
    _ = run(&b, seconds: tuning.hold, start: end) { _ in stopAngle }
    #expect(b.pressure > 0.8 * peak)
    // ...after the tail it is down to about 5 percent...
    _ = run(&b, seconds: tuning.tail, start: end + tuning.hold) { _ in stopAngle }
    #expect(b.pressure < 0.08 * peak)
    // ...and soon after that it is inaudible.
    _ = run(&b, seconds: 1.5, start: end + tuning.hold + tuning.tail) { _ in stopAngle }
    #expect(b.pressure < 0.01)
}

@Test func turningTheLidAroundKeepsTheAir() {
    var b = Bellows()
    // Open at 30 deg/s, pause 0.3 s to turn around, then close at 30 deg/s.
    let angle: (Double) -> Double = { t in
        if t < 0.8 { return 80 + 30 * t }
        if t < 1.1 { return 104 }
        return 104 - 30 * (t - 1.1)
    }
    _ = run(&b, seconds: 0.8, angle: angle)
    let before = b.pressure
    var lowest = before
    let dt = 1.0 / 120
    var t = 0.8
    var lastSample = 0.8
    while t < 1.8 {
        if t - lastSample >= 0.1 {
            lastSample = t
            b.ingest(angle: angle(t), time: t)
        }
        b.tick(now: t, dt: dt)
        lowest = min(lowest, b.pressure)
        t += dt
    }
    #expect(before > 0.5)
    #expect(lowest > 0.6 * before)
    #expect(b.pressure > 0.8 * before)
}

@Test func gentleMotionIsAudible() {
    var b = Bellows()
    _ = run(&b, seconds: 1) { 80 + 10 * $0 }
    #expect(b.pressure > 0.25)
}

@Test func higherSensitivityNeedsLessMotion() {
    var dull = Bellows()
    var keen = Bellows()
    dull.tuning.fullSpeed = 90
    keen.tuning.fullSpeed = 20
    _ = run(&dull, seconds: 1) { 80 + 15 * $0 }
    _ = run(&keen, seconds: 1) { 80 + 15 * $0 }
    #expect(keen.pressure > dull.pressure + 0.3)
}

@Test func reversingReportsOneBellowsChange() {
    var b = Bellows()
    // Open for half a second, then close.
    let (_, reversals) = run(&b, seconds: 1) { t in t < 0.5 ? 60 + 60 * t : 90 - 60 * (t - 0.5) }
    #expect(reversals == 1)
    #expect(b.direction == .closing)
}

@Test func manualAirHoldsAFloor() {
    var b = Bellows()
    _ = run(&b, seconds: 1, angle: { _ in 100 }, manualAir: 0.6)
    #expect(abs(b.pressure - 0.6) < 0.01)
}

@Test func longGapDoesNotReadAsAFastSwing() {
    var b = Bellows()
    b.ingest(angle: 30, time: 0)
    b.ingest(angle: 120, time: 2) // e.g. the app was asleep
    b.tick(now: 2, dt: 1.0 / 120)
    #expect(b.velocity == 0)
}

@Test func resyncSwallowsTheJump() {
    var b = Bellows()
    _ = run(&b, seconds: 0.5) { _ in 130 }
    b.resync(angle: 100, time: 0.5)
    _ = run(&b, seconds: 0.5, start: 0.5) { _ in 100 }
    #expect(b.pressure == 0)
}

@Test func wholeDegreeFlickerIsSilentWithItsDeadzone() {
    var b = Bellows()
    // Whole-degree sensors flip between neighbouring readings while the lid rests.
    b.tuning.deadzone = 12
    _ = run(&b, seconds: 2) { t in Int(t * 10) % 2 == 0 ? 107 : 108 }
    #expect(b.pressure == 0)
}
