import SwiftUI

struct CustomTabBar: View {
    @Binding var selection: AppTab
    var badges: [AppTab: Int] = [:]
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                let isSelected = selection == tab
                Button {
                    if selection != tab {
                        withAnimation(Theme.Motion.snappy) { selection = tab }
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                            .font(.system(size: 19, weight: isSelected ? .semibold : .regular))
                            .frame(height: 22)
                            .overlay(alignment: .topTrailing) {
                                if let count = badges[tab], count > 0 {
                                    Text(count > 99 ? "99+" : "\(count)")
                                        .font(.roundedUI(10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 5)
                                        .frame(minWidth: 17, minHeight: 17)
                                        .background(Capsule().fill(Theme.Palette.coral))
                                        .offset(x: 12, y: -6)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                        Text(tab.title)
                            .font(.ui(10.5, weight: .medium))
                    }
                    .foregroundStyle(isSelected ? Theme.Palette.accent : Theme.Palette.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(Theme.Palette.accentSoft)
                                .matchedGeometryEffect(id: "pill", in: pill)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(6)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().fill(Theme.Palette.surface.opacity(0.55)))
                .overlay(Capsule().strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
                .shadow(color: Theme.Palette.deepOcean.opacity(0.14), radius: 22, x: 0, y: 10)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

extension AppTab {
    var selectedIcon: String {
        switch self {
        case .bottle: return "waterbottle.fill"
        case .explore: return "safari.fill"
        case .chats: return "bubble.left.and.bubble.right.fill"
        case .profile: return "person.crop.circle.fill"
        }
    }
}

struct ToastView: View {
    let toast: Toast

    private var tint: Color {
        switch toast.style {
        case .info: return Theme.Palette.accent
        case .success: return Theme.Palette.success
        case .warning: return Theme.Palette.warning
        case .error: return Theme.Palette.danger
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: toast.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
            Text(toast.message)
                .font(.ui(14, weight: .medium))
                .foregroundStyle(Theme.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 10)
    }
}
