import SwiftUI
import SwiftData

// MARK: - Category

enum SpendCategory: String, CaseIterable, Identifiable, Codable {
    case food, transport, shopping, bills, entertainment, health, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .food: return "Food & Dining"
        case .transport: return "Transport"
        case .shopping: return "Online & Shopping"
        case .bills: return "Bills & Utilities"
        case .entertainment: return "Entertainment"
        case .health: return "Health"
        case .other: return "Other"
        }
    }

    var shortTitle: String {
        switch self {
        case .food: return "Food"
        case .transport: return "Transport"
        case .shopping: return "Shopping"
        case .bills: return "Bills"
        case .entertainment: return "Entertainment"
        case .health: return "Health"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "car.fill"
        case .shopping: return "bag.fill"
        case .bills: return "bolt.fill"
        case .entertainment: return "gamecontroller.fill"
        case .health: return "cross.case.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .food: return .orange
        case .transport: return .blue
        case .shopping: return .pink
        case .bills: return .indigo
        case .entertainment: return .purple
        case .health: return .mint
        case .other: return .gray
        }
    }

    /// Bills and health are hard to cut, so the suggested limit leaves them alone.
    var isEssential: Bool { self == .bills || self == .health }

    /// Share of total spending above which we flag the category.
    /// These are rule-of-thumb heuristics, not financial advice.
    var shareThreshold: Double {
        switch self {
        case .food: return 0.35
        case .transport: return 0.20
        case .shopping: return 0.20
        case .entertainment: return 0.12
        case .bills, .health, .other: return 1.0 // never flagged on share alone
        }
    }
}

// MARK: - Expense (SwiftData)

@Model
final class Expense {
    var id: UUID
    var amount: Double
    var categoryRaw: String
    var note: String
    var date: Date

    init(amount: Double, category: SpendCategory, note: String = "", date: Date = Date.now) {
        self.id = UUID()
        self.amount = amount
        self.categoryRaw = category.rawValue
        self.note = note
        self.date = date
    }

    var category: SpendCategory {
        get { SpendCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}

// MARK: - Money formatting

enum Money {
    static var defaultCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    static func string(_ value: Double, code: String, decimals: Bool = false) -> String {
        value.formatted(
            .currency(code: code)
            .precision(decimals ? .fractionLength(2) : .fractionLength(0))
        )
    }

    static func symbol(for code: String) -> String {
        Locale(identifier: "en_US@currency=\(code)").currencySymbol ?? code
    }
}
