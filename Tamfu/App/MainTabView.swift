import SwiftUI

struct MainTabView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        ZStack(alignment: .bottom) {
            ZStack {
                tab(.bottle) { BottleHomeView() }
                tab(.explore) { ExploreView() }
                tab(.chats) { ChatListView() }
                tab(.profile) { ProfileView() }
            }

            if !model.isTabBarHidden {
                CustomTabBar(selection: $model.selectedTab, badges: [.chats: model.unreadCount])
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Spacing.xs)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(.keyboard)
        .overlay(alignment: .top) {
            if let bottle = model.arrivalBanner, model.presentedBottle == nil {
                BottleArrivalBanner(bottle: bottle) { model.open(bottle) }
                    .padding(.horizontal, Theme.Spacing.l)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(item: $model.presentedBottle) { bottle in
            IncomingBottleView(bottle: bottle)
                .presentationDetents([.large])
                .presentationCornerRadius(Theme.Radius.xl)
        }
        .animation(Theme.Motion.snappy, value: model.isTabBarHidden)
    }

    /// Keeps every tab alive (scroll position, navigation stack) like UITabBarController.
    @ViewBuilder
    private func tab<Content: View>(_ tab: AppTab, @ViewBuilder content: () -> Content) -> some View {
        let isSelected = model.selectedTab == tab
        content()
            .opacity(isSelected ? 1 : 0)
            .allowsHitTesting(isSelected)
            .accessibilityHidden(!isSelected)
    }
}

/// Reserves space for the floating tab bar at the bottom of scrollable screens.
struct TabBarSpacer: View {
    var body: some View { Color.clear.frame(height: 96) }
}
