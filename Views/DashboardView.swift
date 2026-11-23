import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @AppStorage("weeklyLimit") private var weeklyLimit: Double = 0
    @AppStorage("currencyCode") private var currencyCode = Money.defaultCode
    @State private var showingAdd = false

    var body: some View {
        let analyzer = SpendingAnalyzer(expenses: expenses, currencyCode: currencyCode)

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if expenses.isEmpty {
                        ContentUnavailableView {
                            Label("No expenses yet", systemImage: "creditcard.fill")
                        } description: {
                            Text("Log what you spend each day and SpendSense will spot patterns and suggest a weekly limit.")
                        } actions: {
                            Button("Add Expense") { showingAdd = true }
                                .buttonStyle(.borderedProminent)
                            Button("Load Sample Data") {
                                SampleData.load(into: context, currencyCode: currencyCode)
                            }
                        }
                        .padding(.top, 40)
                    } else {
                        WeeklyLimitCard(
                            spent: analyzer.thisWeekTotal,
                            limit: $weeklyLimit,
                            daysLeft: analyzer.daysLeftInWeek,
                            suggestion: analyzer.suggestion(),
                            currencyCode: currencyCode
                        )
                        DailyChartCard(days: analyzer.dailyTotals(days: 7),
                                       weeklyLimit: weeklyLimit)
                        CategoryDonutCard(totals: analyzer.categoryTotals(days: 30),
                                          currencyCode: currencyCode)
                        TopInsightsCard(insights: Array(analyzer.insights().prefix(3)))
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("SpendSense")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("Add expense")
                }
            }
            .sheet(isPresented: $showingAdd) { ExpenseFormView() }
        }
    }
}

// MARK: - Weekly limit

struct WeeklyLimitCard: View {
    let spent: Double
    @Binding var limit: Double
    let daysLeft: Int
    let suggestion: LimitSuggestion?
    let currencyCode: String

    private var progress: Double { limit > 0 ? spent / limit : 0 }

    private var tint: Color {
        if progress >= 1 { return .red }
        if progress >= 0.75 { return .orange }
        return .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("This week").font(.headline)

            if limit > 0 {
                HStack(spacing: 20) {
                    ZStack {
                        Circle().stroke(tint.opacity(0.18), lineWidth: 12)
                        Circle()
                            .trim(from: 0, to: min(progress, 1))
                            .stroke(tint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.6), value: progress)
                        VStack(spacing: 0) {
                            Text("\(Int((progress * 100).rounded()))%")
                                .font(.title2.bold())
                            Text("used")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 110, height: 110)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(Money.string(spent, code: currencyCode))
                            .font(.title.bold())
                        Text("of \(Money.string(limit, code: currencyCode)) weekly limit")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if spent >= limit {
                            Text("Over by \(Money.string(spent - limit, code: currencyCode))")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.red)
                        } else {
                            let left = limit - spent
                            Text("\(Money.string(left, code: currencyCode)) left · about \(Money.string(left / Double(daysLeft), code: currencyCode))/day for \(daysLeft) more day\(daysLeft == 1 ? "" : "s")")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text(Money.string(spent, code: currencyCode))
                    .font(.largeTitle.bold())
                Text("spent so far this week")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let suggestion {
                    Divider()
                    Text("We suggest a limit of \(Money.string(suggestion.amount, code: currencyCode)) per week based on your recent spending.")
                        .font(.subheadline)
                    Button("Use suggested limit") { limit = suggestion.amount }
                        .buttonStyle(.borderedProminent)
                } else {
                    Text("Log a few more days of expenses to get a suggested weekly limit.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .card()
    }
}

// MARK: - Last 7 days chart

struct DailyChartCard: View {
    let days: [DayTotal]
    let weeklyLimit: Double

    private var dailyPace: Double { weeklyLimit / 7 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 7 days").font(.headline)

            Chart {
                ForEach(days) { d in
                    BarMark(x: .value("Day", d.date, unit: .day),
                            y: .value("Spent", d.total))
                        .foregroundStyle(weeklyLimit > 0 && d.total > dailyPace ? Color.orange : Color.accentColor)
                        .cornerRadius(4)
                }
                if weeklyLimit > 0 {
                    RuleMark(y: .value("Daily pace", dailyPace))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .foregroundStyle(.secondary)
                        .annotation(position: .top, alignment: .leading) {
                            Text("Daily pace")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 170)
        }
        .card()
    }
}

// MARK: - Category breakdown

struct CategoryDonutCard: View {
    let totals: [CategoryTotal]
    let currencyCode: String

    private var grandTotal: Double { totals.reduce(0) { $0 + $1.total } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Where it goes · 30 days").font(.headline)

            if totals.isEmpty {
                Text("No spending in the last 30 days.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Chart(totals) { item in
                    SectorMark(angle: .value("Spent", item.total),
                               innerRadius: .ratio(0.62),
                               angularInset: 1.5)
                        .cornerRadius(4)
                        .foregroundStyle(item.category.color)
                }
                .chartLegend(.hidden)
                .frame(height: 190)
                .overlay {
                    VStack(spacing: 0) {
                        Text(Money.string(grandTotal, code: currencyCode))
                            .font(.title3.bold())
                        Text("total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 10) {
                    ForEach(totals) { item in
                        HStack(spacing: 10) {
                            CategoryBadge(category: item.category, size: 28)
                            Text(item.category.title).font(.subheadline)
                            Spacer()
                            Text(item.share, format: .percent.precision(.fractionLength(0)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(Money.string(item.total, code: currencyCode))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .card()
    }
}

// MARK: - Insight preview

struct TopInsightsCard: View {
    let insights: [Insight]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Spending patterns").font(.headline)
            if insights.isEmpty {
                Text("Keep logging — patterns show up after a few days of data.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(insights) { InsightRow(insight: $0) }
                Text("See everything in the Insights tab.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: Expense.self, inMemory: true)
}
