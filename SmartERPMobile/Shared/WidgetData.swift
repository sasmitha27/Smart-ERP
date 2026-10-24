import Foundation
import ActivityKit

struct ERPWidgetSnapshot: Codable {
    var pendingOrders: Int
    var lowStock: Int
    var nextVisit: String?
    var nextVisitAt: Date?
    var updatedAt: Date

    static let empty = ERPWidgetSnapshot(pendingOrders: 0, lowStock: 0, nextVisit: nil, nextVisitAt: nil, updatedAt: .now)
}

enum WidgetData {
    static let group = "group.com.example.SmartERPMobile"
    static let key = "widgetSnapshot"

    static func read() -> ERPWidgetSnapshot {
        guard let data = UserDefaults(suiteName: group)?.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(ERPWidgetSnapshot.self, from: data) else { return .empty }
        return snapshot
    }

    static func write(_ snapshot: ERPWidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults(suiteName: group)?.set(data, forKey: key)
    }
}

struct WorkSessionAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
        var visitName: String?
    }
    var title: String
}
