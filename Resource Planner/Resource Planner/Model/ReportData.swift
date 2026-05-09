import Foundation

// MARK: - Shared report computation helpers
// Extracted from ReportsView and InitiativeDetailView so both views and exporters share one source of truth.

enum ReportData {

    // MARK: - Currency context

    struct CurrencyContext {
        let displayCurrency: String
        let conversionRates: [String: Double]

        /// Convert an amount from a source currency to the display currency.
        func convert(_ amount: Double, from sourceCurrency: String) -> Double {
            let rate = conversionRates[sourceCurrency] ?? 1.0
            return amount * rate
        }

        /// Identity context — no conversion (all amounts treated as display currency).
        static let identity = CurrencyContext(displayCurrency: "USD", conversionRates: ["USD": 1.0])
    }

    // MARK: - Result types

    struct CostSplit {
        var committed: Double = 0
        var placeholder: Double = 0
        var total: Double { committed + placeholder }
    }

    struct ResourceCostEntry: Identifiable {
        let id: UUID
        let name: String
        let employmentType: EmploymentType
        let avgAllocation: Double
        let totalCost: Double
        let costByYear: [Int: Double]
    }

    struct RoleCostEntry: Identifiable {
        let id: UUID
        let roleName: String
        let costByYear: [Int: Double]
        var totalCost: Double { costByYear.values.reduce(0, +) }
    }

    struct RoleCapacityEntry: Identifiable {
        let id: UUID
        let roleName: String
        let resources: [ResourceCapacityEntry]
        var totalRemainingMonthlyCost: Double { resources.reduce(0) { $0 + $1.remainingMonthlyCost } }
    }

    struct ResourceCapacityEntry: Identifiable {
        let id: UUID
        let name: String
        let avgAllocation: Double
        let remainingPercent: Double
        let monthlyCost: Double
        var remainingMonthlyCost: Double { monthlyCost * max(remainingPercent, 0) }
    }

    struct RoleAllocationEntry: Identifiable {
        let id: UUID
        let roleName: String
        let resources: [ResourceAllocationRoleEntry]
        var totalCost: Double { resources.reduce(0) { $0 + $1.totalCost } }
        func costForYear(_ year: Int) -> Double { resources.reduce(0) { $0 + $1.costForYear(year) } }
    }

    struct ResourceAllocationRoleEntry: Identifiable {
        let id: UUID
        let name: String
        let employmentType: EmploymentType
        let assignments: [ResourceAssignmentEntry]
        var totalCost: Double { assignments.reduce(0) { $0 + $1.cost } }
        func costForYear(_ year: Int) -> Double { assignments.reduce(0) { $0 + ($1.costByYear[year] ?? 0) } }
    }

    struct ResourceAssignmentEntry: Identifiable {
        let id: UUID
        let initiativeName: String
        let color: InitiativeColor
        let avgPercent: Double
        let cost: Double
        let costByYear: [Int: Double]
    }

    // MARK: - Month / year helpers

    /// All MonthKeys that have any allocation data across the entire plan.
    static func allActiveMonths(plan: Plan) -> [MonthKey] {
        var keys = Set<MonthKey>()
        for assignment in plan.assignments {
            for allocation in assignment.allocations {
                for mk in allocation.months.keys where (allocation.months[mk] ?? 0) > 0 {
                    keys.insert(mk)
                }
            }
        }
        return keys.sorted()
    }

    /// All years that have allocation data (including other costs).
    static func allActiveYears(plan: Plan) -> [Int] {
        var yearSet = Set(allActiveMonths(plan: plan).map(\.year))
        for initiative in plan.initiatives {
            for cost in initiative.otherCosts {
                for mk in cost.monthKeys { yearSet.insert(mk.year) }
            }
        }
        return yearSet.sorted()
    }

    // MARK: - Other costs helpers

