import Foundation

/// The suggestion on Home: the place most of your recent evenings were at.
///
/// It used to be `places.first`, with a line underneath saying "most evenings
/// this week, that's where you were" — true for nobody in particular. This is
/// the knowledge test applied: the app knows your own sessions and which
/// gathering each was in, so it can say where you've usually been, and when
/// nowhere stands out it says nothing at all.
public enum UsualPlace {

    /// The place with the most distinct evenings among `sessions`; ties go to
    /// the one used most recently. Nil when none of them had a place.
    ///
    /// Distinct `local_date`s, not sessions: a second session on the same
    /// evening is still one evening there.
    public static func among(
        _ sessions: [Session],
        gatherings: [UUID: Gathering],
        places: [Place]
    ) -> Place? {
        var dates: [UUID: Set<String>] = [:]
        for s in sessions where s.qualifying {
            guard let place = gatherings[s.gatheringId]?.placeId else { continue }
            dates[place, default: []].insert(s.localDate)
        }
        return places
            .filter { $0.mergedInto == nil && dates[$0.id] != nil }
            .max { a, b in
                let x = dates[a.id] ?? [], y = dates[b.id] ?? []
                return x.count != y.count ? x.count < y.count
                                          : (x.max() ?? "") < (y.max() ?? "")
            }
    }
}
