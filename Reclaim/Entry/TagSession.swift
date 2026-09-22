import Foundation
import CoreNFC
import ReclaimKit

/// The app's own NFC: writing a place's card onto a tag, and reading one back
/// when someone would rather scan than tap their way in.
///
/// The payload is an https universal link, never a custom scheme: iOS only
/// offers to open http(s) from a background tag read, and a background read is
/// the entire point. A tag carrying `reclaim://` would need the app already
/// open, which is the thing this replaces.
///
/// Neither is the main path. A tag by the door is read by the SYSTEM, with the
/// app closed and the screen locked, through Associated Domains — that is the
/// product, and it needs none of this. This is for the two moments you are
/// already holding the phone: making a card, and joining someone else's.
///
/// It reads and writes through `NFCTagReaderSession` — the TAG format — rather
/// than the shorter `NFCNDEFReaderSession`, because App Store Connect refuses
/// a build made with the iOS 26 SDK that asks for the NDEF format: "NDEF is
/// disallowed … TAG is missing in the entitlement" (error 90778). The tag
/// still holds an ordinary NDEF URI record; this connects to the tag first and
/// asks it for its NDEF, instead of being handed the message.
final class TagSession: NSObject {

    private var session: NFCTagReaderSession?
    /// A finished session invalidates, which calls back through
    /// didInvalidateWithError — so without this, every success would be
    /// reported a moment later as a failure.
    private var done = false
    /// Nil for a read: there is nothing to put on the tag, only something to
    /// take off it.
    private let url: URL?
    private let finished: @MainActor @Sendable (Bool) -> Void
    private let found: (@MainActor @Sendable (URL) -> Void)?

    /// Held for the life of the session, because the system holds only a weak
    /// reference to the delegate and a local would be gone before the tag is.
    nonisolated(unsafe) private static var inFlight: TagSession?

    /// False on the simulator, and on the few iPhones without a reader — where
    /// the choice is picking a place instead, not a button that does nothing.
    static var canRead: Bool { NFCTagReaderSession.readingAvailable }

    static func write(_ url: URL, then finished: @escaping @MainActor @Sendable (Bool) -> Void) {
        start(TagSession(url: url, finished: finished, found: nil),
              prompt: t("card.write.hold"), finished: finished)
    }

    /// Reading a card someone else made. The URL goes to `URLRouter`, which is
    /// the same path a background read takes — one resolver, one behaviour.
    static func read(then found: @escaping @MainActor @Sendable (URL) -> Void) {
        start(TagSession(url: nil, finished: { _ in }, found: found),
              prompt: t("places.scan.hold"), finished: { _ in })
    }

    private static func start(_ session: TagSession, prompt: String,
                              finished: @escaping @MainActor @Sendable (Bool) -> Void) {
        guard NFCTagReaderSession.readingAvailable else {
            Task { @MainActor in finished(false) }
            return
        }
        inFlight = session
        session.begin(prompt: prompt)
    }

    private init(url: URL?,
                 finished: @escaping @MainActor @Sendable (Bool) -> Void,
                 found: (@MainActor @Sendable (URL) -> Void)?) {
        self.url = url
        self.finished = finished
        self.found = found
    }

    /// The three polling standards a tag in a house might speak. A card sticker
    /// is almost always ISO 14443 (NTAG); the other two cost nothing to listen
    /// for and cover the rest.
    private func begin(prompt: String) {
        guard let session = NFCTagReaderSession(
            pollingOption: [.iso14443, .iso15693, .iso18092], delegate: self, queue: nil)
        else {
            failed(nil)
            return
        }
        session.alertMessage = prompt
        session.begin()
        self.session = session
    }

    /// `message` nil ends the session without a word: a read that found nothing
    /// is the person moving the phone away, not an error to announce.
    private func end(_ success: Bool, message: String?) {
        guard !done else { return }
        done = true
        switch (success, message) {
        case (true, let message?):
            session?.alertMessage = message
            session?.invalidate()
        case (false, let message?):
            session?.invalidate(errorMessage: message)
        default:
            session?.invalidate()
        }
        session = nil
        let finished = finished
        Task { @MainActor in
            finished(success)
            TagSession.inFlight = nil
        }
    }

    /// A write that didn't take says so; a read that didn't just stops.
    private func failed(_ session: NFCTagReaderSession?) {
        end(false, message: url == nil ? nil : t("card.write.failed"))
    }
}

extension TagSession: NFCTagReaderSessionDelegate {

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first, let ndef = Self.ndef(tag) else {
            failed(session)
            return
        }
        session.connect(to: tag) { [weak self] error in
            guard let self, error == nil else {
                self?.failed(session)
                return
            }
            ndef.queryNDEFStatus { status, _, error in
                guard error == nil, status != .notSupported else {
                    self.failed(session)
                    return
                }
                if let url = self.url {
                    self.write(url, to: ndef, status: status)
                } else {
                    self.read(from: ndef)
                }
            }
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        // Includes the person tapping Cancel, which is not a failure worth
        // reporting as one — the label just goes back to how it was.
        guard !done else { return }
        done = true
        self.session = nil
        let finished = finished
        Task { @MainActor in
            finished(false)
            TagSession.inFlight = nil
        }
    }

    /// Every tag the reader can return carries NDEF under a different name.
    private static func ndef(_ tag: NFCTag) -> NFCNDEFTag? {
        switch tag {
        case .miFare(let tag):   return tag
        case .iso7816(let tag):  return tag
        case .iso15693(let tag): return tag
        case .feliCa(let tag):   return tag
        @unknown default:        return nil
        }
    }

    /// A card carries one URI record; anything else on the tag is somebody
    /// else's and none of our business.
    private func read(from tag: NFCNDEFTag) {
        tag.readNDEF { [weak self] message, _ in
            guard let self else { return }
            guard let url = message?.records.compactMap({ $0.wellKnownTypeURIPayload() }).first,
                  let found
            else {
                self.end(false, message: nil)
                return
            }
            done = true
            session?.invalidate()
            session = nil
            Task { @MainActor in
                found(url)
                TagSession.inFlight = nil
            }
        }
    }

    private func write(_ url: URL, to tag: NFCNDEFTag, status: NFCNDEFStatus) {
        guard status == .readWrite,
              let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: url)
        else {
            end(false, message: t("card.write.failed"))
            return
        }
        tag.writeNDEF(NFCNDEFMessage(records: [payload])) { [weak self] error in
            self?.end(error == nil,
                      message: error == nil ? t("card.write.done") : t("card.write.failed"))
        }
    }
}
