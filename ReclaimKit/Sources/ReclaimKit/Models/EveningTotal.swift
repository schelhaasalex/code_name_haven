import Foundation

/// Every evening you've had, as a number and a first date (migration 0011).
///
/// The same unit as the dot week and the rhythm: distinct qualifying
/// `local_date`s, so a five-person dinner is one. It only goes up.
public struct EveningTotal: Codable, Hashable, Sendable {
    public let count: Int
    /// The first one, as Postgres sends a `date`: "yyyy-MM-dd".
    public let first: String?

    enum CodingKeys: String, CodingKey {
        case count = "evenings"
        case first = "first_evening"
    }

    public init(count: Int, first: String?) {
        self.count = count
        self.first = first
    }

    public static let none = EveningTotal(count: 0, first: nil)
}