    /// Total other costs for an initiative, bucketed by year.
    static func otherCostsByYear(initiative: Initiative, currencyContext: CurrencyContext = .identity) -> [Int: Double] {
        var result: [Int: Double] = [:]
        for cost in initiative.otherCosts {
            for (year, amount) in cost.costByYear {
                result[year, default: 0] += currencyContext.convert(amount, from: cost.currencyCode)
            }
        }
        return result
    }

    /// Total of all other costs for an initiative.
    static func otherCostsTotal(initiative: Initiative, currencyContext: CurrencyContext = .identity) -> Double {
        initiative.otherCosts.reduce(0) { $0 + currencyContext.convert($1.totalAmount, from: $1.currencyCode) }
    }

    // MARK: - Expected returns helpers

    /// Expected returns bucketed by year.
    static func expectedReturnsByYear(initiative: Initiative, currencyContext: CurrencyContext = .identity) -> [Int: Double] {
        var result: [Int: Double] = [:]
        for ret in initiative.expectedReturns {
            for (year, amount) in ret.returnByYear {
                result[year, default: 0] += currencyContext.convert(amount, from: ret.currencyCode)
            }
        }
        return result
    }

    /// Total of all expected returns for an initiative.
    static func expectedReturnsTotal(initiative: Initiative, currencyContext: CurrencyContext = .identity) -> Double {
        initiative.expectedReturns.reduce(0) { $0 + currencyContext.convert($1.totalAmount, from: $1.currencyCode) }
    }

    // MARK: - Cost computation

    /// Cost for a single initiative in a single month, split by resource type.
    static func initiativeMonthlyCost(
        initiative: Initiative,
        plan: Plan,
        resources: [Resource],
        month: MonthKey,
        excludedResourceIDs: Set<UUID> = [],
        currencyContext: CurrencyContext = .identity
    ) -> CostSplit {
        var split = CostSplit()
        let assignments = plan.assignments.filter { $0.initiativeID == initiative.id }
        for assignment in assignments {
            for allocation in assignment.allocations {
                guard !excludedResourceIDs.contains(allocation.resourceID) else { continue }
                guard let resource = resources.first(where: { $0.id == allocation.resourceID }) else { continue }
                let percent = allocation.months[month] ?? 0
                guard percent > 0 else { continue }
                let cost = currencyContext.convert(resource.monthlyCost * percent, from: resource.currencyCode)
                if resource.employmentType == .placeholder {
                    split.placeholder += cost
                } else {
                    split.committed += cost
                }
            }
        }
        return split
    }

    /// Yearly cost for a single initiative, split by committed/placeholder.
    static func initiativeYearlyCosts(
        initiative: Initiative,
        plan: Plan,
        resources: [Resource],
        excludedResourceIDs: Set<UUID> = [],
        currencyContext: CurrencyContext = .identity
    ) -> [Int: CostSplit] {
        let months = allActiveMonths(plan: plan)
        var byYear: [Int: CostSplit] = [:]
        for mk in months {
            let split = initiativeMonthlyCost(
                initiative: initiative, plan: plan, resources: resources,
                month: mk, excludedResourceIDs: excludedResourceIDs,
                currencyContext: currencyContext
            )
            var existing = byYear[mk.year] ?? CostSplit()
            existing.committed += split.committed
            existing.placeholder += split.placeholder
            byYear[mk.year] = existing
        }
        return byYear
    }

