import Foundation
import ReclaimKit

/// The boxes this phone belongs to — the kitchen's and the bedroom's, say:
/// meeting one, what each is called, and letting one go. Each is its own
/// place, with its own name and its own total; an evening is at one of them.
/// The radio that listens to them is `AppState+Box`.
@MainActor
extension AppState {

    /// The names a box goes by until someone names it, in the order a
    /// household meets its boxes.
    static var defaultNames: [String] { [t("box.default.1"), t("box.default.2"), t("box.default.3")] }

    /// A fresh code for a second phone to scan off this one's screen, as it
    /// would the card: the same link, an hour long (migration 0025). It names
    /// the box when this launch read a card that did; without that, the other
    /// phone pairs with the closest box, and it is standing beside it. Nil if
    /// the server couldn't be asked.
    public func boxCode(for place: UUID) async -> URL? {
        guard let secret = try? await repo.boxCode(place: place) else { return nil }
        return Dock.url(secret: secret, box: cardBoxes[place])
    }

    /// A box's name: its own, or the one it goes by.
    public func name(of id: UUID) -> String {
        if let name = place(id)?.name, !name.isEmpty { return name }
        let i = boxPlaces.firstIndex(of: id) ?? 0
        return Self.defaultNames.indices.contains(i) ? Self.defaultNames[i] : t("box.unnamed")
    }

    /// The box an evening was at, by name — for one that isn't running, so
    /// isn't `gathering`. Nil if the gathering can't be read, or was at no box.
    public func placeName(ofGathering id: UUID) async -> String? {
        guard let place = (try? await repo.gathering(id))?.placeId,
              self.place(place) != nil || boxPlaces.contains(place) else { return nil }
        return name(of: place)
    }

    /// Its card or a tag was read: on this phone's list, and the box Home
    /// leads with.
    func meet(_ id: UUID) {
        if !boxPlaces.contains(id) { boxPlaces.append(id) }
        lastBox = id
    }

    /// The first phone to read a box gives it the name it goes by, written
    /// down so every phone in the house calls it the same thing. The first
    /// default none of this phone's other boxes already has.
    func nameIfUnnamed(_ id: UUID) async {
        guard let box = place(id), box.name?.isEmpty ?? true, canRename(id) else { return }
        let taken = Set(boxPlaces.filter { $0 != id }.map(name(of:)))
        guard let name = Self.defaultNames.first(where: { !taken.contains($0) }) else { return }
        try? await repo.rename(place: id, to: name)
        places = (try? await repo.myPlaces()) ?? places
    }

    /// Only whoever's phone first read the box can name it (`places_update_owner`).
    public func canRename(_ id: UUID) -> Bool {
        guard let maker = place(id)?.createdBy else { return false }
        return maker == profile?.id
    }

    @discardableResult
    public func rename(_ id: UUID, to name: String) async -> Bool {
        do {
            try await repo.rename(place: id, to: name)
            places = (try? await repo.myPlaces()) ?? places
            return true
        } catch {
            banner = t("error.retry")
            return false
        }
    }

    /// Paired with its radio, not only its place.
    public func hasRadio(_ id: UUID) -> Bool {
        BoxPairing.all.first { $0.place == id }?.peripheral != nil
    }

    /// What its radio is doing, for Settings. Nil before it has been paired
    /// with one, or before Bluetooth has said anything on this launch.
    public func radio(of id: UUID) -> BoxLink.Radio? {
        _ = radioTick
        return boxLink.radio(of: BoxPairing.all.first { $0.place == id }?.peripheral)
    }

    /// This phone stops being the box's. The box, and everything it kept,
    /// stays; reading its card or a tag again brings this phone back.
    public func forget(_ id: UUID) {
        if let radio = BoxPairing.all.first(where: { $0.place == id })?.peripheral {
            boxLink.letGo(of: radio)
        }
        BoxPairing.forget(id)
        boxPlaces.removeAll { $0 == id }
        boxSummaries[id] = nil
        if lastBox == id { lastBox = nil }
    }
}
