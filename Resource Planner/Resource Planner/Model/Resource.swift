import Foundation

nonisolated public enum RateBasis: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case hourly, monthly, annual
    public var id: String { rawValue }
}

nonisolated public enum EmploymentType: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case fullTime, contractor, placeholder
    public var id: String { rawValue }
}

/// A team that resources belong to. Document-wide, like Role. Roles may declare a default team
/// which is adopted by a resource when the role is assigned (gated by `Resource.isCustomTeam`).
nonisolated public struct Team: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var color: InitiativeColor
    public var icon: String

    public init(
        id: UUID = UUID(),
        name: String,
        color: InitiativeColor = .teal,
        icon: String = "person.3.fill"
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        color = try c.decodeIfPresent(InitiativeColor.self, forKey: .color) ?? .teal
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "person.3.fill"
    }
}

nonisolated public struct Role: Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var defaultRate: Double
    public var defaultRateBasis: RateBasis
    public var defaultHoursPerWeek: Double
    public var currencyCode: String
    public var defaultTeamID: UUID?

    public init(
        id: UUID = UUID(),
        name: String,
        defaultRate: Double = 0,
        defaultRateBasis: RateBasis = .annual,
        defaultHoursPerWeek: Double = 40,
        currencyCode: String = "USD",
        defaultTeamID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.defaultRate = defaultRate
        self.defaultRateBasis = defaultRateBasis
        self.defaultHoursPerWeek = defaultHoursPerWeek
        self.currencyCode = currencyCode
        self.defaultTeamID = defaultTeamID
    }
}

extension Role: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, defaultRate, defaultRateBasis, defaultHoursPerWeek, currencyCode, defaultTeamID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        defaultRate = try container.decode(Double.self, forKey: .defaultRate)
        defaultRateBasis = try container.decode(RateBasis.self, forKey: .defaultRateBasis)
        defaultHoursPerWeek = try container.decode(Double.self, forKey: .defaultHoursPerWeek)
        currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode) ?? "USD"
        defaultTeamID = try container.decodeIfPresent(UUID.self, forKey: .defaultTeamID)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(defaultRate, forKey: .defaultRate)
        try c.encode(defaultRateBasis, forKey: .defaultRateBasis)
        try c.encode(defaultHoursPerWeek, forKey: .defaultHoursPerWeek)
        try c.encode(currencyCode, forKey: .currencyCode)
        try c.encodeIfPresent(defaultTeamID, forKey: .defaultTeamID)
    }

    /// Cost per month implied by the role's defaults (matches Resource.monthlyCost math).
    public var defaultMonthlyCost: Double {
        switch defaultRateBasis {
        case .annual:  return defaultRate / 12.0
        case .monthly: return defaultRate
        case .hourly:  return defaultRate * defaultHoursPerWeek * (52.0 / 12.0)
        }
    }
}

nonisolated public struct Resource: Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var roleID: UUID?
    public var employmentType: EmploymentType
    public var rate: Double
    public var rateBasis: RateBasis
    public var hoursPerWeek: Double
    /// True if the user has explicitly set this resource's rate so it shouldn't be auto-overwritten by a role default.
    public var isCustomRate: Bool
    public var currencyCode: String
    public var teamID: UUID?
    /// True if the user has explicitly set this resource's team so it shouldn't be auto-overwritten by a role default.
    public var isCustomTeam: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        roleID: UUID? = nil,
        employmentType: EmploymentType = .fullTime,
        rate: Double = 0,
        rateBasis: RateBasis = .annual,
        hoursPerWeek: Double = 40,
        isCustomRate: Bool = false,
        currencyCode: String = "USD",
        teamID: UUID? = nil,
        isCustomTeam: Bool = false
    ) {
        self.id = id
        self.name = name
        self.roleID = roleID
        self.employmentType = employmentType
        self.rate = rate
        self.rateBasis = rateBasis
        self.hoursPerWeek = hoursPerWeek
        self.isCustomRate = isCustomRate
        self.currencyCode = currencyCode
        self.teamID = teamID
        self.isCustomTeam = isCustomTeam
    }
}

extension Resource: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, roleID, employmentType, rate, rateBasis, hoursPerWeek, isCustomRate, currencyCode
        case teamID, isCustomTeam
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        roleID = try container.decodeIfPresent(UUID.self, forKey: .roleID)
        employmentType = try container.decode(EmploymentType.self, forKey: .employmentType)
        rate = try container.decode(Double.self, forKey: .rate)
        rateBasis = try container.decode(RateBasis.self, forKey: .rateBasis)
        hoursPerWeek = try container.decode(Double.self, forKey: .hoursPerWeek)
        isCustomRate = try container.decode(Bool.self, forKey: .isCustomRate)
        currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode) ?? "USD"
        teamID = try container.decodeIfPresent(UUID.self, forKey: .teamID)
        isCustomTeam = try container.decodeIfPresent(Bool.self, forKey: .isCustomTeam) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(roleID, forKey: .roleID)
        try c.encode(employmentType, forKey: .employmentType)
        try c.encode(rate, forKey: .rate)
        try c.encode(rateBasis, forKey: .rateBasis)
        try c.encode(hoursPerWeek, forKey: .hoursPerWeek)
        try c.encode(isCustomRate, forKey: .isCustomRate)
        try c.encode(currencyCode, forKey: .currencyCode)
        try c.encodeIfPresent(teamID, forKey: .teamID)
        try c.encode(isCustomTeam, forKey: .isCustomTeam)
    }

    /// Cost per month for 100% allocation, normalized across rate bases.
    public var monthlyCost: Double {
        switch rateBasis {
        case .annual:  return rate / 12.0
        case .monthly: return rate
        case .hourly:  return rate * hoursPerWeek * (52.0 / 12.0)
        }
    }

    /// Whether this resource's compensation matches its role's default (within rounding).
    /// Returns true when there's no role assigned (nothing to reconcile against).
    public func matchesRoleDefault(_ role: Role?) -> Bool {
        guard let role else { return true }
        return rateBasis == role.defaultRateBasis &&
               abs(rate - role.defaultRate) < 0.005 &&
               abs(hoursPerWeek - role.defaultHoursPerWeek) < 0.005 &&
               currencyCode == role.currencyCode
    }

    /// Copy the role's default rate fields into this resource and mark non-custom.
    public mutating func adoptRoleDefaults(_ role: Role) {
        rate = role.defaultRate
        rateBasis = role.defaultRateBasis
        hoursPerWeek = role.defaultHoursPerWeek
        currencyCode = role.currencyCode
        isCustomRate = false
    }

    /// Adopt the role's default team for this resource (only if not custom).
    /// Caller is responsible for checking `isCustomTeam` before calling.
    public mutating func adoptRoleTeamDefault(_ role: Role) {
        teamID = role.defaultTeamID
        isCustomTeam = false
    }
}
