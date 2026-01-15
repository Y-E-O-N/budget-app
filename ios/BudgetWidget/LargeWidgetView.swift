// =============================================================================
// LargeWidgetView.swift - Large Widget (4x3) View with Category Details
// =============================================================================
import SwiftUI
import WidgetKit

// MARK: - Large Widget View
struct LargeWidgetView: View {
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
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.blue)
                Text("Budget Categories")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }
            .padding(.bottom, 4)

            // Category list
            if entry.categories.isEmpty {
                // Empty state
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.system(size: 32))
                            .foregroundColor(.gray)
                        Text("No budget data")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // Category rows (max 5)
                ForEach(entry.categories.prefix(5)) { category in
                    CategoryRow(category: category, formatter: currencyFormatter)
                }

                Spacer()
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Category Row Component
struct CategoryRow: View {
    let category: CategoryData
    let formatter: NumberFormatter

    // Calculate progress percentage
    private var progressPercentage: Double {
        guard category.budget > 0 else { return 0 }
        return Double(category.spent) / Double(category.budget)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Category name and amounts
            HStack {
                Text(category.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Spacer()

                Text(formatter.string(from: NSNumber(value: category.remaining)) ?? "")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(category.isWarning ? .red : .primary)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    // Progress
                    RoundedRectangle(cornerRadius: 3)
                        .fill(category.isWarning ? Color.red : Color.blue)
                        .frame(width: geometry.size.width * min(progressPercentage, 1.0), height: 6)
                }
            }
            .frame(height: 6)

            // Spent / Budget text
            HStack {
                Text("\(formatter.string(from: NSNumber(value: category.spent)) ?? "") / \(formatter.string(from: NSNumber(value: category.budget)) ?? "")")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Large Widget Configuration
struct LargeBudgetWidget: Widget {
    // kind must match iOSName in Flutter's HomeWidget.updateWidget()
    let kind: String = "BudgetWidgetLarge"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SimpleProvider()) { entry in
            LargeWidgetView(entry: entry)
        }
        .configurationDisplayName("Budget Details")
        .description("Shows detailed breakdown of all budget categories")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - Preview
#Preview(as: .systemLarge) {
    LargeBudgetWidget()
} timeline: {
    BudgetEntry(
        date: Date(),
        configuration: nil,
        smallBudgetName: "",
        smallRemainingDays: 0,
        smallBalance: 0,
        smallIsWarning: false,
        mediumBudgetName: "",
        mediumTotalBudget: 0,
        mediumSpent: 0,
        mediumRemaining: 0,
        mediumIsWarning: false,
        categories: [
            CategoryData(name: "Food", budget: 300000, spent: 180000, remaining: 120000, isWarning: false),
            CategoryData(name: "Transport", budget: 100000, spent: 85000, remaining: 15000, isWarning: true),
            CategoryData(name: "Entertainment", budget: 150000, spent: 50000, remaining: 100000, isWarning: false),
            CategoryData(name: "Shopping", budget: 200000, spent: 190000, remaining: 10000, isWarning: true),
            CategoryData(name: "Utilities", budget: 80000, spent: 60000, remaining: 20000, isWarning: false)
        ]
    )
}
