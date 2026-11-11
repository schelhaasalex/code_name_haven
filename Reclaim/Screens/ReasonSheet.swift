import SwiftUI
import ReclaimKit

/// Screen 8a. Under the receipt, once: what would you like the time for?
/// Then, for someone who answered, one note a day, offered and never assumed.
///
/// "Not now" closes it and changes nothing; the question lives on in
/// Settings and is never asked again. Pairing stays the only setup there is
/// (rule 5): this comes after a day that counted, never before one.
///
/// The offer's time is what the box has seen. Under the first day it is that
/// evening's own, so "around when your phone went in today" is true.
struct ReasonSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let first: Bool

    @State private var picked: Reason?
    @State private var words = ""
    @State private var offering = false
    @State private var height: CGFloat = 520
    @FocusState private var typing: Bool

    private var chosen: Reason? { Reason.chosen(picked, words: words) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if offering { offer } else { question }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 28)
        .padding(.top, 36)
        .padding(.bottom, 8)
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { height = $0 }
        .presentationDetents([.height(height)])
        .presentationBackground(Palette.bone)
        .presentationCornerRadius(32)
        .presentationDragIndicator(.visible)
        .animation(.easeInOut(duration: 0.3), value: offering)
    }

    private var question: some View {
        VStack(alignment: .leading, spacing: 0) {
            if first {
                Text(t("reason.ask.first")).eyebrow(Palette.clay).padding(.bottom, 12)
            }
            Text(t("reason.ask.title")).font(Type.subhead).foregroundStyle(Palette.ink)
            Text(t("reason.ask.body")).font(Type.body(15)).foregroundStyle(Palette.ink2).lineSpacing(3)
                .padding(.top, 10)
            ReasonPicker(picked: $picked, words: $words, typing: $typing)
                .padding(.top, 22)
            PrimaryButton(title: t("reason.ask.keep")) { keep() }
                .disabled(chosen == nil)
                .opacity(chosen == nil ? 0.35 : 1)
                .padding(.top, 28)
            quiet(t("reason.ask.later")) { dismiss() }
        }
    }

    /// The note, offered once a reason is kept. A sample of what it would
    /// say, so nobody agrees to something they haven't read.
    private var offer: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let reason = state.reason {
                Text(reason.label).eyebrow(Palette.clay).padding(.bottom, 12)
            }
            Text(t("nudge.offer.title", "time", state.nudgeTime ?? ""))
                .font(Type.subhead).foregroundStyle(Palette.ink)
            Text(t(first ? "nudge.offer.body.first" : "nudge.offer.body"))
                .font(Type.body(15)).foregroundStyle(Palette.ink2).lineSpacing(3)
                .padding(.top, 10)
            if let sample {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("nudge.offer.sample")).eyebrow(Palette.muted)
                    Text(sample).font(Type.body(15)).foregroundStyle(Palette.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .paperCard()
                .padding(.top, 20)
            }
            PrimaryButton(title: t("nudge.offer.yes")) {
                Task {
                    await state.nudge(true)
                    dismiss()
                }
            }
            .padding(.top, 28)
            quiet(t("nudge.offer.no")) { dismiss() }
        }
    }

    private var sample: String? {
        guard let reason = state.reason, let box = state.boxPlace else { return nil }
        return reason.nudges(place: state.name(of: box)).first
    }

    private func quiet(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(Type.body(15, weight: .medium)).foregroundStyle(Palette.muted)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    /// Kept. The note is offered only when there's a box to name and a time
    /// the box has taught; otherwise the page in Settings can offer it later.
    private func keep() {
        guard let chosen else { return }
        typing = false
        state.choose(chosen)
        if state.boxPlace != nil, state.nudgeTime != nil {
            offering = true
        } else {
            dismiss()
        }
    }
}

#Preview("The first day") {
    let state = AppState(repo: PreviewRepository(), boxPlaces: [PreviewRepository.kitchenTable])
    return Color.clear.sheet(isPresented: .constant(true)) { ReasonSheet(first: true) }
        .environment(state).task { await state.load() }
}

#Preview("Asked later") {
    let state = AppState(repo: PreviewRepository(), boxPlaces: [PreviewRepository.kitchenTable])
    return Color.clear.sheet(isPresented: .constant(true)) { ReasonSheet(first: false) }
        .environment(state).task { await state.load() }
}
