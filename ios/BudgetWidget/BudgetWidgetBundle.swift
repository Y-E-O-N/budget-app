// =============================================================================
// BudgetWidgetBundle.swift - Widget Bundle Entry Point
// =============================================================================
import WidgetKit
import SwiftUI

// MARK: - Widget Bundle
@main
struct BudgetWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Small widget - Balance display
        SmallBudgetWidget()

        // Medium widget - Budget overview
        MediumBudgetWidget()

        // Large widget - Category details
        LargeBudgetWidget()
    }
}
