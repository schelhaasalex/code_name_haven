import SwiftUI
import ReclaimKit

/// Screen 16b. What we can see, said plainly, from Settings' Privacy row.
///
/// In the app rather than on the site: every path there but the home page
/// opens the app (`links/`), so a policy page linked from here would open
/// this app again; and this needs no network. The full policy, once it
/// exists, belongs on the site's home page and in App Store Connect.
struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text(t("settings.privacy")).font(Type.title).foregroundStyle(Palette.ink)
                LabelledSection(label: t("settings.see.label"), spacing: 14) {
                    ForEach(["settings.see.body", "settings.see.others"], id: \.self) { key in
                        Text(t(key)).font(Type.body(15)).foregroundStyle(Palette.ink2).lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .background(Palette.bone.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { PrivacyView() }
}
