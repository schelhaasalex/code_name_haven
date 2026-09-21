import Foundation

extension Date {
    /// "7:40" — the only time format the app shows.
    var shortTime: String { formatted(date: .omitted, time: .shortened) }
}
