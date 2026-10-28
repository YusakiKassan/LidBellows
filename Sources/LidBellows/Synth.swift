import AVFoundation
import BellowsCore
import os

/// Free-reed accordion synthesizer.
///
/// Threading: the main thread only appends commands to a small queue. The render thread
/// owns all voice state and drains the queue with a try-lock, so it never waits on the main
/// thread and never allocates while rendering.
final class Synth {
    enum Bank: UInt8 { case melody, bass }

    enum Command {
        case noteOn(id: Int, midi: Int, bank: Bank)
        case noteOff(id: Int)
        case allOff
        case pressure(Double)
        case bellowsChange
    }

    private struct Queue {
        var items: [Command] = []
        init() { items.reserveCapacity(Self.capacity) }
        static let capacity = 512
    }

    private let queue = OSAllocatedUnfairLock(initialState: Queue())
    private let engine = AVAudioEngine()
    private let reverb = AVAudioUnitReverb()
    private var dsp: DSP?
    private(set) var error: String?

    init() {
        let output = engine.outputNode.outputFormat(forBus: 0)
        let sampleRate = output.sampleRate > 0 ? output.sampleRate : 48_000
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            error = "Unsupported audio format"
            return
        }
        let dsp = DSP(sampleRate: sampleRate)
        self.dsp = dsp
        let queue = self.queue
        let source = AVAudioSourceNode(format: format) { _, _, frameCount, bufferList in
            queue.withLockIfAvailable { state in
                for command in state.items { dsp.handle(command) }
                state.items.removeAll(keepingCapacity: true)
            }
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            guard buffers.count >= 2,
                  let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
                  let right = buffers[1].mData?.assumingMemoryBound(to: Float.self)
            else { return noErr }
            dsp.render(left: left, right: right, frames: Int(frameCount))
            return noErr
        }
        reverb.loadFactoryPreset(.smallRoom)
        reverb.wetDryMix = 14
        engine.attach(source)
        engine.attach(reverb)
        engine.connect(source, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
        } catch {
            self.error = "Audio failed to start: \(error.localizedDescription)"
        }
    }

    /// Restart after the output device changes (headphones, Bluetooth).
    func restartIfNeeded() {
        guard !engine.isRunning else { return }
        try? engine.start()
    }

    func send(_ command: Command) {
        queue.withLock { state in
            // A full queue means the audio thread has stalled; dropping is better than blocking.
            if state.items.count < Queue.capacity { state.items.append(command) }
        }
    }
}

/// Render-thread state. Touched only from the audio callback.
private final class DSP {
    struct Voice {
        var id = -1
        var bank = Synth.Bank.melody
        var freq = 0.0
        var phase: (Double, Double, Double) = (0, 0, 0)
        var env = 0.0
        var gate = false
        var active = false
        var age = 0
    }

    // Musette tuning: one reed flat, one in tune, one sharp. The beating between them is
    // what makes it sound like an accordion rather than an organ.
    static let reedCents = (-12.0, 0.0, 11.0)
    static let reedGain = (0.32, 0.42, 0.30)
    static let maxVoices = 24

    let sampleRate: Double
    var voices = [Voice](repeating: Voice(), count: DSP.maxVoices)
    let reedRatio: (Double, Double, Double)

    var targetPressure = 0.0
    var pressure = 0.0
    var articulation = 1.0
    var rng: UInt32 = 0x9E37_79B9
    var noiseState = 0.0
    var clock = 0

    // Lowpass biquad whose cutoff follows the pressure: harder pushes sound brighter.
    var b0 = 0.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0
    var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

