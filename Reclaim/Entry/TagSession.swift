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
/// product. This is for the two moments you are already holding the phone:
/// making a card, and joining someone else's.
final class TagSession: NSObject {

    private var session: NFCNDEFReaderSession?
    /// A successful write invalidates the session, which calls back through
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
        guard NFCNDEFReaderSession.readingAvailable else {
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

    private func begin(prompt: String) {
        let session = NFCNDEFReaderSession(delegate: self, queue: nil,
                                           invalidateAfterFirstRead: url == nil)
        session.alertMessage = prompt
        session.begin()
        self.session = session
    }

    private func end(_ success: Bool, message: String) {
        guard !done else { return }
        done = true
        if success {
            session?.alertMessage = message
            session?.invalidate()
        } else {
            session?.invalidate(errorMessage: message)
        }
        session = nil
        let finished = finished
        Task { @MainActor in
            finished(success)
            TagSession.inFlight = nil
        }
    }
}

extension TagSession: NFCNDEFReaderSessionDelegate {

    /// The read path. A card carries one URI record; anything else on the tag
    /// is somebody else's and none of our business.
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        let urls = messages.flatMap(\.records).compactMap { $0.wellKnownTypeURIPayload() }
        guard let url = urls.first, let found else { return }
        done = true
        self.session = nil
        Task { @MainActor in
            found(url)
            TagSession.inFlight = nil
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let url, let tag = tags.first else { return }
        session.connect(to: tag) { [weak self] error in
            guard let self, error == nil else {
                self?.end(false, message: t("card.write.failed"))
                return
            }
            tag.queryNDEFStatus { status, _, _ in
                guard status == .readWrite,
                      let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: url)
                else {
                    self.end(false, message: t("card.write.failed"))
                    return
                }
                tag.writeNDEF(NFCNDEFMessage(records: [payload])) { error in
                    self.end(error == nil,
                             message: error == nil ? t("card.write.done") : t("card.write.failed"))
                }
            }
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
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
}
