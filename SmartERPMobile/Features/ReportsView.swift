import SwiftUI
import Charts

struct ReportsView: View {
    @Environment(DemoStore.self) private var store

    private struct DailySales: Identifiable {
        let date: Date
        let amount: Double
        var id: Date { date }
    }

    private var dailySales: [DailySales] {
        let calendar = Calendar.current
        return (0..<7).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: .now)) else { return nil }
            let total = store.invoices.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }.reduce(Decimal.zero) { $0 + $1.total }
            return DailySales(date: date, amount: NSDecimalNumber(decimal: total).doubleValue)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionTitle("Sales performance", subtitle: "Last 7 days · LKR · local demo invoices")
                Surface {
                    Chart(dailySales) { day in
                        BarMark(x: .value("Day", day.date, unit: .day), y: .value("Revenue", day.amount))
                            .foregroundStyle(Theme.blue.gradient)
                            .cornerRadius(5)
                    }
                    .frame(height: 210)
                    .chartYAxis { AxisMarks(position: .leading) }
                    .accessibilityLabel("Daily demo invoice totals for the last seven days")
                }
                HStack(spacing: 12) {
                    MetricCard(title: "Invoice value", value: Money.format(store.invoices.reduce(0) { $0 + $1.total }), symbol: "doc.text", color: Theme.blue)
                    MetricCard(title: "Demo payments", value: Money.format(store.invoices.reduce(0) { $0 + $1.paid }), symbol: "creditcard", color: Theme.green)
                }
                SectionTitle("Inventory", subtitle: "Current local demo catalog")
                Surface {
                    VStack(alignment: .leading, spacing: 14) {
                        LabeledContent("Products", value: "\(store.products.count)")
                        LabeledContent("Low stock", value: "\(store.products.filter { $0.stock <= $0.reorderLevel }.count)")
                        LabeledContent("Demo valuation", value: Money.format(store.products.reduce(0) { $0 + $1.cost * Decimal($1.stock) }))
                        Text("Valuation uses local sample quantities and costs. It is not an accounting report.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                SectionTitle("Field activity")
                Surface {
                    VStack(alignment: .leading, spacing: 14) {
                        LabeledContent("Planned visits", value: "\(store.visits.count)")
                        LabeledContent("Confirmed in demo", value: "\(store.visits.filter { $0.completedAt != nil }.count)")
                    }
                }
                Text("Updated \((store.lastSaved ?? .now).formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding()
        }
        .background(Theme.background)
        .navigationTitle("Reports")
    }
}
