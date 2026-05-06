import XCTest
import SwiftData
@testable import StayTrackr_V3

@MainActor
final class V4MigrationsTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var property: STProperty!

    override func setUp() async throws {
        let schema = Schema([
            STProperty.self, STGuest.self, STBooking.self,
            STExpense.self, STRecurringBill.self,
            STFXRate.self, V4AppPreferences.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
        property = STProperty(
            id: UUID(), name: "Migration Test Property", purchasePrice: 100_000,
            mortgageAPR: 0.04, mortgageYears: 20, commissionPct: 0.08,
            emoji: "🏡", colorHex: "#336699", isArchived: false, trackMortgage: false,
            currencyCode: "EUR"
        )
        context.insert(property)
    }

    override func tearDown() async throws {
        container = nil
        context = nil
        property = nil
    }

    func testBackfillSetsCurrencyFromProperty() throws {
        // Empty string triggers backfill
        let expense = STExpense(
            id: UUID(), property: property,
            date: Date(), amount: 50, category: .cleaning,
            currencyCode: ""
        )
        context.insert(expense)
        try context.save()

        V4Migrations.backfillExpenseCurrency(in: context)

        XCTAssertEqual(expense.currencyCode, "EUR")
    }

    func testBackfillDoesNotOverwriteExistingCurrency() throws {
        let expense = STExpense(
            id: UUID(), property: property,
            date: Date(), amount: 50, category: .cleaning,
            currencyCode: "USD"
        )
        context.insert(expense)
        try context.save()

        V4Migrations.backfillExpenseCurrency(in: context)

        XCTAssertEqual(expense.currencyCode, "USD")
    }

    func testBackfillDoesNotCrashOnEmptyContext() {
        // No expenses in context — should be a no-op
        V4Migrations.backfillExpenseCurrency(in: context)
    }

    func testBackfillHandlesWhitespaceOnlyCurrencyCode() throws {
        let expense = STExpense(
            id: UUID(), property: property,
            date: Date(), amount: 75, category: .utilities,
            currencyCode: "   "
        )
        context.insert(expense)
        try context.save()

        V4Migrations.backfillExpenseCurrency(in: context)

        XCTAssertEqual(expense.currencyCode, "EUR")
    }

    func testBackfillOnlyAffectsExpensesWithEmptyCurrency() throws {
        let expenseEmpty = STExpense(
            id: UUID(), property: property,
            date: Date(), amount: 100, category: .repairs,
            currencyCode: ""
        )
        let expenseGBP = STExpense(
            id: UUID(), property: property,
            date: Date(), amount: 200, category: .management,
            currencyCode: "GBP"
        )
        context.insert(expenseEmpty)
        context.insert(expenseGBP)
        try context.save()

        V4Migrations.backfillExpenseCurrency(in: context)

        XCTAssertEqual(expenseEmpty.currencyCode, "EUR")
        XCTAssertEqual(expenseGBP.currencyCode, "GBP")
    }
}
