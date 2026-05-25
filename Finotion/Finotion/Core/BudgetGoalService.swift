import SwiftData

enum BudgetGoalService {
    // Copies all goals from sourceMonth to targetMonth if targetMonth has no goals.
    // Called at first access of a new month to carry forward the previous month's limits.
    static func autoCarry(from sourceMonth: String, to targetMonth: String, context: ModelContext) throws {
        let targetDescriptor = FetchDescriptor<BudgetGoal>(
            predicate: #Predicate { $0.yearMonth == targetMonth }
        )
        let existing = try context.fetch(targetDescriptor)
        guard existing.isEmpty else { return }

        let sourceDescriptor = FetchDescriptor<BudgetGoal>(
            predicate: #Predicate { $0.yearMonth == sourceMonth }
        )
        let sourceGoals = try context.fetch(sourceDescriptor)
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
