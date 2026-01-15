// =============================================================================
// SmallWidgetView.swift - Small Widget (2x1) View
// =============================================================================
import SwiftUI
import WidgetKit

// MARK: - Small Widget View
struct SmallWidgetView: View {
    let entry: BudgetEntry

    // Currency formatter for Korean Won
    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.maximumFractionDigits = 0
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Line 1: Budget name + remaining days
            HStack {
                Text(entry.smallBudgetName)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                Text("D-\(entry.smallRemainingDays)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Line 2: Balance (red if warning)
            Text(currencyFormatter.string(from: NSNumber(value: entry.smallBalance)) ?? "\(entry.smallBalance)원")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(entry.smallIsWarning ? .red : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Small Widget Configuration
struct SmallBudgetWidget: Widget {
    // kind must match iOSName in Flutter's HomeWidget.updateWidget()
    let kind: String = "BudgetWidgetSmall"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SimpleProvider()) { entry in
            SmallWidgetView(entry: entry)
        }
        .configurationDisplayName("Budget Balance")
        .description("Shows your budget balance and remaining days")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Simple Provider (no intent)
struct SimpleProvider: TimelineProvider {
    private let appGroupId = "group.com.example.budgetapp.widget"

    func placeholder(in context: Context) -> BudgetEntry {
        BudgetEntry(
            date: Date(),
            configuration: nil,
            smallBudgetName: "Budget",
            smallRemainingDays: 15,
            smallBalance: 150000,
            smallIsWarning: false,
            mediumBudgetName: "Monthly Budget",
            mediumTotalBudget: 500000,
            mediumSpent: 200000,
            mediumRemaining: 300000,
            mediumIsWarning: false,
            categories: []
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgetEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> BudgetEntry {
        guard let userDefaults = UserDefaults(suiteName: appGroupId) else {
            return placeholder(in: Context())
        }

        // Small widget data
        let smallBudgetName = userDefaults.string(forKey: "small_budgetName") ?? "Budget"
        let smallRemainingDays = userDefaults.integer(forKey: "small_remainingDays")
        let smallBalance = userDefaults.integer(forKey: "small_remaining")
        let smallIsWarning = userDefaults.bool(forKey: "small_isWarning")

        // Medium widget data
        let mediumBudgetName = userDefaults.string(forKey: "medium_budgetName") ?? "Budget"
        let mediumTotalBudget = userDefaults.integer(forKey: "medium_totalBudget")
        let mediumSpent = userDefaults.integer(forKey: "medium_spent")
        let mediumRemaining = userDefaults.integer(forKey: "medium_remaining")
        let mediumIsWarning = userDefaults.bool(forKey: "medium_isWarning")

        // Large widget - categories
        let categoryCount = userDefaults.integer(forKey: "large_categoryCount")
        var categories: [CategoryData] = []
        for i in 0..<min(categoryCount, 5) {
            let prefix = "large_cat\(i)"
            let name = userDefaults.string(forKey: "\(prefix)_name") ?? ""
            if !name.isEmpty {
                categories.append(CategoryData(
                    name: name,
                    budget: userDefaults.integer(forKey: "\(prefix)_budget"),
                    spent: userDefaults.integer(forKey: "\(prefix)_spent"),
                    remaining: userDefaults.integer(forKey: "\(prefix)_remaining"),
                    isWarning: userDefaults.bool(forKey: "\(prefix)_isWarning")
                ))
            }
        }

        return BudgetEntry(
            date: Date(),
            configuration: nil,
            smallBudgetName: smallBudgetName,
            smallRemainingDays: smallRemainingDays,
            smallBalance: smallBalance,
            smallIsWarning: smallIsWarning,
            mediumBudgetName: mediumBudgetName,
            mediumTotalBudget: mediumTotalBudget,
            mediumSpent: mediumSpent,
            mediumRemaining: mediumRemaining,
            mediumIsWarning: mediumIsWarning,
            categories: categories
        )
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    SmallBudgetWidget()
} timeline: {
    BudgetEntry(
        date: Date(),
        configuration: nil,
        smallBudgetName: "Food Budget",
        smallRemainingDays: 12,
        smallBalance: 85000,
        smallIsWarning: false,
        mediumBudgetName: "",
        mediumTotalBudget: 0,
        mediumSpent: 0,
        mediumRemaining: 0,
        mediumIsWarning: false,
        categories: []
    )
    BudgetEntry(
        date: Date(),
        configuration: nil,
        smallBudgetName: "Transport",
        smallRemainingDays: 5,
        smallBalance: 15000,
        smallIsWarning: true,
        mediumBudgetName: "",
        mediumTotalBudget: 0,
        mediumSpent: 0,
        mediumRemaining: 0,
        mediumIsWarning: false,
        categories: []
    )
}
