import Foundation

/// A moment setup or the box went wrong — or a box saying it's well — noted
/// for whoever runs the boxes (migration 0021). A fixed list, a box at most,
/// a few small facts. Never what's on the screen, and never waited on.
/// Settings says this happens.
public enum Note: String, Sendable, CaseIterable {
    case paired
    case pairNotHeard  = "pair_not_heard"
    case dockFailed    = "dock_failed"
    case cameraDenied  = "camera_denied"
    case bluetoothOff  = "bluetooth_off"
    case activitiesOff = "activities_off"
    case boxHello      = "box_hello"

    /// How often the same note, for the same box, is worth sending. Something
    /// that happened, every time; a state that stays put, once a day; a box's
    /// hello, once an hour — the phone reconnects all evening.
    public var every: TimeInterval {
        switch self {
        case .paired, .pairNotHeard, .dockFailed:        0
        case .cameraDenied, .bluetoothOff, .activitiesOff: 24 * 3600
        case .boxHello:                                    3600
        }
    }

    /// Whether to send it now, given when it last went. A hello goes at once
    /// if the box has restarted since the last one: that's the news.
    public func due(last: Date?, at now: Date = .now, bootsThen: Int? = nil, bootsNow: Int? = nil) -> Bool {
        guard let last else { return true }
        if self == .boxHello, let bootsNow, bootsNow != bootsThen { return true }
        return now.timeIntervalSince(last) >= every
    }
}

/// When each note last went from this phone, per box, so `Note.due` has
/// something to go by. Kept on this phone only.
public enum NoteLog {
    private static let key = "notes.last"
    private static let bootsKey = "notes.boots"

    private static func id(_ note: Note, _ place: UUID?) -> String {
        "\(note.rawValue)/\(place?.uuidString ?? "-")"
    }

    /// True, and remembered as sent, when the note is due.
    public static func take(_ note: Note, place: UUID?, boots: Int? = nil, at now: Date = .now) -> Bool {
        let defaults = UserDefaults.standard
        var last = defaults.dictionary(forKey: key) as? [String: Double] ?? [:]
        var sentBoots = defaults.dictionary(forKey: bootsKey) as? [String: Int] ?? [:]
        let id = id(note, place)
        let then = last[id].map(Date.init(timeIntervalSince1970:))
        guard note.due(last: then, at: now, bootsThen: sentBoots[id], bootsNow: boots) else { return false }
        last[id] = now.timeIntervalSince1970
        if let boots { sentBoots[id] = boots }
        defaults.set(last, forKey: key)
        defaults.set(sentBoots, forKey: bootsKey)
        return true
    }
}
