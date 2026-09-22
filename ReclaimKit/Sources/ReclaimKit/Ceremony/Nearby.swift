import Foundation

/// The phone-to-phone part of the ritual: one phone already down at a table,
/// the others noticing from across it with nothing to scan and nothing to set
/// up. Migration 0010 is the other half.
///
/// WHAT TRAVELS IS A KEY, NOT AN ADDRESS. A place id would work and would
/// never expire; this one is worthless the moment the evening ends. Nothing
/// about the place, the people or their names goes over the air — the phone
/// that hears it learns only that somewhere near it, an evening is open, and
/// it learns that from the server, not from the radio.
///
/// The ids are fixed and public. They have to be: a phone advertising in the
/// background gets no name and no data in its advertisement, only service
/// ids in the overflow area, and a central can only find those by asking for
/// them exactly. Anyone may therefore see that a phone is advertising this
/// service; what they cannot do is read the key without connecting, or use it
/// without an account.
public enum Nearby {

    /// The service a phone with its face down advertises.
    public static let service = "8A06E37A-62DC-49B8-A01C-7E66F4935549"
    /// The one characteristic on it: the key, as UTF-8 text, read by the
    /// phone that connects.
    public static let characteristic = "754192A7-B9AE-4C7E-9E3D-D11A2FEB9C8D"

    /// 18 random bytes, base64url — what `app.open_nearby()` mints.
    static let keyLength = 24
    private static let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")

    public static func data(for key: String) -> Data { Data(key.utf8) }

    /// What came back off a stranger's radio, believed only as far as its
    /// shape. Any device in the world may advertise these ids and answer with
    /// anything at all; a key that doesn't look like one of ours never
    /// becomes a request.
    public static func key(from data: Data?) -> String? {
        guard let data, data.count == keyLength,
              let text = String(data: data, encoding: .utf8),
              text.count == keyLength,
              text.allSatisfy({ allowed.contains($0) })
        else { return nil }
        return text
    }
}

/// Which keys have already been asked about.
///
/// The radio finds the same table every few seconds for as long as you stand
/// near it. Asking once is an offer; asking again is the nagging this product
/// exists to replace — so a key gets one question, ever, and "not right now"
/// is taken at its word for the rest of that evening.
public struct NearbyOffers: Sendable {

    private var seen: Set<String> = []

    public init() {}

    /// True the first time this key is worth a question, false forever after.
    public mutating func firstSight(of key: String) -> Bool {
        seen.insert(key).inserted
    }

    /// After your own evening ends. Tables you walked past on Tuesday are not
    /// the ones in front of you on Wednesday, and the phone that was
    /// advertising has minted a new key by then anyway.
    public mutating func forget() { seen.removeAll() }
}
