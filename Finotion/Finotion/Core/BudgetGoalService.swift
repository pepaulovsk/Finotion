import SwiftData

enum BudgetGoalService {
    // Copies all goals from sourceMonth to targetMonth if targetMonth has no goals.
    // Called at first access of a new month to carry forward the previous month's limits.
    static func autoCarry(from sourceMonth: String, to targetMonth: String, context: ModelContext) throws {
        let allGoals = try context.fetch(FetchDescriptor<BudgetGoal>())
        let existing = allGoals.filter { $0.yearMonth == targetMonth }
        guard existing.isEmpty else { return }

        let sourceGoals = allGoals.filter { $0.yearMonth == sourceMonth }
        for goal in sourceGoals {
            context.insert(BudgetGoal(
                categoryName: goal.categoryName,
                yearMonth: targetMonth,
                limitAmount: goal.limitAmount
            ))
        }
        try context.save()
    }
}
