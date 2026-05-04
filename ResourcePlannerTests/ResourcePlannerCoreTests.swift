import XCTest
@testable import ResourcePlannerCore

final class ResourcePlannerCoreTests: XCTestCase {

    // MARK: - Rate normalization (monthly)

    func testMonthlyCostAnnual() {
        let r = Resource(name: "A", rate: 120_000, rateBasis: .annual)
        XCTAssertEqual(r.monthlyCost, 10_000, accuracy: 0.0001)
    }

    func testMonthlyCostMonthly() {
        let r = Resource(name: "B", rate: 10_000, rateBasis: .monthly)
        XCTAssertEqual(r.monthlyCost, 10_000, accuracy: 0.0001)
    }

    func testMonthlyCostHourly() {
        let r = Resource(name: "C", rate: 100, rateBasis: .hourly, hoursPerWeek: 40)
        // 100 * 40 * (52/12) = 100 * 40 * 4.333... ≈ 17333.33
        XCTAssertEqual(r.monthlyCost, 100 * 40 * 52.0 / 12.0, accuracy: 0.01)
    }

    // MARK: - Codable round-trip

    func testDocumentRoundTrip() throws {
        let role = Role(name: "Developer")
        let res = Resource(name: "Alice", roleID: role.id, rate: 150_000, rateBasis: .annual)
        let init1 = Initiative(name: "CRM Rebuild",
                               startDate: Date(timeIntervalSince1970: 1_767_225_600),
                               endDate: Date(timeIntervalSince1970: 1_798_761_600))
        let alloc = Allocation(resourceID: res.id, months: [
            MonthKey(year: 2026, month: 5): 0.5,
            MonthKey(year: 2026, month: 6): 0.8,
        ])
        let assignment = Assignment(name: "Requirements", initiativeID: init1.id, allocations: [alloc])
        let plan = Plan(name: "Baseline", initiatives: [init1], assignments: [assignment])

        let doc = PlannerDocument(resources: [res], roles: [role], plans: [plan])
        let data = try doc.encoded()
        let back = try PlannerDocument.decoded(from: data)
        XCTAssertEqual(doc, back)
    }

