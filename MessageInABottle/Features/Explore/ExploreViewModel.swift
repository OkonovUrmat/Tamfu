import SwiftUI

enum SwipeDirection {
    case left, right
}

@MainActor
@Observable
final class ExploreViewModel {
    var candidates: [UserProfile] = []
    var filters = DiscoveryFilters()
    var isLoading = false
    var hasLoaded = false
    var match: UserProfile?
    /// Set by the action buttons; the top card animates itself out.
    var programmaticSwipe: SwipeDirection?
    var lastSwiped: (UserProfile, SwipeDirection)?

    func load(using model: AppModel) async {
        isLoading = true
        let results = await model.services.discovery.candidates(
            for: model.currentUser,
            filters: filters,
            preferences: model.settings.discovery)
        withAnimation(Theme.Motion.snappy) {
            candidates = results.filter { !model.isBlocked($0.id) }
            isLoading = false
            hasLoaded = true
        }
    }

    var top: UserProfile? { candidates.first }

    func swipe(_ profile: UserProfile, _ direction: SwipeDirection, using model: AppModel) {
        withAnimation(Theme.Motion.snappy) {
            candidates.removeAll { $0.id == profile.id }
        }
        programmaticSwipe = nil
        lastSwiped = (profile, direction)
        Task {
            switch direction {
            case .right:
                let mutual = await model.services.discovery.like(profile, by: model.currentUser)
                if mutual {
                    withAnimation(Theme.Motion.bouncy) { match = profile }
                }
            case .left:
                await model.services.discovery.pass(profile, by: model.currentUser)
            }
        }
    }

    func undo() {
        guard let last = lastSwiped else { return }
        withAnimation(Theme.Motion.snappy) { candidates.insert(last.0, at: 0) }
        lastSwiped = nil
    }

    func trigger(_ direction: SwipeDirection) {
        guard top != nil, programmaticSwipe == nil else { return }
        programmaticSwipe = direction
    }
}
