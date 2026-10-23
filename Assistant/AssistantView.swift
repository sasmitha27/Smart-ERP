import SwiftUI

#if canImport(FoundationModels)
import FoundationModels
#endif

struct AssistantView: View {
    @Environment(DemoStore.self) private var store
    @State private var messages: [AssistantMessage] = [
        AssistantMessage(role: .assistant, title: "Welcome", body: "Ask me about your sales, receivables, inventory, orders, customers, or field activity.")
    ]
    @State private var question = ""
    @State private var isResponding = false

    private let suggestions = [
        "Give me a business summary",
        "Which products are low in stock?",
        "How much is unpaid?",
        "Who is my top customer?"
    ]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    AssistantPrivacyBanner(status: AssistantResponseComposer.status)

                    if messages.count == 1 {
                        suggestionGrid
                    }

                    ForEach(messages) { message in
                        AssistantBubble(message: message)
                            .id(message.id)
                    }

                    if isResponding {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Reviewing your business data…")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
            .background(Theme.background)
            .onChange(of: messages.count) {
                guard let lastID = messages.last?.id else { return }
                withAnimation { proxy.scrollTo(lastID, anchor: .bottom) }
            }
        }
        .navigationTitle("Smart Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { composer }
    }

    private var suggestionGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try asking")
                .font(.headline)

            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    submit(suggestion)
                } label: {
                    HStack {
                        Text(suggestion)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .padding(14)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.blue)
                .disabled(isResponding)
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask about your business", text: $question, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit { submit(question) }

            Button {
                submit(question)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
            }
            .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isResponding)
            .accessibilityLabel("Send question")
        }
        .padding()
        .background(.bar)
    }

    private func submit(_ rawQuestion: String) {
        let cleanQuestion = rawQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuestion.isEmpty, !isResponding else { return }

        question = ""
        messages.append(AssistantMessage(role: .user, title: nil, body: cleanQuestion))
        isResponding = true

        let snapshot = BusinessSnapshot(store: store)
        let verifiedAnswer = BusinessAssistant.answer(question: cleanQuestion, snapshot: snapshot)

        Task {
            let body = await AssistantResponseComposer.compose(question: cleanQuestion, answer: verifiedAnswer)
            messages.append(AssistantMessage(role: .assistant, title: verifiedAnswer.title, body: body))
            isResponding = false
        }
    }
}

private struct AssistantMessage: Identifiable {
    enum Role {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let title: String?
    let body: String
}

private struct AssistantBubble: View {
    let message: AssistantMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 48) }

            VStack(alignment: .leading, spacing: 6) {
                if let title = message.title {
                    Text(title)
                        .font(.headline)
                }
                Text(message.body)
                    .font(.body)
            }
            .padding(14)
            .foregroundStyle(message.role == .user ? Color.white : Color.primary)
            .background(message.role == .user ? Theme.blue : Theme.surface, in: RoundedRectangle(cornerRadius: 18))

            if message.role == .assistant { Spacer(minLength: 30) }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct AssistantPrivacyBanner: View {
    let status: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(Theme.green)
            VStack(alignment: .leading, spacing: 3) {
                Text(status)
                    .font(.subheadline.weight(.semibold))
                Text("Answers use the current local demo workspace. Verified totals are calculated by SmartERP and are never generated by AI.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Theme.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }
}

enum AssistantResponseComposer {
    static var status: String {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return "On-device AI available"
            case .unavailable:
                return "Verified insights mode"
            }
        }
#endif
        return "Verified insights mode"
    }

    static func compose(question: String, answer: BusinessAnswer) async -> String {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *), SystemLanguageModel.default.availability == .available {
            do {
                let session = LanguageModelSession(instructions: """
                    You are a concise business assistant inside SmartERP. Rewrite the supplied verified facts as a friendly answer of at most 90 words. Never change, recalculate, infer, or add numbers. Never claim that demo data is official accounting data. Do not use markdown tables.
                    """)
                let response = try await session.respond(to: """
                    User question: \(question)
                    Verified answer title: \(answer.title)
                    Verified facts: \(answer.verifiedFacts)
                    """)
                return response.content
            } catch {
                return answer.body
            }
        }
#endif
        return answer.body
    }
}

