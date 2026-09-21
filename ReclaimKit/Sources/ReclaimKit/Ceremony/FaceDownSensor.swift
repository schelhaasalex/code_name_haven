import Foundation
import CoreMotion

/// Face-down is CEREMONY, NOT EVIDENCE.
///
/// A phone in a pocket is not face down and its owner is entirely present; a
/// phone face up and ignored is the same. So nothing is ever gated on this —
/// it exists so the app can answer the gesture with a haptic at the right
/// instant, and so the table can watch its own count climb.
///
/// Foreground only. Streaming raw accelerometer in the background is
/// restricted, and we deliberately don't ask for the permission that would
/// loosen it. The window where this matters is the window where the app is
/// open, which is exactly when the gesture happens.
@MainActor
public final class FaceDownSensor {

    private let motion = CMMotionManager()
    private var onChange: ((Bool) -> Void)?
    public private(set) var isFaceDown = false

    public init() {}

    public func start(_ onChange: @escaping (Bool) -> Void) {
        guard motion.isAccelerometerAvailable, !motion.isAccelerometerActive else { return }
        self.onChange = onChange
        motion.accelerometerUpdateInterval = 1.0 / 10.0
        motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let z = data?.acceleration.z else { return }
            // z ≈ -1 when the screen faces the table. A generous threshold,
            // because a wobbly phone on a tablecloth should still read as down.
            let down = z < -0.72
            if down != self.isFaceDown {
                self.isFaceDown = down
                self.onChange?(down)
            }
        }
    }

    public func stop() {
        motion.stopAccelerometerUpdates()
        onChange = nil
    }

    deinit { motion.stopAccelerometerUpdates() }
}
