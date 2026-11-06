import Foundation

/// The evening charges: the phone in the box, and the person away from it.
///
/// Four segments, full at fifteen minutes, half an hour, an hour and an hour
/// and a half, and then the ring holds. It only ever fills — an evening that
/// stops early is a ring partly full, never one with a gap marked missing —
/// and a light joins it for each person who has put their phone down.
///
/// The server decides each step from the same four numbers
/// (`app.charge_stage`, migration 0016), because the phone is asleep when it
/// happens. `scripts/shape.sh` checks the two lists agree.
public enum EveningCharge {

    /// The first is the fifteen minutes an evening needs to count, so
    /// "Tonight counts." is true the moment it appears.
    public static let minutes = [15, 30, 60, 90]

    /// The last stage: full, glowing, held until the evening ends.
    public static var full: Int { minutes.count }

    /// More lights than this crowd a ring 30 points across.
    public static let mostLights = 6

    public static func stage(minutes elapsed: Double) -> Int {
        minutes.filter { elapsed >= Double($0) }.count
    }

    public static func stage(since start: Date, at now: Date = Date()) -> Int {
        stage(minutes: now.timeIntervalSince(start) / 60)
    }

    /// A light for each person — but not for one alone: a single light on the
    /// ring would only be you, which the ring already is.
    public static func lights(memberCount: Int) -> Int {
        memberCount > 1 ? min(memberCount, mostLights) : 0
    }

    /// Where the lights sit, as angles in degrees clockwise from the top,
    /// spread evenly from the first.
    public static func lightAngles(_ count: Int) -> [Double] {
        guard count > 0 else { return [] }
        return (0..<count).map { 45 + Double($0) * 360 / Double(count) }
    }
}
