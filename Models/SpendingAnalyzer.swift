import Foundation

// MARK: - Result types

struct DayTotal: Identifiable {
    let date: Date
    let total: Double
    var id: Date { date }
}

struct CategoryTotal: Identifiable {
    let category: SpendCategory
    let total: Double
    let share: Double
    var id: SpendCategory { category }
}

struct Insight: Identifiable {
    enum Severity { case warning, info, positive }

    let id = UUID()
    let severity: Severity
    let icon: String
    let title: String
    let detail: String
    let category: SpendCategory?
}

struct CategoryLimit: Identifiable {
    let category: SpendCategory
    let weeklyAverage: Double
    let suggested: Double
    var id: SpendCategory { category }
}

struct LimitSuggestion {
    /// Suggested total weekly limit.
    let amount: Double
    /// What the user is currently spending per week, extrapolated from recent days.
    let currentPace: Double
    /// Number of days of history the suggestion is based on.
    let spanDays: Int
    let categoryLimits: [CategoryLimit]

    var weeklySavings: Double { max(0, currentPace - amount) }
}

// MARK: - Analyzer

/// Pure, side-effect-free analysis of a list of expenses.
struct SpendingAnalyzer {
    let expenses: [Expense]
    let currencyCode: String
    private let calendar: Calendar
    private let today: Date

    init(expenses: [Expense],
         currencyCode: String = Money.defaultCode,
         calendar: Calendar = .current,
         now: Date = Date.now) {
        self.expenses = expenses
        self.currencyCode = currencyCode
        self.calendar = calendar
        self.today = calendar.startOfDay(for: now)
    }

    // MARK: Date helpers

