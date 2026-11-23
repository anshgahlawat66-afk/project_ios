import SwiftUI
import SwiftData

struct InsightsView: View {
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @AppStorage("weeklyLimit") private var weeklyLimit: Double = 0
    @AppStorage("currencyCode") private var currencyCode = Money.defaultCode

    var body: some View {
        let analyzer = SpendingAnalyzer(expenses: expenses, currencyCode: currencyCode)
        let suggestion = analyzer.suggestion()
        let insights = analyzer.insights()

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let suggestion {
                        SuggestionCard(suggestion: suggestion,
                                       weeklyLimit: $weeklyLimit,
                                       currencyCode: currencyCode)
                        CategoryLimitsCard(limits: suggestion.categoryLimits,
                                           currencyCode: currencyCode)
                    } else {
                        ContentUnavailableView(
                            "Not enough data yet",
                            systemImage: "chart.bar.doc.horizontal",
                            description: Text("Log expenses for at least 3 days (5+ entries) and SpendSense will suggest a weekly limit and detect spending patterns.")
                        )
                        .padding(.top, 40)
                    }

                    if !insights.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Patterns detected").font(.headline)
                            ForEach(insights) { InsightRow(insight: $0) }
                        }
                        .card()
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Insights")
        }
    }
}

// MARK: - Suggested limit

struct SuggestionCard: View {
    let suggestion: LimitSuggestion
    @Binding var weeklyLimit: Double
    let currencyCode: String

    private var isActive: Bool { abs(weeklyLimit - suggestion.amount) < 0.5 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Suggested weekly limit", systemImage: "target")
                .font(.headline)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Money.string(suggestion.amount, code: currencyCode))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text("/ week")
                    .foregroundStyle(.secondary)
            }

            Text("You're on pace to spend about \(Money.string(suggestion.currentPace, code: currencyCode)) a week.\(suggestion.weeklySavings > 0 ? " Sticking to this limit would save roughly \(Money.string(suggestion.weeklySavings, code: currencyCode)) each week." : "")")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if isActive {
                Label("This is your current limit", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Button {
                    weeklyLimit = suggestion.amount
                } label: {
                    Text(weeklyLimit > 0 ? "Replace my current limit" : "Set as my weekly limit")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            if suggestion.spanDays < 14 {
                Text("Based on only \(suggestion.spanDays) days of data — it will get more accurate as you keep logging.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Based on your last \(suggestion.spanDays) days. Discretionary categories are trimmed 10–20%; bills and health are left as-is.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }
}

struct CategoryLimitsCard: View {
    let limits: [CategoryLimit]
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Suggested limits by category").font(.headline)

            ForEach(limits) { item in
                HStack(spacing: 12) {
                    CategoryBadge(category: item.category, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.category.title).font(.subheadline.weight(.medium))
                        Text("Now ~\(Money.string(item.weeklyAverage, code: currencyCode))/wk")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Money.string(item.suggested, code: currencyCode))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .frame(minWidth: 70, alignment: .trailing)
                }
            }
        }
        .card()
    }
}

#Preview {
    InsightsView()
        .modelContainer(for: Expense.self, inMemory: true)
}
