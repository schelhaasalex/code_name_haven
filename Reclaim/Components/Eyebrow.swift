import SwiftUI
import ReclaimKit

/// Mark plus letterspaced caps — the header on nearly every screen.
struct Eyebrow: View {
    let text: String
    var mark: Color = Palette.clay
    var tint: Color = Palette.muted

    var body: some View {
        HStack(spacing: 10) {
            Brand(color: mark)
            Text(text).eyebrow(tint)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        Eyebrow(text: "Reclaim")
        Eyebrow(text: "The Kitchen Table", mark: Palette.ember, tint: Palette.dust)
            .padding(8).background(Palette.night)
    }
    .padding()
}
