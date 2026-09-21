import XCTest
import Supabase
@testable import ReclaimKit

/// The round trip through Realtime, without a socket.
///
/// `sent(_:)` does what the SDK does on each end: `broadcast(event:message:)`
/// turns the message into a `JSONObject` with `JSONEncoder.supabase()`, and
/// the receiving channel hands its callback the whole envelope. If either of
/// those changes in a supabase-swift update, these fail rather than the table
/// going quiet.
final class CeremonyWireTests: XCTestCase {

    private let me = UUID()
    private let them = UUID()
    private let at = Date(timeIntervalSince1970: 1_790_000_000)

    private func sent(_ message: some Codable, event: String) throws -> JSONObject {
        ["event": .string(event), "payload": .object(try JSONObject(message)), "type": "broadcast"]
    }

    func testAnInvitationSurvivesTheRoundTrip() throws {
        let invitation = Invitation(gathering: UUID(), place: UUID(), name: "Maya", count: 2, at: at)
        let back = CeremonyWire.unwrap(try sent(invitation, event: "invitation"), as: Invitation.self)
        XCTAssertEqual(back?.gathering, invitation.gathering)
        XCTAssertEqual(back?.name, "Maya")
        XCTAssertEqual(back?.count, 2)
        XCTAssertEqual(back?.at.timeIntervalSince1970 ?? 0, at.timeIntervalSince1970, accuracy: 0.001)
    }

    /// The bug this replaced: decoding what we sent from the top of the
    /// envelope, where it isn't.
    func testThePayloadIsInsideTheEnvelopeNotAtItsTop() throws {
        let envelope = try sent(CeremonyWire.payload(for: .released(profile: them), from: them),
                                event: "ceremony")
        XCTAssertNil(try? AnyJSON.object(envelope).decode(as: CeremonyWire.Payload.self))
        XCTAssertNotNil(CeremonyWire.unwrap(envelope, as: CeremonyWire.Payload.self))
    }

    /// The other one: the SDK writes dates as strings, so a plain decoder
    /// can't read an invitation back.
    func testThePlainDecoderCannotReadTheSDKsDates() throws {
        let invitation = Invitation(gathering: UUID(), place: UUID(), name: nil, count: 1, at: at)
        let data = try JSONEncoder().encode(AnyJSON.object(try JSONObject(invitation)))
        XCTAssertThrowsError(try JSONDecoder().decode(Invitation.self, from: data))
    }

    func testEveryCeremonyEventSurvivesTheRoundTrip() throws {
        let events: [CeremonyEvent] = [
            .docked(at: at),
            .faceDown(profile: them, down: true),
            .faceDown(profile: them, down: false),
            .released(profile: them)
        ]
        for event in events {
            let envelope = try sent(CeremonyWire.payload(for: event, from: them), event: "ceremony")
            let p = try XCTUnwrap(CeremonyWire.unwrap(envelope, as: CeremonyWire.Payload.self))
            XCTAssertEqual(CeremonyWire.event(from: p, me: me), event)
        }
    }

    /// The app renders your own tap on send; an echo would count you twice.
    func testYourOwnEventIsNotDeliveredBackToYou() {
        let p = CeremonyWire.payload(for: .released(profile: me), from: me)
        XCTAssertNil(CeremonyWire.event(from: p, me: me))
    }

    func testAnUnknownKindIsIgnored() {
        let p = CeremonyWire.Payload(kind: "wave", sender: them.uuidString, at: nil, down: nil)
        XCTAssertNil(CeremonyWire.event(from: p, me: me))
    }
}
