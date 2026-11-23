import SwiftUI
import SwiftData

/// Add a new expense, or edit an existing one when `expense` is passed.
struct ExpenseFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("currencyCode") private var currencyCode = Money.defaultCode

    let expense: Expense?

    @State private var amountText: String
    @State private var category: SpendCategory
    @State private var note: String
    @State private var date: Date
    @FocusState private var amountFocused: Bool

    init(expense: Expense? = nil) {
        self.expense = expense
        let initialAmount: String
        if let expense {
            initialAmount = expense.amount.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
        } else {
            initialAmount = ""
        }
        _amountText = State(initialValue: initialAmount)
        _category = State(initialValue: expense?.category ?? .food)
        _note = State(initialValue: expense?.note ?? "")
        _date = State(initialValue: expense?.date ?? Date.now)
    }

    private var parsedAmount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var isValid: Bool { (parsedAmount ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    HStack(spacing: 6) {
                        Text(Money.symbol(for: currencyCode))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .focused($amountFocused)
                    }
                }

                Section("Category") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                              spacing: 14) {
                        ForEach(SpendCategory.allCases) { c in
                            Button { category = c } label: {
                                VStack(spacing: 6) {
                                    CategoryBadge(category: c, size: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary, lineWidth: category == c ? 2.5 : 0)
                                                .padding(-3)
                                        )
                                    Text(c.shortTitle)
                                        .font(.caption2)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .foregroundStyle(category == c ? .primary : .secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Details") {
                    DatePicker("Date", selection: $date, in: ...Date.now)
                    TextField("Note (optional)", text: $note)
                }
            }
            .navigationTitle(expense == nil ? "New Expense" : "Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!isValid)
                }
            }
            .onAppear { if expense == nil { amountFocused = true } }
        }
        .presentationDetents([.large])
    }

    private func save() {
        guard let value = parsedAmount, value > 0 else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let expense {
            expense.amount = value
            expense.category = category
            expense.note = trimmed
            expense.date = date
        } else {
            context.insert(Expense(amount: value, category: category, note: trimmed, date: date))
        }
        dismiss()
    }
}

#Preview {
    ExpenseFormView()
        .modelContainer(for: Expense.self, inMemory: true)
}
