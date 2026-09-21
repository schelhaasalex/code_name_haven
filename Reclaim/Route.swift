import Foundation
import ReclaimKit

/// Everywhere you can go. Three destinations off Home, and two that hang off a
/// place — which is the whole map. There is no tab bar and nothing else to
/// browse, so this enum is allowed to be the complete answer.
enum Route: Hashable {
    case places
    case rhythm
    case settings
    case place(Place)
    /// Screen 15, keyed by place rather than carrying one, so a card opened
    /// from a rename still draws the renamed place.
    case card(UUID)
}
