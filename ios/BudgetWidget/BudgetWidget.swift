// =============================================================================
// BudgetWidget.swift - iOS Widget Entry Point
// =============================================================================
import WidgetKit
import SwiftUI

// MARK: - Widget Entry (Timeline Entry)
struct BudgetEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationIntent?

    // Small widget data
    let smallBudgetName: String
    let smallRemainingDays: Int
    let smallBalance: Int
    let smallIsWarning: Bool

    // Medium widget data
    let mediumBudgetName: String
    let mediumTotalBudget: Int
    let mediumSpent: Int
    let mediumRemaining: Int
    let mediumIsWarning: Bool

    // Large widget data
    let categories: [CategoryData]
}

// MARK: - Category Data for Large Widget
struct CategoryData: Identifiable {
    let id = UUID()
    let name: String
    let budget: Int
    let spent: Int
    let remaining: Int
    let isWarning: Bool
}

// MARK: - Timeline Provider
struct BudgetTimelineProvider: IntentTimelineProvider {
    typealias Entry = BudgetEntry
    typealias Intent = ConfigurationIntent

    // App Group ID - must match Flutter's widget_service.dart
    private let appGroupId = "group.com.example.budgetapp.widget"

    // Placeholder for preview
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
            categories: [
                CategoryData(name: "Food", budget: 200000, spent: 80000, remaining: 120000, isWarning: false),
                CategoryData(name: "Transport", budget: 100000, spent: 50000, remaining: 50000, isWarning: false)
            ]
        )
    }

    // Snapshot for gallery preview
    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (BudgetEntry) -> Void) {
        let entry = loadEntry(configuration: configuration)
        completion(entry)
    }

    // Timeline for widget updates
    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<BudgetEntry>) -> Void) {
        let entry = loadEntry(configuration: configuration)

        // Update every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    // Load data from UserDefaults (App Group)
    private func loadEntry(configuration: ConfigurationIntent?) -> BudgetEntry {
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

        // Large widget data - categories
        let categoryCount = userDefaults.integer(forKey: "large_categoryCount")
        var categories: [CategoryData] = []

        for i in 0..<min(categoryCount, 5) {
            let prefix = "large_cat\(i)"
            let name = userDefaults.string(forKey: "\(prefix)_name") ?? ""
            let budget = userDefaults.integer(forKey: "\(prefix)_budget")
            let spent = userDefaults.integer(forKey: "\(prefix)_spent")
            let remaining = userDefaults.integer(forKey: "\(prefix)_remaining")
            let isWarning = userDefaults.bool(forKey: "\(prefix)_isWarning")

            if !name.isEmpty {
                categories.append(CategoryData(
                    name: name,
                    budget: budget,
                    spent: spent,
                    remaining: remaining,
                    isWarning: isWarning
                ))
            }
        }

        return BudgetEntry(
            date: Date(),
            configuration: configuration,
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

// MARK: - Configuration Intent (placeholder)
struct ConfigurationIntent {
    // Can be extended for widget configuration
}
