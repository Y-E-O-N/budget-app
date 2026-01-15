// =============================================================================
// MediumWidgetView.swift - Medium Widget (3x2) View
// =============================================================================
import SwiftUI
import WidgetKit

// MARK: - Medium Widget View
struct MediumWidgetView: View {
    let entry: BudgetEntry

    // Currency formatter for Korean Won
    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.maximumFractionDigits = 0
        return formatter
    }

    // Calculate progress percentage
    private var progressPercentage: Double {
        guard entry.mediumTotalBudget > 0 else { return 0 }
        return Double(entry.mediumSpent) / Double(entry.mediumTotalBudget)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Line 1: Budget name + total budget
            HStack {
                Text(entry.mediumBudgetName)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)

                Spacer()

                Text(currencyFormatter.string(from: NSNumber(value: entry.mediumTotalBudget)) ?? "")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)

                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(entry.mediumIsWarning ? Color.red : Color.blue)
                        .frame(width: geometry.size.width * min(progressPercentage, 1.0), height: 8)
                }
            }
            .frame(height: 8)

            // Line 2 & 3: Spent and Remaining
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Spent")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(currencyFormatter.string(from: NSNumber(value: entry.mediumSpent)) ?? "")
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Remaining")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(currencyFormatter.string(from: NSNumber(value: entry.mediumRemaining)) ?? "")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(entry.mediumIsWarning ? .red : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Medium Widget Configuration
struct MediumBudgetWidget: Widget {
    // kind must match iOSName in Flutter's HomeWidget.updateWidget()
    let kind: String = "BudgetWidgetMedium"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SimpleProvider()) { entry in
            MediumWidgetView(entry: entry)
        }
        .configurationDisplayName("Budget Overview")
        .description("Shows your budget, spending, and remaining balance")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Preview
#Preview(as: .systemMedium) {
    MediumBudgetWidget()
} timeline: {
    BudgetEntry(
        date: Date(),
        configuration: nil,
        smallBudgetName: "",
        smallRemainingDays: 0,
        smallBalance: 0,
        smallIsWarning: false,
        mediumBudgetName: "Monthly Budget",
        mediumTotalBudget: 500000,
        mediumSpent: 200000,
        mediumRemaining: 300000,
        mediumIsWarning: false,
        categories: []
    )
    BudgetEntry(
        date: Date(),
        configuration: nil,
        smallBudgetName: "",
        smallRemainingDays: 0,
        smallBalance: 0,
        smallIsWarning: false,
        mediumBudgetName: "Food Expenses",
        mediumTotalBudget: 300000,
        mediumSpent: 280000,
        mediumRemaining: 20000,
        mediumIsWarning: true,
        categories: []
    )
}
