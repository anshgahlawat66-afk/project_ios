import SwiftUI

// MARK: - Card style

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
}

// MARK: - Category badge

struct CategoryBadge: View {
    let category: SpendCategory
    var size: CGFloat = 38

    var body: some View {
        Image(systemName: category.icon)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(category.color.gradient, in: Circle())
    }
}

// MARK: - Insights

extension Insight.Severity {
    var color: Color {
        switch self {
        case .warning: return .orange
        case .info: return .blue
        case .positive: return .green
        }
    }
}

struct InsightRow: View {
    let insight: Insight

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(insight.severity.color)
                .frame(width: 30, height: 30)
                .background(insight.severity.color.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(insight.title)
                    .font(.subheadline.weight(.semibold))
                Text(insight.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Expense row

struct ExpenseRow: View {
    let expense: Expense
    let currencyCode: String

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadge(category: expense.category)
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.note.isEmpty ? expense.category.title : expense.note)
                    .font(.body)
                    .lineLimit(1)
                Text(expense.note.isEmpty
                     ? expense.date.formatted(date: .omitted, time: .shortened)
                     : "\(expense.category.shortTitle) · \(expense.date.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Money.string(expense.amount, code: currencyCode, decimals: true))
                .font(.body.weight(.semibold))
                .monospacedDigit()
        }
        .contentShape(Rectangle())
    }
}
