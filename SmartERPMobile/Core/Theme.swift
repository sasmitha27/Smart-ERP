import SwiftUI

enum Theme {
    static let blue = Color(red: 37/255, green: 99/255, blue: 235/255)
    static let teal = Color(red: 20/255, green: 184/255, blue: 166/255)
    static let green = Color(red: 22/255, green: 163/255, blue: 74/255)
    static let amber = Color(red: 245/255, green: 158/255, blue: 11/255)
    static let red = Color(red: 220/255, green: 38/255, blue: 38/255)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
}

struct Surface<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct SectionTitle: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.title3.weight(.bold))
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EmptyPanel: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.largeTitle).foregroundStyle(Theme.blue)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22))
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let symbol: String
    let color: Color

    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: symbol)
                    .font(.headline)
                    .foregroundStyle(color)
                    .frame(width: 34, height: 34)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                Text(value).font(.title2.weight(.bold)).monospacedDigit()
                    .minimumScaleFactor(0.7).lineLimit(1)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
