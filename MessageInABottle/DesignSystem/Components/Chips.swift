import SwiftUI

/// Wrapping layout for chips and tags.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: proposal.width ?? widest, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += lineHeight + lineSpacing
                x = bounds.minX
                lineHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

struct ChipView: View {
    let text: String
    var icon: String? = nil
    var isSelected = false
    var style: Style = .soft

    enum Style { case soft, outline, onDark }

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            }
            Text(text)
                .font(.ui(13.5, weight: .medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .foregroundStyle(foreground)
        .background(Capsule().fill(background))
        .overlay(Capsule().strokeBorder(border, lineWidth: 1))
    }

    private var foreground: Color {
        if isSelected { return .white }
        switch style {
        case .soft: return Theme.Palette.textPrimary
        case .outline: return Theme.Palette.textSecondary
        case .onDark: return .white
        }
    }

    private var background: Color {
        if isSelected { return Theme.Palette.accent }
        switch style {
        case .soft: return Theme.Palette.surfaceMuted
        case .outline: return .clear
        case .onDark: return .white.opacity(0.16)
        }
    }

    private var border: Color {
        if isSelected { return .clear }
        switch style {
        case .soft: return .clear
        case .outline: return Theme.Palette.hairline
        case .onDark: return .white.opacity(0.25)
        }
    }
}

/// Multi-select chip grid.
struct ChipPicker: View {
    let options: [String]
    @Binding var selection: Set<String>
    var limit: Int? = nil

    var body: some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(options, id: \.self) { option in
                let selected = selection.contains(option)
                Button {
                    withAnimation(Theme.Motion.snappy) {
                        if selected {
                            selection.remove(option)
                        } else if limit.map({ selection.count < $0 }) ?? true {
                            selection.insert(option)
                        }
                    }
                } label: {
                    ChipView(text: option, icon: selected ? "checkmark" : nil, isSelected: selected, style: .outline)
                }
                .buttonStyle(.plain)
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Editable list of tags with an inline "add" field.
struct TagEditor: View {
    @Binding var tags: [String]
    var placeholder = "Add…"
    var suggestions: [String] = []
    @State private var newTag = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            FlowLayout {
                ForEach(tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text(tag).font(.ui(13.5, weight: .medium))
                        Button {
                            withAnimation(Theme.Motion.snappy) { tags.removeAll { $0 == tag } }
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(tag)")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .background(Capsule().fill(Theme.Palette.accentSoft))
                }
            }

            HStack {
                TextField(placeholder, text: $newTag)
                    .font(.ui(15))
                    .submitLabel(.done)
                    .onSubmit(add)
                Button("Add", action: add)
                    .buttonStyle(.borderless)
                    .font(.ui(14, weight: .semibold))
                    .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.small).fill(Theme.Palette.surfaceMuted))

            let remaining = suggestions.filter { !tags.contains($0) }.prefix(8)
            if !remaining.isEmpty {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(Array(remaining), id: \.self) { s in
                        Button {
                            withAnimation(Theme.Motion.snappy) { tags.append(s) }
                        } label: {
                            ChipView(text: s, icon: "plus", style: .outline)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func add() {
        let value = newTag.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty, !tags.contains(value) else { return }
        withAnimation(Theme.Motion.snappy) { tags.append(value) }
        newTag = ""
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var action: (title: String, handler: () -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.display(20))
                    .foregroundStyle(Theme.Palette.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.ui(13))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            Spacer()
            if let action {
                Button(action.title, action: action.handler)
                    .font(.ui(14, weight: .semibold))
                    .foregroundStyle(Theme.Palette.accent)
            }
        }
    }
}

struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.Palette.accent)
                .frame(width: 22)
            Text(text)
                .font(.ui(15))
                .foregroundStyle(Theme.Palette.textPrimary)
            Spacer(minLength: 0)
        }
    }
}