    let attackCoef: Double
    let releaseCoef: Double
    let pressureCoef: Double
    let articulationCoef: Double

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        func ratio(_ cents: Double) -> Double { pow(2, cents / 1200) }
        reedRatio = (ratio(Self.reedCents.0), ratio(Self.reedCents.1), ratio(Self.reedCents.2))
        func coef(_ seconds: Double) -> Double { 1 - exp(-1 / (seconds * sampleRate)) }
        attackCoef = coef(0.012)
        releaseCoef = coef(0.06)
        pressureCoef = coef(0.015)
        articulationCoef = coef(0.05)
        setCutoff(400)
    }

    func handle(_ command: Synth.Command) {
        switch command {
        case let .noteOn(id, midi, bank):
            noteOn(id: id, midi: midi, bank: bank)
        case let .noteOff(id):
            for i in voices.indices where voices[i].id == id && voices[i].gate {
                voices[i].gate = false
            }
        case .allOff:
            for i in voices.indices { voices[i].gate = false }
        case let .pressure(value):
            targetPressure = value
        case .bellowsChange:
            articulation = 0.75
        }
    }

    private func noteOn(id: Int, midi: Int, bank: Synth.Bank) {
        // Steal order: a free voice, then the quietest released one, then the oldest.
        // A plain loop, because filter would allocate on the audio thread.
        var free = -1, quietest = -1, oldest = 0
        for i in voices.indices {
            let v = voices[i]
            if !v.active { free = i; break }
            if !v.gate && (quietest < 0 || v.env < voices[quietest].env) { quietest = i }
            if v.age > voices[oldest].age { oldest = i }
        }
        let index = free >= 0 ? free : quietest >= 0 ? quietest : oldest
        // A fixed per-note drift of up to ±2 cents, like reeds that were never tuned perfectly.
        let drift = Double((midi &* 2_654_435_761) & 0xFFFF) / 65_535 * 4 - 2
        voices[index] = Voice(
            id: id, bank: bank,
            freq: Pitch.frequency(midi: midi) * pow(2, drift / 1200),
            phase: (0.13, 0.41, 0.77), env: 0, gate: true, active: true, age: 0)
    }

    private func setCutoff(_ hz: Double) {
        let fc = min(hz, 0.45 * sampleRate)
        let w = 2 * Double.pi * fc / sampleRate
        let alpha = sin(w) / (2 * 0.8)
        let cosw = cos(w)
        let a0 = 1 + alpha
        b0 = (1 - cosw) / 2 / a0
        b1 = (1 - cosw) / a0
        b2 = b0
        a1 = -2 * cosw / a0
        a2 = (1 - alpha) / a0
    }

    @inline(__always) private func polyBlep(_ t: Double, _ dt: Double) -> Double {
        if t < dt {
            let x = t / dt
            return x + x - x * x - 1
        } else if t > 1 - dt {
            let x = (t - 1) / dt
            return x * x + x + x + 1
        }
        return 0
    }

    /// Band-limited sawtooth, so high notes do not alias into hiss.
    @inline(__always) private func saw(_ phase: inout Double, _ inc: Double) -> Double {
        let value = 2 * phase - 1 - polyBlep(phase, inc)
        phase += inc
        if phase >= 1 { phase -= 1 }
        return value
    }

    @inline(__always) private func noise() -> Double {
        rng ^= rng << 13
        rng ^= rng >> 17
        rng ^= rng << 5
        return Double(Int32(bitPattern: rng)) / 2_147_483_648
    }

    func render(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        let invRate = 1 / sampleRate
        for frame in 0..<frames {
            pressure += (targetPressure - pressure) * pressureCoef
            articulation += (1 - articulation) * articulationCoef
            if clock & 31 == 0 { setCutoff(350 + 5200 * pow(pressure, 1.8)) }
            clock &+= 1

            var mix = 0.0
            var anyGate = false
            for i in 0..<voices.count where voices[i].active {
                var v = voices[i]
                if v.gate {
                    anyGate = true
                    v.env += (1 - v.env) * attackCoef
                } else {
                    v.env -= v.env * releaseCoef
                    if v.env < 0.0005 {
                        voices[i].active = false
                        continue
                    }
                }
                let inc = v.freq * invRate
                var sample: Double
                switch v.bank {
                case .melody:
                    sample = saw(&v.phase.0, inc * reedRatio.0) * Self.reedGain.0
                        + saw(&v.phase.1, inc * reedRatio.1) * Self.reedGain.1
                        + saw(&v.phase.2, inc * reedRatio.2) * Self.reedGain.2
                case .bass:
                    // Bass reeds: one reed plus a softer octave below, no musette beating.
                    sample = saw(&v.phase.0, inc) * 0.5 + saw(&v.phase.1, inc * 0.5) * 0.3
                }
                mix += sample * v.env * (v.bank == .melody ? 0.24 : 0.13)
                v.age &+= 1
                voices[i] = v
            }

            // A little air hiss rides on the reeds while the bellows move.
            if anyGate {
                noiseState += (noise() - noiseState) * 0.2
                mix += noiseState * 0.012 * pressure
            }

            let gain = pow(pressure, 1.1) * articulation
            let x = mix * gain
            let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1; x1 = x
            y2 = y1; y1 = y
            // Soft clip keeps big chords from distorting harshly.
            let out = Float(tanh(y * 1.4) * 0.8)
            left[frame] = out
            right[frame] = out
        }
    }
}
