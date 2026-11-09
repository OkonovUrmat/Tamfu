import SwiftUI

struct FiltersView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Binding var filters: DiscoveryFilters
    var onApply: () -> Void

    @State private var draft = DiscoveryFilters()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    section("Age", trailing: "\(draft.minAge) – \(draft.maxAge)\(draft.maxAge == 60 ? "+" : "")") {
                        RangeSlider(lower: $draft.minAge, upper: $draft.maxAge, bounds: 18...60)
                    }

                    section("Location") {
                        VStack(spacing: Theme.Spacing.m) {
                            Menu {
                                Button("Anywhere") { draft.country = nil }
                                Divider()
                                ForEach(Country.all) { c in
                                    Button("\(c.flag) \(c.name)") { draft.country = c }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "globe.europe.africa")
                                    Text(draft.country.map { "\($0.flag) \($0.name)" } ?? "Anywhere in the world")
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 12))
                                }
                                .font(.ui(15))
                                .foregroundStyle(Theme.Palette.textPrimary)
                                .padding(14)
                                .background(RoundedRectangle(cornerRadius: Theme.Radius.small).fill(Theme.Palette.surfaceMuted))
                            }
                            TextField("City", text: $draft.city)
                                .font(.ui(15))
                                .padding(14)
                                .background(RoundedRectangle(cornerRadius: Theme.Radius.small).fill(Theme.Palette.surfaceMuted))
                        }
                    }

                    section("Languages") {
                        ChipPicker(options: MockData.allLanguages, selection: $draft.languages)
                    }
                    section("Interests") {
                        ChipPicker(options: MockData.allInterests, selection: $draft.interests)
                    }
                    section("Hobbies") {
                        ChipPicker(options: MockData.allHobbies, selection: $draft.hobbies)
                    }

                    section("Status") {
                        Toggle("Online now", isOn: $draft.onlineOnly)
                            .font(.ui(15))
                            .tint(Theme.Palette.accent)
                    }

                    section("Your visibility") {
                        Toggle(isOn: Binding(
                            get: { model.settings.privacy.appearInDiscovery },
                            set: { value in model.updateSettings { $0.privacy.appearInDiscovery = value } }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Show me in Explore").font(.ui(15))
                                Text("When off, you can still browse but others won't see your card.")
                                    .font(.ui(12))
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                        }
                        .tint(Theme.Palette.accent)
                    }
                }
                .padding(Theme.Spacing.xl)
            }
            .screenBackground()
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Reset") {
                        withAnimation { draft = DiscoveryFilters() }
                    }
                    .disabled(draft.activeCount == 0)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Show people") {
                    filters = draft
                    onApply()
                    dismiss()
                }
                .buttonStyle(.primary)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.m)
                .background(.ultraThinMaterial)
            }
        }
        .onAppear { draft = filters }
    }

    private func section<Content: View>(_ title: String, trailing: String? = nil,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                Text(title).font(.ui(17, weight: .semibold))
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.ui(15, weight: .medium))
                        .foregroundStyle(Theme.Palette.accent)
                        .contentTransition(.numericText())
                }
            }
            content()
        }
        .cardStyle()
    }
}

/// Two-thumb slider for integer ranges.
struct RangeSlider: View {
    @Binding var lower: Int
    @Binding var upper: Int
    let bounds: ClosedRange<Int>
    private let thumb: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width - thumb
            let span = CGFloat(bounds.upperBound - bounds.lowerBound)
            let lowerX = CGFloat(lower - bounds.lowerBound) / span * width
            let upperX = CGFloat(upper - bounds.lowerBound) / span * width

            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Palette.surfaceMuted).frame(height: 6)
                    .padding(.horizontal, thumb / 2)
                Capsule().fill(Theme.Gradients.accent)
                    .frame(width: max(0, upperX - lowerX), height: 6)
                    .offset(x: lowerX + thumb / 2)
                thumbView
                    .offset(x: lowerX)
                    .gesture(DragGesture(coordinateSpace: .named("range")).onChanged { v in
                        let value = valueFor(x: v.location.x - thumb / 2, width: width)
                        lower = min(max(bounds.lowerBound, value), upper - 1)
                    })
                    .accessibilityLabel("Minimum age \(lower)")
                thumbView
                    .offset(x: upperX)
                    .gesture(DragGesture(coordinateSpace: .named("range")).onChanged { v in
                        let value = valueFor(x: v.location.x - thumb / 2, width: width)
                        upper = max(min(bounds.upperBound, value), lower + 1)
                    })
                    .accessibilityLabel("Maximum age \(upper)")
            }
            .coordinateSpace(.named("range"))
        }
        .frame(height: thumb)
        .sensoryFeedback(.selection, trigger: lower)
        .sensoryFeedback(.selection, trigger: upper)
    }

    private var thumbView: some View {
        Circle()
            .fill(.white)
            .frame(width: thumb, height: thumb)
            .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
            .overlay(Circle().strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
    }

    private func valueFor(x: CGFloat, width: CGFloat) -> Int {
        let ratio = min(max(0, x / width), 1)
        return bounds.lowerBound + Int((ratio * CGFloat(bounds.upperBound - bounds.lowerBound)).rounded())
    }
}
