import Foundation

nonisolated public enum InitiativeColor: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case blue, green, purple, orange, red, teal, pink, indigo, mint, brown
    public var id: String { rawValue }
}

/// A non-personnel cost attached to an initiative (e.g. consulting, licensing, travel).
/// The totalAmount is amortized evenly across all months from startDate to endDate.
nonisolated public struct OtherCost: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var startDate: Date
    public var endDate: Date
    public var totalAmount: Double
    public var currencyCode: String

    public init(
        id: UUID = UUID(),
        name: String = "",
        startDate: Date = Date(),
        endDate: Date = Date(),
        totalAmount: Double = 0,
        currencyCode: String = "USD"
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.totalAmount = totalAmount
        self.currencyCode = currencyCode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        totalAmount = try container.decode(Double.self, forKey: .totalAmount)
        currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode) ?? "USD"
    }

    /// The months spanned by this cost (inclusive of start and end months).
    public var monthKeys: [MonthKey] {
        let cal = Calendar.gregorianUTC
        let startMK = MonthKey.from(date: startDate, calendar: cal)
        let endMK = MonthKey.from(date: endDate, calendar: cal)
        guard startMK <= endMK else { return [] }

        var keys: [MonthKey] = []
        var current = startMK
        while current <= endMK {
            keys.append(current)
            // Advance one month
            let nextMonth = current.month == 12 ? 1 : current.month + 1
            let nextYear = current.month == 12 ? current.year + 1 : current.year
            current = MonthKey(year: nextYear, month: nextMonth)
        }
        return keys
    }

    /// Amortized cost per month (totalAmount / number of months).
    public var monthlyCost: Double {
        let count = monthKeys.count
        guard count > 0 else { return 0 }
        return totalAmount / Double(count)
    }

    /// Amortized cost bucketed by year.
    public var costByYear: [Int: Double] {
        let perMonth = monthlyCost
        var result: [Int: Double] = [:]
        for mk in monthKeys {
            result[mk.year, default: 0] += perMonth
        }
        return result
    }
}

/// A date-ranged expected return entry, modeled like OtherCost.
nonisolated public struct ExpectedReturn: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var startDate: Date
    public var endDate: Date
    public var totalAmount: Double
    public var currencyCode: String

    public init(
        id: UUID = UUID(),
        name: String = "",
        startDate: Date = Date(),
        endDate: Date = Date(),
        totalAmount: Double = 0,
        currencyCode: String = "USD"
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.totalAmount = totalAmount
        self.currencyCode = currencyCode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        totalAmount = try container.decode(Double.self, forKey: .totalAmount)
        currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode) ?? "USD"
    }

    /// The months spanned by this return (inclusive of start and end months).
    public var monthKeys: [MonthKey] {
        let cal = Calendar.gregorianUTC
        let startMK = MonthKey.from(date: startDate, calendar: cal)
        let endMK = MonthKey.from(date: endDate, calendar: cal)
        guard startMK <= endMK else { return [] }

        var keys: [MonthKey] = []
        var current = startMK
        while current <= endMK {
            keys.append(current)
            let nextMonth = current.month == 12 ? 1 : current.month + 1
            let nextYear = current.month == 12 ? current.year + 1 : current.year
            current = MonthKey(year: nextYear, month: nextMonth)
        }
        return keys
    }

    /// Amortized return per month.
    public var monthlyReturn: Double {
        let count = monthKeys.count
        guard count > 0 else { return 0 }
        return totalAmount / Double(count)
    }

    /// Amortized return bucketed by year.
    public var returnByYear: [Int: Double] {
        let perMonth = monthlyReturn
        var result: [Int: Double] = [:]
        for mk in monthKeys {
            result[mk.year, default: 0] += perMonth
        }
        return result
    }
}

/// A grouping above initiatives. Programs have their own date range; initiatives belonging to
/// a program inherit those dates on creation but can be edited independently afterwards.
nonisolated public struct Program: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var startDate: Date
    public var endDate: Date
    public var notes: String
    public var color: InitiativeColor
    public var icon: String

    public init(
        id: UUID = UUID(),
        name: String,
        startDate: Date,
        endDate: Date,
        notes: String = "",
        color: InitiativeColor = .indigo,
        icon: String = "rectangle.stack.fill"
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.color = color
        self.icon = icon
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        color = try container.decodeIfPresent(InitiativeColor.self, forKey: .color) ?? .indigo
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "rectangle.stack.fill"
    }
}

nonisolated public struct Initiative: Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var startDate: Date
    public var endDate: Date
    public var notes: String
    public var color: InitiativeColor
    public var icon: String
    public var otherCosts: [OtherCost]
    public var expectedReturns: [ExpectedReturn]
    /// Optional end of the investment evaluation window. If nil, defaults to initiative endDate.
    public var investmentWindowEnd: Date?
    /// Optional parent program. When set on creation the initiative inherits program dates;
    /// edits to the initiative's own dates after that point are independent.
    public var programID: UUID?

    public init(
        id: UUID = UUID(),
        name: String,
        startDate: Date,
        endDate: Date,
        notes: String = "",
        color: InitiativeColor = .blue,
        icon: String = "flag.fill",
        otherCosts: [OtherCost] = [],
        expectedReturns: [ExpectedReturn] = [],
        investmentWindowEnd: Date? = nil,
        programID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.color = color
        self.icon = icon
        self.otherCosts = otherCosts
        self.expectedReturns = expectedReturns
        self.investmentWindowEnd = investmentWindowEnd
        self.programID = programID
    }

    /// The effective end of the investment window for ROI/payback calculations.
    public var effectiveInvestmentWindowEnd: Date {
        investmentWindowEnd ?? endDate
    }
}

