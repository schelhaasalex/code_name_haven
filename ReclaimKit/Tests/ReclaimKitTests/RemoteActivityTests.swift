import XCTest
@testable import ReclaimKit

final class RemoteActivityTests: XCTestCase {

    private let gathering = UUID(uuidString: "D0DF523F-E265-492D-92DC-512D285CAFF3")!
    private let state = ReclaimActivityAttributes.ContentState(
        startedAt: Date(timeIntervalSince1970: 1_792_700_000), memberCount: 2, placeName: "Low Vole")

    private func body() throws -> [String: Any] {
        let data = try RemoteActivity.startBody(gatheringId: gathering, state: state,
                                                title: "Docked at Low Vole", body: "See you in a bit.")
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// The failure this guards against is silent: a date written as an ISO
    /// string, or as seconds since 1970, and the push arrives and the Live
    /// Activity never appears. ActivityKit decodes with a plain decoder, so
    /// the date is seconds since 2001.
    func testTheStartTimeIsWhatActivityKitDecodes() throws {
        let content = try XCTUnwrap(body()["contentState"] as? [String: Any])
        let seconds = try XCTUnwrap(content["startedAt"] as? Double)
        XCTAssertEqual(seconds, state.startedAt.timeIntervalSinceReferenceDate, accuracy: 0.001)

        let decoded = try JSONDecoder().decode(ReclaimActivityAttributes.ContentState.self,
                                               from: JSONSerialization.data(withJSONObject: content))
        XCTAssertEqual(decoded, state, "a plain decoder reads back exactly what was sent")
    }

    /// The server refuses a body whose two gathering ids disagree.
    func testTheAttributesNameTheSameEvening() throws {
        let b = try body()
        let attributes = try XCTUnwrap(b["attributes"] as? [String: Any])
        XCTAssertEqual(b["gatheringId"] as? String, gathering.uuidString)
        XCTAssertEqual(attributes["gatheringId"] as? String, gathering.uuidString)
    }

    func testTheAlertCarriesTheWordsItWasGiven() throws {
        let alert = try XCTUnwrap(body()["alert"] as? [String: String])
        XCTAssertEqual(alert, ["title": "Docked at Low Vole", "body": "See you in a bit."])
    }

    func testATokenIsLowercaseHex() {
        XCTAssertEqual(RemoteActivity.hex(Data([0x00, 0xAB, 0x0F, 0xFF])), "00ab0fff")
    }
}
