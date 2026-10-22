import Foundation

/// What the box's light controller understands: WLED's JSON API, one segment
/// per slot.
///
/// Plain values, so what goes over the wire can be tested without a box.
public enum WLED {

    /// What the controller advertises itself as on the home network. Also in
    /// `NSBonjourServices` (project.yml) — iOS refuses to browse for a service
    /// the app didn't declare, and says nothing.
    public static let service = "_wled._tcp"

    /// One slot's light, and only that one. Switching the whole controller off
    /// would put out the lights of the phones still in the box.
    ///
    /// Turning a slot on also turns the controller on: a segment that is on
    /// under a controller that is off is still dark.
    public static func state(segment: Int, on: Bool) -> Data {
        var state: [String: Any] = ["seg": [["id": segment, "on": on]]]
        if on { state["on"] = true }
        return (try? JSONSerialization.data(withJSONObject: state, options: [.sortedKeys])) ?? Data()
    }

    /// The whole HTTP request, as bytes. Sent over a plain TCP connection to
    /// the service iOS found, rather than through URLSession, so there is no
    /// host name to resolve and no App Transport Security exception to hold.
    public static func request(body: Data) -> Data {
        let head = [
            "POST /json/state HTTP/1.1",
            "Host: wled.local",
            "Content-Type: application/json",
            "Content-Length: \(body.count)",
            "Connection: close",
            "", ""
        ].joined(separator: "\r\n")
        return Data(head.utf8) + body
    }
}
