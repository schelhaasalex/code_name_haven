import XCTest
@testable import ReclaimKit

final class AutoClosedTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func session(minutesAgo: Double = 60, autoClosed: Bool = false) -> Session {
        let started = now.addingTimeInterval(-minutesAgo * 60)
        return Session(id: UUID(), profileId: UUID(), gatheringId: UUID(),
                       startedAt: started, endedAt: started.addingTimeInterval(3600),
                       durationMinutes: 60, localDate: "2026-09-21",
                       qualifying: true, autoClosed: autoClosed)
    }

    func testNothingToSayIsTheCommonCase() {
        XCTAssertNil(AutoClosed.latest(in: [session(), session(minutesAgo: 900)]))
        XCTAssertNil(AutoClosed.latest(in: []))
    }

    func testTheMostRecentIsTheOneWeExplain() {
        let older = session(minutesAgo: 2000, autoClosed: true)
        let newer = session(minutesAgo: 300, autoClosed: true)
        XCTAssertEqual(AutoClosed.latest(in: [older, newer, session()]), newer)
        XCTAssertEqual(AutoClosed.latest(in: [newer, older]), newer,
                       "the order the rows arrive in must not decide this")
    }

    /// The lock screen goes quiet at the cap, so it has to be the server's
    /// cap: the last migration that defines `app.auto_close_minutes`.
    func testTheCapIsTheServers() throws {
        let migrations = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("supabase/migrations")
        let files = try FileManager.default.contentsOfDirectory(atPath: migrations.path)
            .filter { $0.hasSuffix(".sql") }.sorted()
        var cap: Int?
        for file in files {
            let sql = try String(contentsOf: migrations.appendingPathComponent(file), encoding: .utf8)
            guard let at = sql.range(of: "function app.auto_close_minutes()") else { continue }
            let rest = sql[at.upperBound...]
            if let body = rest.range(of: #"select (\d+)"#, options: .regularExpression) {
                cap = Int(rest[body].dropFirst("select ".count))
            }
        }
        XCTAssertEqual(cap, AutoClosed.capMinutes)
        XCTAssertEqual(AutoClosed.cap, TimeInterval(AutoClosed.capMinutes * 60))
    }
}
