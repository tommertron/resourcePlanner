import Foundation

nonisolated public struct PlannerDocument: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 4

    public var schemaVersion: Int
    public var resources: [Resource]
    public var roles: [Role]
    public var teams: [Team]
    public var plans: [Plan]
    public var displayCurrency: String
    public var conversionRates: [String: Double]

    public init(
        schemaVersion: Int = PlannerDocument.currentSchemaVersion,
        resources: [Resource] = [],
        roles: [Role] = [],
        teams: [Team] = [],
        plans: [Plan] = [],
        displayCurrency: String = "USD",
        conversionRates: [String: Double] = ["USD": 1.0, "CAD": 0.73, "EUR": 1.08]
    ) {
        self.schemaVersion = schemaVersion
        self.resources = resources
        self.roles = roles
        self.teams = teams
        self.plans = plans
        self.displayCurrency = displayCurrency
        self.conversionRates = conversionRates
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        resources = try container.decode([Resource].self, forKey: .resources)
        roles = try container.decode([Role].self, forKey: .roles)
        teams = try container.decodeIfPresent([Team].self, forKey: .teams) ?? []
        plans = try container.decode([Plan].self, forKey: .plans)
        displayCurrency = try container.decodeIfPresent(String.self, forKey: .displayCurrency) ?? "USD"
        conversionRates = try container.decodeIfPresent([String: Double].self, forKey: .conversionRates)
            ?? ["USD": 1.0, "CAD": 0.73, "EUR": 1.08]
    }

    public nonisolated func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public nonisolated static func decoded(from data: Data) throws -> PlannerDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PlannerDocument.self, from: data)
    }

    /// Index of the baseline plan, creating it if needed.
    public var baselinePlanIndex: Int {
        mutating get {
            if let idx = plans.firstIndex(where: { $0.name == "Baseline" }) {
                return idx
            }
            plans.append(Plan(name: "Baseline"))
            return plans.count - 1
        }
    }
}