    func testMonthKeyEncodesAsStringDictKey() throws {
        let alloc = Allocation(resourceID: UUID(), months: [
            MonthKey(year: 2026, month: 6): 1.0,
        ])
        let data = try JSONEncoder().encode(alloc)
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("\"2026-06\""), "Expected month string key, got: \(json)")
    }

    func testAllocationMonthlyRoundTrip() throws {
        var alloc = Allocation(resourceID: UUID())
        alloc.months[MonthKey(year: 2026, month: 6)] = 0.75
        let data = try JSONEncoder().encode(alloc)
        let decoded = try JSONDecoder().decode(Allocation.self, from: data)
        let value = try XCTUnwrap(decoded.months[MonthKey(year: 2026, month: 6)])
        XCTAssertEqual(value, 0.75, accuracy: 0.0001)
    }

    // MARK: - Monthly allocation independence

    func testSetMonthlyDoesNotBleedIntoNextMonth() {
        var alloc = Allocation(resourceID: UUID())
        alloc.months[MonthKey(year: 2026, month: 6)] = 0.5
        XCTAssertNil(alloc.months[MonthKey(year: 2026, month: 7)],
                     "Setting June should not affect July")
    }

    // MARK: - Plan helpers

    func testMonthAllocationAcrossAssignments() {
        let rid = UUID()
        let mk = MonthKey(year: 2026, month: 6)
        let alloc1 = Allocation(resourceID: rid, months: [mk: 0.5])
        let alloc2 = Allocation(resourceID: rid, months: [mk: 0.6])
        let a1 = Assignment(name: "A", initiativeID: UUID(), allocations: [alloc1])
        let a2 = Assignment(name: "B", initiativeID: UUID(), allocations: [alloc2])
        let plan = Plan(name: "Test", assignments: [a1, a2])
        let total = plan.monthAllocation(for: rid, in: mk)
        XCTAssertEqual(total, 1.1, accuracy: 0.0001)
    }

    func testAverageAllocationAcrossMonths() {
        let rid = UUID()
        let m1 = MonthKey(year: 2026, month: 6)
        let m2 = MonthKey(year: 2026, month: 7)
        let alloc = Allocation(resourceID: rid, months: [m1: 0.8, m2: 0.4])
        let a = Assignment(name: "A", initiativeID: UUID(), allocations: [alloc])
        let plan = Plan(name: "Test", assignments: [a])
        let avg = plan.averageAllocation(for: rid, in: [m1, m2])
        XCTAssertEqual(avg, 0.6, accuracy: 0.0001)
    }

    // MARK: - Currency

    func testCurrencyContextConversion() {
        let ctx = ReportData.CurrencyContext(
            displayCurrency: "CAD",
            conversionRates: ["USD": 1.37, "CAD": 1.0, "EUR": 1.52]
        )
        // Converting 1000 USD to CAD display: 1000 * 1.37 = 1370
        XCTAssertEqual(ctx.convert(1000, from: "USD"), 1370, accuracy: 0.01)
        // CAD to CAD (display currency): 1000 * 1.0 = 1000
        XCTAssertEqual(ctx.convert(1000, from: "CAD"), 1000, accuracy: 0.01)
        // EUR to CAD: 1000 * 1.52 = 1520
        XCTAssertEqual(ctx.convert(1000, from: "EUR"), 1520, accuracy: 0.01)
        // Unknown currency defaults to rate 1.0
        XCTAssertEqual(ctx.convert(1000, from: "GBP"), 1000, accuracy: 0.01)
    }

    func testCurrencyContextIdentity() {
        let ctx = ReportData.CurrencyContext.identity
        XCTAssertEqual(ctx.displayCurrency, "USD")
        XCTAssertEqual(ctx.convert(500, from: "USD"), 500, accuracy: 0.01)
    }

    func testResourceAdoptRoleDefaultsCopiesCurrency() {
        let role = Role(name: "Dev", defaultRate: 100_000, defaultRateBasis: .annual, currencyCode: "CAD")
        var resource = Resource(name: "Bob", rate: 80_000, rateBasis: .annual, currencyCode: "USD")
        resource.adoptRoleDefaults(role)
        XCTAssertEqual(resource.currencyCode, "CAD")
        XCTAssertEqual(resource.rate, 100_000, accuracy: 0.01)
        XCTAssertFalse(resource.isCustomRate)
    }

    func testResourceMatchesRoleDefaultChecksCountry() {
        let role = Role(name: "Dev", defaultRate: 100_000, defaultRateBasis: .annual, currencyCode: "CAD")
        let matching = Resource(name: "A", rate: 100_000, rateBasis: .annual, currencyCode: "CAD")
        let different = Resource(name: "B", rate: 100_000, rateBasis: .annual, currencyCode: "USD")
        XCTAssertTrue(matching.matchesRoleDefault(role))
        XCTAssertFalse(different.matchesRoleDefault(role))
    }

    func testDocumentRoundTripWithCurrency() throws {
        var doc = PlannerDocument()
        doc.displayCurrency = "EUR"
        doc.conversionRates = ["USD": 0.92, "CAD": 0.67, "EUR": 1.0]
        doc.resources = [Resource(name: "Alice", rate: 80_000, rateBasis: .annual, currencyCode: "CAD")]
        doc.roles = [Role(name: "Dev", currencyCode: "EUR")]
        let data = try doc.encoded()
        let back = try PlannerDocument.decoded(from: data)
        XCTAssertEqual(back.displayCurrency, "EUR")
        XCTAssertEqual(back.conversionRates["CAD"] ?? 0, 0.67, accuracy: 0.001)
        XCTAssertEqual(back.resources[0].currencyCode, "CAD")
        XCTAssertEqual(back.roles[0].currencyCode, "EUR")
    }

    func testOtherCostCurrencyRoundTrip() throws {
        let cost = OtherCost(
            name: "License",
            startDate: Date(timeIntervalSince1970: 1_767_225_600),
            endDate: Date(timeIntervalSince1970: 1_769_817_600),
            totalAmount: 5000,
            currencyCode: "CAD"
        )
        let data = try JSONEncoder().encode(cost)
        let decoded = try JSONDecoder().decode(OtherCost.self, from: data)
        XCTAssertEqual(decoded.currencyCode, "CAD")
        XCTAssertEqual(decoded.totalAmount, 5000, accuracy: 0.01)
    }

    func testBackwardCompatDecodingDefaultsToUSD() throws {
        // Simulate a v2 document without currency fields
        let json = """
        {
            "schemaVersion": 2,
            "resources": [],
            "roles": [],
            "plans": []
        }
        """
        let data = Data(json.utf8)
        let doc = try JSONDecoder().decode(PlannerDocument.self, from: data)
        XCTAssertEqual(doc.displayCurrency, "USD")
        XCTAssertEqual(doc.conversionRates["USD"], 1.0)
        XCTAssertEqual(doc.conversionRates["CAD"], 0.73)
    }
}
