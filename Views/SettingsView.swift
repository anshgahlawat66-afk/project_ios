import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Wrapper so the CSV can be shared with a proper file name.
struct CSVFile: Transferable {
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { csv in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("SpendSense-Export.csv")
            try Data(csv.text.utf8).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Expense.date) private var expenses: [Expense]
    @AppStorage("weeklyLimit") private var weeklyLimit: Double = 0
    @AppStorage("currencyCode") private var currencyCode = Money.defaultCode
    @State private var confirmDelete = false

    private static let commonCurrencies = ["INR", "USD", "EUR", "GBP", "JPY", "AUD", "CAD", "SGD", "AED"]

    private var currencyOptions: [String] {
        Self.commonCurrencies.contains(currencyCode)
            ? Self.commonCurrencies
            : [currencyCode] + Self.commonCurrencies
    }

    private var csv: CSVFile {
        let formatter = ISO8601DateFormatter()
        var lines = ["Date,Category,Amount,Note"]
        for e in expenses {
            let note = e.note.replacingOccurrences(of: "\"", with: "\"\"")
            lines.append("\(formatter.string(from: e.date)),\(e.category.title),\(e.amount),\"\(note)\"")
        }
        return CSVFile(text: lines.joined(separator: "\n"))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Preferences") {
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(currencyOptions, id: \.self) { code in
                            Text("\(code) · \(Locale.current.localizedString(forCurrencyCode: code) ?? code)")
                                .tag(code)
                        }
                    }

                    HStack {
                        Text("Weekly limit")
                        Spacer()
                        TextField("Not set", value: $weeklyLimit, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 140)
                    }

                    if weeklyLimit > 0 {
                        Button("Remove weekly limit", role: .destructive) { weeklyLimit = 0 }
                    }
                }

                Section {
                    Button {
                        SampleData.load(into: context, currencyCode: currencyCode)
                    } label: {
                        Label("Load sample data", systemImage: "wand.and.stars")
                    }

                    ShareLink(item: csv, preview: SharePreview("SpendSense Export.csv")) {
                        Label("Export as CSV", systemImage: "square.and.arrow.up")
                    }
                    .disabled(expenses.isEmpty)

                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Delete all expenses", systemImage: "trash")
                    }
                    .disabled(expenses.isEmpty)
                } header: {
                    Text("Data")
                } footer: {
                    Text("\(expenses.count) expense\(expenses.count == 1 ? "" : "s") stored on this device. Nothing is sent anywhere.")
                }

                Section("About") {
                    LabeledContent("SpendSense", value: "1.0")
                    Text("Pattern thresholds (e.g. food under ~35% of spending) are general rules of thumb, not financial advice.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Delete all expenses?",
                                isPresented: $confirmDelete,
                                titleVisibility: .visible) {
                Button("Delete All", role: .destructive) {
                    try? context.delete(model: Expense.self)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This can't be undone.")
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: Expense.self, inMemory: true)
}
