import Foundation

/// ISO year-week identifier (e.g. 2026-W18).
nonisolated public struct WeekKey: Hashable, Codable, Comparable, CustomStringConvertible, CodingKeyRepresentable, Sendable {
    public let year: Int
    public let week: Int

    public init(year: Int, week: Int) {
        self.year = year
        self.week = week
    }

    public var description: String { String(format: "%04d-W%02d", year, week) }

    public static func < (lhs: WeekKey, rhs: WeekKey) -> Bool {
        (lhs.year, lhs.week) < (rhs.year, rhs.week)
    }

    public static func from(date: Date, calendar: Calendar = .iso8601UTC) -> WeekKey {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return WeekKey(year: comps.yearForWeekOfYear ?? 0, week: comps.weekOfYear ?? 0)
    }

    public func startDate(calendar: Calendar = .iso8601UTC) -> Date {
        var comps = DateComponents()
        comps.yearForWeekOfYear = year
        comps.weekOfYear = week
        comps.weekday = calendar.firstWeekday
        return calendar.date(from: comps) ?? .distantPast
    }

    // CodingKeyRepresentable: encodes dict keys as "YYYY-Www"
    public init?<T>(codingKey: T) where T: CodingKey {
        let s = codingKey.stringValue
        guard let dash = s.firstIndex(of: "-"),
              s.distance(from: dash, to: s.endIndex) >= 2,
              s[s.index(after: dash)] == "W",
              let y = Int(s[..<dash]),
              let w = Int(s[s.index(dash, offsetBy: 2)...]) else { return nil }
        self.init(year: y, week: w)
    }

    public var codingKey: CodingKey { StringCodingKey(description) }
}

/// Year-month identifier (e.g. 2026-06).
nonisolated public struct MonthKey: Hashable, Codable, Comparable, CustomStringConvertible, CodingKeyRepresentable, Sendable {
    public let year: Int
    public let month: Int

    public init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    public var description: String { String(format: "%04d-%02d", year, month) }

    public static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }

    public static func from(date: Date, calendar: Calendar = .gregorianUTC) -> MonthKey {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return MonthKey(year: comps.year ?? 0, month: comps.month ?? 0)
    }

    /// Every ISO week whose Monday (start) falls within this calendar month.
    public func weeksInMonth(calendar: Calendar = .gregorianUTC, isoCalendar: Calendar = .iso8601UTC) -> [WeekKey] {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let first = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: first) else { return [] }
        var keys: [WeekKey] = []
        var seen = Set<WeekKey>()
        for day in range {
            comps.day = day
            guard let d = calendar.date(from: comps) else { continue }
            let key = WeekKey.from(date: d, calendar: isoCalendar)
            guard seen.insert(key).inserted else { continue }
            // Only include this week if its Monday falls within this month
            let monday = key.startDate(calendar: isoCalendar)
            let mondayComps = calendar.dateComponents([.year, .month], from: monday)
            if mondayComps.year == year && mondayComps.month == month {
                keys.append(key)
            }
        }
        return keys
    }

    public init?<T>(codingKey: T) where T: CodingKey {
        let s = codingKey.stringValue
        let parts = s.split(separator: "-")
        guard parts.count == 2, let y = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        self.init(year: y, month: m)
    }

    public var codingKey: CodingKey { StringCodingKey(description) }
}

nonisolated struct StringCodingKey: CodingKey, Sendable {
    var stringValue: String
    var intValue: Int? { Int(stringValue) }
    init(_ s: String) { self.stringValue = s }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { self.stringValue = String(intValue) }
}

extension Calendar {
    public nonisolated static var iso8601UTC: Calendar {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        c.minimumDaysInFirstWeek = 4
        c.firstWeekday = 2 // Monday
        return c
    }

    public nonisolated static var gregorianUTC: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return c
    }
}