    /// Start of the day `offset` days from today (negative = past).
    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: today) ?? today
    }

    private var tomorrow: Date { day(1) }

    private func money(_ value: Double) -> String {
        Money.string(value, code: currencyCode)
    }

    private func percent(_ value: Double) -> Int {
        Int((value * 100).rounded())
    }

    // MARK: Totals

    func total(from start: Date, to end: Date, category: SpendCategory? = nil) -> Double {
        expenses.reduce(0) { acc, e in
            guard e.date >= start, e.date < end else { return acc }
            if let category, e.category != category { return acc }
            return acc + e.amount
        }
    }

    /// Calendar week containing today.
    var weekInterval: DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: today)
            ?? DateInterval(start: day(-6), end: tomorrow)
    }

    var thisWeekTotal: Double {
        total(from: weekInterval.start, to: weekInterval.end)
    }

    /// Days left in the current week, counting today.
    var daysLeftInWeek: Int {
        max(1, calendar.dateComponents([.day], from: today, to: weekInterval.end).day ?? 1)
    }

    /// Number of days (capped at 30) between the first logged expense and today.
    var trackedDays: Int {
        guard let first = expenses.map(\.date).min() else { return 0 }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: first), to: today).day ?? 0
        return min(max(days + 1, 1), 30)
    }

    func dailyTotals(days: Int = 7) -> [DayTotal] {
        (0..<days).map { i in
            let start = day(-(days - 1 - i))
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            return DayTotal(date: start, total: total(from: start, to: end))
        }
    }

    func categoryTotals(days: Int = 30) -> [CategoryTotal] {
        let start = day(-(days - 1))
        let all = total(from: start, to: tomorrow)
        guard all > 0 else { return [] }
        return SpendCategory.allCases
            .compactMap { category -> CategoryTotal? in
                let t = total(from: start, to: tomorrow, category: category)
                return t > 0 ? CategoryTotal(category: category, total: t, share: t / all) : nil
            }
            .sorted { $0.total > $1.total }
    }

    // MARK: Weekly limit suggestion

    /// Suggests a weekly limit by looking at recent weekly pace and trimming
    /// discretionary categories (more aggressively for categories flagged as too large).
    func suggestion() -> LimitSuggestion? {
        let span = trackedDays
        guard span >= 3, expenses.count >= 5 else { return nil }

        let shares = categoryTotals(days: span)
        let spanTotal = shares.reduce(0) { $0 + $1.total }
        guard spanTotal > 0 else { return nil }

        let limits: [CategoryLimit] = shares.map { item in
            let weekly = item.total / Double(span) * 7
            let factor: Double
            if item.category.isEssential {
                factor = 1.0
            } else if item.share > item.category.shareThreshold {
                factor = 0.80
            } else if item.category == .transport {
                factor = 0.95
            } else {
                factor = 0.90
            }
            return CategoryLimit(category: item.category,
                                 weeklyAverage: weekly,
                                 suggested: Self.niceRound(weekly * factor))
        }

        let amount = limits.reduce(0) { $0 + $1.suggested }
        let pace = spanTotal / Double(span) * 7
        return LimitSuggestion(amount: amount, currentPace: pace, spanDays: span, categoryLimits: limits)
    }

    static func niceRound(_ value: Double) -> Double {
        guard value > 0 else { return 0 }
        let step: Double
        switch value {
        case 5000...: step = 100
        case 1000...: step = 50
        case 200...: step = 10
        case 20...: step = 5
        default: step = 1
        }
        return max(step, (value / step).rounded() * step)
    }

    // MARK: Pattern detection

    func insights() -> [Insight] {
        guard expenses.count >= 3 else { return [] }

        let span = trackedDays
        let window = max(1, span)
        let windowStart = day(-(window - 1))
        let totals = categoryTotals(days: window)
        let windowTotal = totals.reduce(0) { $0 + $1.total }
        guard windowTotal > 0 else { return [] }

        let windowLabel = window == 1 ? "today" : "over the last \(window) days"
        var warnings: [Insight] = []
        var notes: [Insight] = []

        // 1. A category takes too big a slice of the budget.
        if span >= 3 {
            for item in totals where item.share > item.category.shareThreshold {
                let limitPct = percent(item.category.shareThreshold)
                warnings.append(Insight(
                    severity: .warning,
                    icon: item.category.icon,
                    title: "\(item.category.title) is \(percent(item.share))% of your spending",
                    detail: "\(money(item.total)) \(windowLabel). A healthier range is under about \(limitPct)% — try trimming a little each week.",
                    category: item.category
                ))
            }
        }

        // 2. Week-over-week changes (needs roughly two weeks of history).
        if span >= 10 {
            let lastStart = day(-6)
            let prevStart = day(-13)
            let last7 = total(from: lastStart, to: tomorrow)
            let prev7 = total(from: prevStart, to: lastStart)

            for category in SpendCategory.allCases {
                let last = total(from: lastStart, to: tomorrow, category: category)
                let prev = total(from: prevStart, to: lastStart, category: category)
                guard prev > 0, last >= prev * 1.3, (last - prev) >= max(last7 * 0.05, 1) else { continue }
                let rise = Int(((last / prev - 1) * 100).rounded())
                warnings.append(Insight(
                    severity: .warning,
                    icon: "arrow.up.right",
                    title: "\(category.title) is up \(rise)% vs the week before",
                    detail: "\(money(last)) in the last 7 days compared with \(money(prev)) the 7 days before.",
                    category: category
                ))
            }

            if prev7 > 0 {
                let change = (last7 - prev7) / prev7
                if change > 0.15 {
                    warnings.append(Insight(
                        severity: .warning,
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Overall spending is up \(percent(change))%",
                        detail: "\(money(last7)) in the last 7 days vs \(money(prev7)) the week before.",
                        category: nil
                    ))
                } else if change < -0.10 {
                    notes.append(Insight(
                        severity: .positive,
                        icon: "arrow.down.right.circle.fill",
                        title: "Spending is down \(percent(-change))%",
                        detail: "Nice — \(money(last7)) in the last 7 days vs \(money(prev7)) the week before.",
                        category: nil
                    ))
                }
            }
        }

        // 3. Lots of small purchases that quietly add up.
        let recent = expenses.filter { $0.date >= windowStart && $0.date < tomorrow }
        if recent.count >= 10 {
            let average = windowTotal / Double(recent.count)
            let candidates: [SpendCategory] = [.food, .transport, .shopping, .entertainment]
            for category in candidates {
                let small = recent.filter { $0.category == category && $0.amount <= average * 0.6 }
                let sum = small.reduce(0) { $0 + $1.amount }
                if small.count >= 6, sum >= windowTotal * 0.08 {
                    notes.append(Insight(
                        severity: .info,
                        icon: "cup.and.saucer.fill",
                        title: "Small \(category.shortTitle.lowercased()) purchases add up",
                        detail: "\(small.count) small purchases came to \(money(sum)) \(windowLabel) — easy to overlook one at a time.",
                        category: category
                    ))
                }
            }
        }

        // 4. Weekends vs weekdays.
        if span >= 14 {
            var weekendTotal = 0.0, weekendDays = 0
            var weekdayTotal = 0.0, weekdayDays = 0
            for offset in 0..<window {
                let start = day(-offset)
                let end = day(-offset + 1)
                let t = total(from: start, to: end)
                if calendar.isDateInWeekend(start) {
                    weekendTotal += t; weekendDays += 1
                } else {
                    weekdayTotal += t; weekdayDays += 1
                }
            }
            if weekendDays >= 3, weekdayDays >= 3 {
                let weekendAvg = weekendTotal / Double(weekendDays)
                let weekdayAvg = weekdayTotal / Double(weekdayDays)
                if weekdayAvg > 0, weekendAvg > weekdayAvg * 1.5 {
                    let ratio = String(format: "%.1f", weekendAvg / weekdayAvg)
                    notes.append(Insight(
                        severity: .info,
                        icon: "calendar",
                        title: "Weekends cost you \(ratio)× more per day",
                        detail: "About \(money(weekendAvg)) a day on weekends vs \(money(weekdayAvg)) on weekdays.",
                        category: nil
                    ))
                }
            }
        }

        // 5. Reassurance when nothing is off.
        if warnings.isEmpty, span >= 7 {
            notes.insert(Insight(
                severity: .positive,
                icon: "checkmark.seal.fill",
                title: "No unusual patterns found",
                detail: "Your spending looks balanced across categories. Keep logging to stay on track.",
                category: nil
            ), at: 0)
        }

        return warnings + notes
    }
}
