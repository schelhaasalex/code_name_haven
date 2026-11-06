import Foundation

/// Screen 20 is the only optional setup in the product. Declining it is final.
enum OneTapOffer {
    private static let key = "reclaim.onetap.offered"
    static var hasBeenOffered: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