    /// Per-resource cost breakdown for a single initiative across all active months.
    static func resourceBreakdown(initiative: Initiative, plan: Plan, resources: [Resource], currencyContext: CurrencyContext = .identity) -> [ResourceCostEntry] {
        let assignments = plan.assignments.filter { $0.initiativeID == initiative.id }
        let months = allActiveMonths(plan: plan)
        guard !months.isEmpty else { return [] }

        var costByResource: [UUID: Double] = [:]
        var yearCostByResource: [UUID: [Int: Double]] = [:]
        var allocByResource: [UUID: [Double]] = [:]
        for assignment in assignments {
            for allocation in assignment.allocations {
                for mk in months {
                    let pct = allocation.months[mk] ?? 0
                    guard pct > 0 else { continue }
                    guard let resource = resources.first(where: { $0.id == allocation.resourceID }) else { continue }
                    let cost = currencyContext.convert(resource.monthlyCost * pct, from: resource.currencyCode)
                    costByResource[resource.id, default: 0] += cost
                    yearCostByResource[resource.id, default: [:]][mk.year, default: 0] += cost
                    allocByResource[resource.id, default: []].append(pct)
                }
            }
        }

        return costByResource.compactMap { (rid, cost) in
            guard let resource = resources.first(where: { $0.id == rid }) else { return nil }
            let allocs = allocByResource[rid] ?? []
            let avg = allocs.isEmpty ? 0 : allocs.reduce(0, +) / Double(allocs.count)
            return ResourceCostEntry(
                id: rid, name: resource.name, employmentType: resource.employmentType,
                avgAllocation: avg, totalCost: cost, costByYear: yearCostByResource[rid] ?? [:]
            )
        }.sorted { $0.totalCost > $1.totalCost }
    }

    /// Per-role cost breakdown for an initiative, with yearly buckets.
    static func initiativeCostByRole(initiative: Initiative, plan: Plan, resources: [Resource], roles: [Role], currencyContext: CurrencyContext = .identity) -> [RoleCostEntry] {
        let noRoleID = UUID(uuidString: "00000000-0000-0000-0000-FFFFFFFFFFFF")!
        let months = allActiveMonths(plan: plan)
        guard !months.isEmpty else { return [] }

        let assignments = plan.assignments.filter { $0.initiativeID == initiative.id }
        var byRoleYear: [UUID: [Int: Double]] = [:]
        for assignment in assignments {
            for allocation in assignment.allocations {
                guard let resource = resources.first(where: { $0.id == allocation.resourceID }) else { continue }
                let roleKey = resource.roleID ?? noRoleID
                for mk in months {
                    let pct = allocation.months[mk] ?? 0
                    guard pct > 0 else { continue }
                    byRoleYear[roleKey, default: [:]][mk.year, default: 0] += currencyContext.convert(resource.monthlyCost * pct, from: resource.currencyCode)
                }
            }
        }

        return byRoleYear.map { (roleID, yearCosts) in
            let name: String
            if roleID == noRoleID {
                name = "No Role"
            } else {
                name = roles.first(where: { $0.id == roleID })?.name ?? "Unknown Role"
            }
            return RoleCostEntry(id: roleID, roleName: name, costByYear: yearCosts)
        }.sorted { $0.totalCost > $1.totalCost }
    }

