import Foundation
import Network

/// The network, as something to wait for. Only the first launch with no
/// network asks (`UnreachableView`): everything after it keeps what it knew
/// and reads again on the next return to the front.
enum NetworkWatch {

    /// Once each time there's a usable path — when watching starts with one,
    /// and whenever one comes back. A path being usable says nothing about
    /// the server, so whoever listens still tries and can still fail.
    static func reachable() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                if path.status == .satisfied { continuation.yield() }
            }
            continuation.onTermination = { _ in monitor.cancel() }
            monitor.start(queue: .global(qos: .utility))
        }
    }
}
