import Foundation
import AVFoundation
import UIKit

/// The moment: a soft two-note chime and a haptic, together.
///
/// Timing here is the reference from prototype/ceremony.html, which is the
/// thing to test at a real table. Whatever the dinner settles, change it here.
@MainActor
public enum Sensation {

    private nonisolated(unsafe) static var engine: AVAudioEngine?
    private nonisolated(unsafe) static var player: AVAudioPlayerNode?

    /// One transient, then a softer one 160ms later — the same interval as the
    /// two notes, so the buzz and the chime read as one event rather than two.
    public static func docked() {
        let heavy = UIImpactFeedbackGenerator(style: .medium)
        heavy.prepare(); heavy.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        chime()
    }

    public static func joined() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    public static func ended() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// G4 then D5 — a fifth, which reads as settled rather than alerting.
    /// Generated rather than shipped as an asset, so it's tunable in one line.
    private static func chime() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        let rate = 44_100.0
        let seconds = 1.8
        let frames = AVAudioFrameCount(rate * seconds)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)
        else { return }
        buffer.frameLength = frames

        let notes: [(hz: Double, delay: Double)] = [(392.0, 0.0), (587.33, 0.16)]
        if let channel = buffer.floatChannelData?[0] {
            for i in 0..<Int(frames) {
                let t = Double(i) / rate
                var sample = 0.0
                for note in notes where t >= note.delay {
                    let local = t - note.delay
                    let envelope = exp(-3.1 * local)
                    sample += sin(2 * .pi * note.hz * local) * envelope * 0.22
                }
                channel[i] = Float(sample)
            }
        }

        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? engine.start()
        player.scheduleBuffer(buffer, at: nil, options: []) {
            DispatchQueue.main.async { engine.stop(); Self.engine = nil; Self.player = nil }
        }
        player.play()
        Self.engine = engine
        Self.player = player
    }
}
