import SwiftUI
import WidgetKit
import ActivityKit

struct ERPEntry: TimelineEntry {
    var date: Date
    var snapshot: ERPWidgetSnapshot
}

struct ERPProvider: TimelineProvider {
    func placeholder(in context: Context) -> ERPEntry { ERPEntry(date: .now, snapshot: .empty) }
    func getSnapshot(in context: Context, completion: @escaping (ERPEntry) -> Void) {
        completion(ERPEntry(date: .now, snapshot: WidgetData.read()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ERPEntry>) -> Void) {
        completion(Timeline(entries: [ERPEntry(date: .now, snapshot: WidgetData.read())], policy: .after(.now.addingTimeInterval(900))))
    }
}

struct ERPOverviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ERPOverview", provider: ERPProvider()) { entry in
            VStack(alignment: .leading, spacing: 8) {
                Label("SmartERP", systemImage: "chart.bar.fill").font(.headline)
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(entry.snapshot.pendingOrders)").font(.title.bold())
                        Text("Orders").font(.caption)
                    }
                    Spacer()
                    VStack(alignment: .leading) {
                        Text("\(entry.snapshot.lowStock)").font(.title.bold())
                        Text("Low stock").font(.caption)
                    }
                }
                if let visit = entry.snapshot.nextVisit {
                    Text("Next: \(visit)").font(.caption).lineLimit(1)
                }
            }
            .padding()
            .containerBackground(.fill.tertiary, for: .widget)

        }
        .configurationDisplayName("Business overview")
        .description("Orders, stock alerts, and the next visit from this device.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ERPVisitWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ERPNextVisit", provider: ERPProvider()) { entry in
            VStack(alignment: .leading, spacing: 8) {
                Label("Next visit", systemImage: "mappin.and.ellipse").font(.headline)
                if let name = entry.snapshot.nextVisit, let date = entry.snapshot.nextVisitAt {
                    Text(name).font(.title3.bold()).lineLimit(2)
                    Text(date, style: .relative).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("No upcoming visits").font(.subheadline)
                }
            }
            .padding()
            .containerBackground(.fill.tertiary, for: .widget)

        }
        .configurationDisplayName("Next visit")
        .description("Your next scheduled visit.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ERPWorkActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkSessionAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: "location.circle.fill").font(.title).foregroundStyle(.green)
                VStack(alignment: .leading) {
                    Text("Work session active").font(.headline)
                    if let visit = context.state.visitName { Text("Next: \(visit)").lineLimit(1) }
                    Text(context.state.startedAt, style: .timer).monospacedDigit()
                }
                Spacer()
            }
            .padding()
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Image(systemName: "location.fill") }
                DynamicIslandExpandedRegion(.center) { Text("Work session") }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.visitName ?? "Location is active").lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "location.fill")
            } compactTrailing: {
                Text(context.state.startedAt, style: .timer).frame(width: 50)
            } minimal: {
                Image(systemName: "location.fill")
            }
        }
    }
}

@main
struct SmartERPWidgetBundle: WidgetBundle {
    var body: some Widget {
        ERPOverviewWidget()
        ERPVisitWidget()
        ERPWorkActivity()
    }
}
