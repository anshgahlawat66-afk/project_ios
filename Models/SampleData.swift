import Foundation
import SwiftData

/// Generates ~5 weeks of realistic demo expenses so every screen has something to show.
/// Food-heavy, pricier weekends, and a shopping surge in the last 7 days.
enum SampleData {
    /// Rough price level per currency relative to INR (so a lunch looks like a lunch).
    static func scale(for code: String) -> Double {
        switch code {
        case "INR": return 1
        case "JPY": return 7
        case "USD": return 0.05
        case "EUR": return 0.045
        case "GBP": return 0.04
        default: return 0.05
        }
    }

    static func load(into context: ModelContext, currencyCode: String, calendar: Calendar = .current) {
        let scale = scale(for: currencyCode)
        let today = calendar.startOfDay(for: Date.now)
        let cap = Date.now

        func amount(_ range: ClosedRange<Double>) -> Double {
            let v = Double.random(in: range) * scale
            return scale < 0.5 ? (v * 100).rounded() / 100 : v.rounded()
        }

        for offset in 0..<35 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let weekend = calendar.isDateInWeekend(day)
            let recent = offset < 7

            func add(_ range: ClosedRange<Double>, _ category: SpendCategory, _ notes: [String], hour: Int) {
                var parts = calendar.dateComponents([.year, .month, .day], from: day)
                parts.hour = hour
                parts.minute = Int.random(in: 0..<60)
                let date = min(calendar.date(from: parts) ?? day, cap)
                context.insert(Expense(amount: amount(range),
                                       category: category,
                                       note: notes.randomElement() ?? "",
                                       date: date))
            }

            // Food
            add(60...180, .food, ["Breakfast", "Chai & snacks", "Coffee"], hour: 9)
            add(weekend ? 250...700 : 120...350, .food, ["Lunch", "Office canteen", "Biryani"], hour: 13)
            if Double.random(in: 0...1) < 0.7 {
                add(weekend ? 350...900 : 200...600, .food, ["Swiggy order", "Zomato dinner", "Dinner out"], hour: 20)
            }

            // Transport
            if !weekend {
                add(60...260, .transport, ["Metro", "Uber", "Auto ride"], hour: 9)
                if Bool.random() { add(60...260, .transport, ["Uber home", "Metro", "Auto ride"], hour: 19) }
            } else if Double.random(in: 0...1) < 0.3 {
                add(150...450, .transport, ["Cab"], hour: 18)
            }

            // Online shopping (surges in the most recent week)
            if Double.random(in: 0...1) < (recent ? 0.5 : 0.15) {
                add(recent ? 900...3200 : 300...1800, .shopping,
                    ["Amazon order", "Flipkart", "Myntra", "Online order"], hour: 22)
            }

            // Entertainment
            if weekend, Double.random(in: 0...1) < 0.6 {
                add(200...900, .entertainment, ["Movie tickets", "Gaming top-up", "Streaming add-on"], hour: 19)
            }

            // Bills & health
            if offset == 3 { add(1000...1400, .bills, ["Electricity bill"], hour: 11) }
            if offset == 12 { add(299...299, .bills, ["Mobile recharge"], hour: 11) }
            if offset == 20 { add(799...799, .bills, ["Broadband"], hour: 11) }
            if offset == 9 { add(250...700, .health, ["Pharmacy"], hour: 17) }
        }
    }
}
