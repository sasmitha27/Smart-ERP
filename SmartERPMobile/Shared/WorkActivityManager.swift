import ActivityKit
import Foundation

@MainActor
final class WorkActivityManager {
    static let shared = WorkActivityManager()
    private init() {}

    func start(nextVisit: String?) throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, Activity<WorkSessionAttributes>.activities.isEmpty else { return }
        let state = WorkSessionAttributes.ContentState(startedAt: .now, visitName: nextVisit)
        _ = try Activity.request(attributes: WorkSessionAttributes(title: "SmartERP work session"), content: ActivityContent(state: state, staleDate: nil), pushType: nil)
    }

    func end() async {
        for activity in Activity<WorkSessionAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