extension Initiative: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, startDate, endDate, notes, color, icon, otherCosts
        case expectedReturns, investmentWindowEnd, programID
        // Legacy key for migration
        case expectedReturn
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        color = try container.decodeIfPresent(InitiativeColor.self, forKey: .color) ?? .blue
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "flag.fill"
        otherCosts = try container.decodeIfPresent([OtherCost].self, forKey: .otherCosts) ?? []
        investmentWindowEnd = try container.decodeIfPresent(Date.self, forKey: .investmentWindowEnd)
        programID = try container.decodeIfPresent(UUID.self, forKey: .programID)

        // Migrate legacy scalar expectedReturn → expectedReturns array
        if let returns = try container.decodeIfPresent([ExpectedReturn].self, forKey: .expectedReturns) {
            expectedReturns = returns
        } else if let legacyReturn = try container.decodeIfPresent(Double.self, forKey: .expectedReturn), legacyReturn > 0 {
            expectedReturns = [ExpectedReturn(name: "Expected Return", startDate: startDate, endDate: endDate, totalAmount: legacyReturn)]
        } else {
            expectedReturns = []
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(notes, forKey: .notes)
        try container.encode(color, forKey: .color)
        try container.encode(icon, forKey: .icon)
        try container.encode(otherCosts, forKey: .otherCosts)
        try container.encode(expectedReturns, forKey: .expectedReturns)
        try container.encodeIfPresent(investmentWindowEnd, forKey: .investmentWindowEnd)
        try container.encodeIfPresent(programID, forKey: .programID)
    }
}

nonisolated public struct Allocation: Hashable, Identifiable, Sendable {
    public var id: UUID
    public var resourceID: UUID
    public var months: [MonthKey: Double]   // percent (0.0 ... 1.0+) per month

    public init(id: UUID = UUID(), resourceID: UUID, months: [MonthKey: Double] = [:]) {
        self.id = id
        self.resourceID = resourceID
        self.months = months
    }
}

// MARK: - Allocation Codable (with v1 migration)

extension Allocation: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, resourceID, months, weeks
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(resourceID, forKey: .resourceID)
        try container.encode(months, forKey: .months)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        resourceID = try container.decode(UUID.self, forKey: .resourceID)

        if let m = try container.decodeIfPresent([MonthKey: Double].self, forKey: .months) {
            months = m
        } else if let weekData = try container.decodeIfPresent([String: WeekEntryV1].self, forKey: .weeks) {
            // Migrate v1 weekly data: group weeks into months and average
            var monthTotals: [MonthKey: (sum: Double, count: Int)] = [:]
            let cal = Calendar.gregorianUTC
            for (keyStr, entry) in weekData {
                // Parse "YYYY-Www" week key to get its Monday date
                guard let dash = keyStr.firstIndex(of: "-"),
                      keyStr.distance(from: dash, to: keyStr.endIndex) >= 2,
                      keyStr[keyStr.index(after: dash)] == "W",
                      let y = Int(keyStr[..<dash]),
                      let w = Int(keyStr[keyStr.index(dash, offsetBy: 2)...]) else { continue }
                var comps = DateComponents()
                comps.yearForWeekOfYear = y
                comps.weekOfYear = w
                comps.weekday = 2 // Monday
                let isoCal = Calendar.iso8601UTC
                guard let monday = isoCal.date(from: comps) else { continue }
                let mk = MonthKey.from(date: monday, calendar: cal)
                let existing = monthTotals[mk] ?? (sum: 0, count: 0)
                monthTotals[mk] = (sum: existing.sum + entry.percent, count: existing.count + 1)
            }
            months = monthTotals.mapValues { $0.sum / Double($0.count) }
        } else {
            months = [:]
        }
    }
}

/// Minimal struct to decode old v1 WeekEntry for migration purposes.
nonisolated private struct WeekEntryV1: Codable, Sendable {
    var percent: Double
}

nonisolated public struct Assignment: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var initiativeID: UUID
    public var allocations: [Allocation]

    public init(id: UUID = UUID(), name: String, initiativeID: UUID, allocations: [Allocation] = []) {
        self.id = id
        self.name = name
        self.initiativeID = initiativeID
        self.allocations = allocations
    }
}

// MARK: - Plan helpers

extension Plan {
    /// Total allocation percentage for a resource in a single month, summed across all assignments.
    public func monthAllocation(for resourceID: UUID, in month: MonthKey) -> Double {
        var total = 0.0
        for assignment in assignments {
            for allocation in assignment.allocations where allocation.resourceID == resourceID {
                total += allocation.months[month] ?? 0
            }
        }
        return total
    }

    /// Average allocation percentage for a resource across a range of months.
    public func averageAllocation(for resourceID: UUID, in months: [MonthKey]) -> Double {
        guard !months.isEmpty else { return 0 }
        let total = months.reduce(0.0) { $0 + monthAllocation(for: resourceID, in: $1) }
        return total / Double(months.count)
    }
}

nonisolated public struct Plan: Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var notes: String
    public var programs: [Program]
    public var initiatives: [Initiative]
    public var assignments: [Assignment]

    public init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        programs: [Program] = [],
        initiatives: [Initiative] = [],
        assignments: [Assignment] = []
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.programs = programs
        self.initiatives = initiatives
        self.assignments = assignments
    }
}

extension Plan: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, notes, programs, initiatives, assignments
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        programs = try c.decodeIfPresent([Program].self, forKey: .programs) ?? []
        initiatives = try c.decode([Initiative].self, forKey: .initiatives)
        assignments = try c.decode([Assignment].self, forKey: .assignments)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(notes, forKey: .notes)
        try c.encode(programs, forKey: .programs)
        try c.encode(initiatives, forKey: .initiatives)
        try c.encode(assignments, forKey: .assignments)
    }
}