    /// All placeholder resources that have any allocations in the plan.
    static func placeholderResourcesInPlan(plan: Plan, resources: [Resource]) -> [Resource] {
        var ids = Set<UUID>()
        for assignment in plan.assignments {
            for allocation in assignment.allocations {
                if (allocation.months.values.first(where: { $0 > 0 }) != nil) {
                    ids.insert(allocation.resourceID)
                }
            }
        }
        return resources
            .filter { $0.employmentType == .placeholder && ids.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Remaining capacity per role.
    static func remainingCapacityByRole(plan: Plan, resources: [Resource], roles: [Role], currencyContext: CurrencyContext = .identity) -> [RoleCapacityEntry] {
        let months = allActiveMonths(plan: plan)
        guard !months.isEmpty else { return [] }
        let noRoleID = UUID(uuidString: "00000000-0000-0000-0000-FFFFFFFFFFFF")!

        var totalAllocByResource: [UUID: Double] = [:]
        for mk in months {
            for assignment in plan.assignments {
                for allocation in assignment.allocations {
                    let pct = allocation.months[mk] ?? 0
                    totalAllocByResource[allocation.resourceID, default: 0] += pct
                }
            }
        }

        var byRole: [UUID: [ResourceCapacityEntry]] = [:]
        for resource in resources {
            let totalAlloc = totalAllocByResource[resource.id] ?? 0
            let avgAlloc = totalAlloc / Double(months.count)
            let remaining = max(1.0 - avgAlloc, 0)
            guard remaining > 0.005 else { continue }
            let entry = ResourceCapacityEntry(
                id: resource.id, name: resource.name,
                avgAllocation: avgAlloc, remainingPercent: remaining,
                monthlyCost: currencyContext.convert(resource.monthlyCost, from: resource.currencyCode)
            )
            let key = resource.roleID ?? noRoleID
            byRole[key, default: []].append(entry)
        }

        return byRole.map { (roleID, entries) in
            let roleName: String
            if roleID == noRoleID {
                roleName = "No Role"
            } else {
                roleName = roles.first(where: { $0.id == roleID })?.name ?? "Unknown Role"
            }
            return RoleCapacityEntry(
                id: roleID, roleName: roleName,
                resources: entries.sorted { $0.remainingMonthlyCost > $1.remainingMonthlyCost }
            )
        }.sorted { $0.totalRemainingMonthlyCost > $1.totalRemainingMonthlyCost }
    }

    /// Resource allocation grouped by role.
    static func resourceAllocationByRole(plan: Plan, resources: [Resource], roles: [Role], currencyContext: CurrencyContext = .identity) -> [RoleAllocationEntry] {
        let noRoleID = UUID(uuidString: "00000000-0000-0000-0000-FFFFFFFFFFFF")!
        let months = allActiveMonths(plan: plan)
        guard !months.isEmpty else { return [] }

        var resourceAssignments: [UUID: [ResourceAssignmentEntry]] = [:]
        for initiative in plan.initiatives {
            let assignments = plan.assignments.filter { $0.initiativeID == initiative.id }
            for assignment in assignments {
                for allocation in assignment.allocations {
                    guard let resource = resources.first(where: { $0.id == allocation.resourceID }) else { continue }
                    var totalPct = 0.0
                    var activePctMonths = 0
                    var cost = 0.0
                    var yearCosts: [Int: Double] = [:]
                    for mk in months {
                        let pct = allocation.months[mk] ?? 0
                        if pct > 0 {
                            totalPct += pct
                            activePctMonths += 1
                            let monthlyCost = currencyContext.convert(resource.monthlyCost * pct, from: resource.currencyCode)
                            cost += monthlyCost
                            yearCosts[mk.year, default: 0] += monthlyCost
                        }
                    }
                    guard activePctMonths > 0 else { continue }
                    let avg = totalPct / Double(activePctMonths)
                    let entry = ResourceAssignmentEntry(
                        id: UUID(),
                        initiativeName: initiative.name.isEmpty ? "Untitled" : initiative.name,
                        color: initiative.color,
                        avgPercent: avg,
                        cost: cost,
                        costByYear: yearCosts
                    )
                    resourceAssignments[resource.id, default: []].append(entry)
                }
            }
        }

        var byRole: [UUID: [ResourceAllocationRoleEntry]] = [:]
        for resource in resources {
            guard let assignments = resourceAssignments[resource.id], !assignments.isEmpty else { continue }
            let roleKey = resource.roleID ?? noRoleID
            let entry = ResourceAllocationRoleEntry(
                id: resource.id, name: resource.name,
                employmentType: resource.employmentType,
                assignments: assignments.sorted { $0.cost > $1.cost }
            )
            byRole[roleKey, default: []].append(entry)
        }

        return byRole.map { (roleID, entries) in
            let name: String
            if roleID == noRoleID {
                name = "No Role"
            } else {
                name = roles.first(where: { $0.id == roleID })?.name ?? "Unknown Role"
            }
            return RoleAllocationEntry(
                id: roleID, roleName: name,
                resources: entries.sorted { $0.totalCost > $1.totalCost }
            )
        }.sorted { $0.totalCost > $1.totalCost }
    }

    // MARK: - Team rollups

    struct TeamBreakdownEntry: Identifiable {
        let id: UUID
        let name: String
        let color: InitiativeColor
        let icon: String
        let costByYear: [Int: Double]
        var totalCost: Double { costByYear.values.reduce(0, +) }
    }

    struct TeamRollup {
        let totalCost: Double
        let costByYear: [Int: Double]
        let byRole: [TeamBreakdownEntry]
        let byInitiative: [TeamBreakdownEntry]
        let byProgram: [TeamBreakdownEntry]
    }

    /// Aggregate plan costs filtered to resources on the given team.
    static func teamRollup(
        team: Team,
        plan: Plan,
        resources: [Resource],
        roles: [Role],
        currencyContext: CurrencyContext = .identity
    ) -> TeamRollup {
        let memberIDs = Set(resources.filter { $0.teamID == team.id }.map(\.id))
        let months = allActiveMonths(plan: plan)
        let noRoleID = UUID(uuidString: "00000000-0000-0000-0000-FFFFFFFFFFFF")!
        let noProgramID = UUID(uuidString: "00000000-0000-0000-0000-EEEEEEEEEEEE")!

        var byYear: [Int: Double] = [:]
        var byRoleYear: [UUID: [Int: Double]] = [:]
        var byInitYear: [UUID: [Int: Double]] = [:]
        var byProgramYear: [UUID: [Int: Double]] = [:]
        var total = 0.0

        guard !memberIDs.isEmpty, !months.isEmpty else {
            return TeamRollup(totalCost: 0, costByYear: [:], byRole: [], byInitiative: [], byProgram: [])
        }

        let resourceByID = Dictionary(uniqueKeysWithValues: resources.map { ($0.id, $0) })
        let initiativeByID = Dictionary(uniqueKeysWithValues: plan.initiatives.map { ($0.id, $0) })

        for assignment in plan.assignments {
            guard let initiative = initiativeByID[assignment.initiativeID] else { continue }
            for allocation in assignment.allocations where memberIDs.contains(allocation.resourceID) {
                guard let resource = resourceByID[allocation.resourceID] else { continue }
                let roleKey = resource.roleID ?? noRoleID
                let programKey = initiative.programID ?? noProgramID
                for mk in months {
                    let pct = allocation.months[mk] ?? 0
                    guard pct > 0 else { continue }
                    let cost = currencyContext.convert(resource.monthlyCost * pct, from: resource.currencyCode)
                    total += cost
                    byYear[mk.year, default: 0] += cost
                    byRoleYear[roleKey, default: [:]][mk.year, default: 0] += cost
                    byInitYear[initiative.id, default: [:]][mk.year, default: 0] += cost
                    byProgramYear[programKey, default: [:]][mk.year, default: 0] += cost
                }
            }
        }

        let rolesByID = Dictionary(uniqueKeysWithValues: roles.map { ($0.id, $0) })
        let programsByID = Dictionary(uniqueKeysWithValues: plan.programs.map { ($0.id, $0) })

        let byRoleEntries: [TeamBreakdownEntry] = byRoleYear.map { (rid, yc) in
            let name = rid == noRoleID ? "No Role" : (rolesByID[rid]?.name ?? "Unknown Role")
            return TeamBreakdownEntry(id: rid, name: name.isEmpty ? "Untitled role" : name,
                                      color: .purple, icon: "tag.fill", costByYear: yc)
        }.sorted { $0.totalCost > $1.totalCost }

        let byInitEntries: [TeamBreakdownEntry] = byInitYear.map { (iid, yc) in
            let init_ = initiativeByID[iid]
            return TeamBreakdownEntry(
                id: iid,
                name: (init_?.name.isEmpty == false ? init_!.name : "Untitled initiative"),
                color: init_?.color ?? .blue,
                icon: init_?.icon ?? "flag.fill",
                costByYear: yc
            )
        }.sorted { $0.totalCost > $1.totalCost }

        let byProgramEntries: [TeamBreakdownEntry] = byProgramYear.map { (pid, yc) in
            if pid == noProgramID {
                return TeamBreakdownEntry(id: pid, name: "(No Program)", color: .brown,
                                          icon: "questionmark.square.dashed", costByYear: yc)
            }
            let p = programsByID[pid]
            return TeamBreakdownEntry(
                id: pid,
                name: (p?.name.isEmpty == false ? p!.name : "Untitled program"),
                color: p?.color ?? .indigo,
                icon: p?.icon ?? "rectangle.stack.fill",
                costByYear: yc
            )
        }.sorted { $0.totalCost > $1.totalCost }

        return TeamRollup(totalCost: total, costByYear: byYear,
                          byRole: byRoleEntries, byInitiative: byInitEntries, byProgram: byProgramEntries)
    }

    // MARK: - Program rollups

    struct ProgramCostEntry: Identifiable {
        let id: UUID
        let name: String
        let color: InitiativeColor
        let icon: String
        let costByYear: [Int: Double]
        let initiativeCount: Int
        var totalCost: Double { costByYear.values.reduce(0, +) }
    }

    /// Yearly cost rollup for each program, summing all member-initiative costs (people + other costs).
    /// Includes a synthetic "(No Program)" entry for initiatives without a program if any exist.
    static func programYearlyCosts(plan: Plan, resources: [Resource], currencyContext: CurrencyContext = .identity) -> [ProgramCostEntry] {
        let noProgramID = UUID(uuidString: "00000000-0000-0000-0000-EEEEEEEEEEEE")!
        var byProgramYear: [UUID: [Int: Double]] = [:]
        var countByProgram: [UUID: Int] = [:]
        for initiative in plan.initiatives {
            let key = initiative.programID ?? noProgramID
            countByProgram[key, default: 0] += 1
            let yearly = initiativeYearlyCosts(initiative: initiative, plan: plan, resources: resources, currencyContext: currencyContext)
            for (year, split) in yearly {
                byProgramYear[key, default: [:]][year, default: 0] += split.total
            }
            for (year, amount) in otherCostsByYear(initiative: initiative, currencyContext: currencyContext) {
                byProgramYear[key, default: [:]][year, default: 0] += amount
            }
        }
        let programByID = Dictionary(uniqueKeysWithValues: plan.programs.map { ($0.id, $0) })
        return byProgramYear.compactMap { (programID, yearCosts) in
            if programID == noProgramID {
                guard (countByProgram[noProgramID] ?? 0) > 0 else { return nil }
                return ProgramCostEntry(
                    id: noProgramID, name: "(No Program)", color: .brown, icon: "questionmark.square.dashed",
                    costByYear: yearCosts, initiativeCount: countByProgram[noProgramID] ?? 0
                )
            }
            guard let program = programByID[programID] else { return nil }
            return ProgramCostEntry(
                id: program.id, name: program.name.isEmpty ? "Untitled Program" : program.name,
                color: program.color, icon: program.icon,
                costByYear: yearCosts, initiativeCount: countByProgram[programID] ?? 0
            )
        }.sorted { $0.totalCost > $1.totalCost }
    }

    /// Total plan cost across all initiatives.
    static func totalPlanCost(plan: Plan, resources: [Resource], excludedResourceIDs: Set<UUID> = [], currencyContext: CurrencyContext = .identity) -> Double {
        let months = allActiveMonths(plan: plan)
        var total = 0.0
        for initiative in plan.initiatives {
            for mk in months {
                let split = initiativeMonthlyCost(
                    initiative: initiative, plan: plan, resources: resources,
                    month: mk, excludedResourceIDs: excludedResourceIDs,
                    currencyContext: currencyContext
                )
                total += split.total
            }
            total += otherCostsTotal(initiative: initiative, currencyContext: currencyContext)
        }
        return total
    }
}
