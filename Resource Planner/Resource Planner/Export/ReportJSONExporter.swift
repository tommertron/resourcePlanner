import Foundation

enum ReportJSONExporter {

    // MARK: - Report-level export

    struct ReportSnapshot: Codable {
        let generatedAt: Date
        let planName: String
        let displayCurrency: String
        let costByInitiative: [InitiativeRow]
        let committedVsPlaceholder: [CommittedPlaceholderRow]
        let resourceAllocation: [RoleAllocationRow]
        let remainingCapacity: [RoleCapacityRow]
    }

    struct InitiativeRow: Codable {
        let name: String
        let costByYear: [String: Double]
        let totalCost: Double
        let roleBreakdown: [RoleCostRow]
        let otherCosts: Double
    }

    struct RoleCostRow: Codable {
        let roleName: String
        let costByYear: [String: Double]
        let totalCost: Double
    }

    struct CommittedPlaceholderRow: Codable {
        let initiativeName: String
        let committed: Double
        let placeholder: Double
        let total: Double
    }

    struct RoleAllocationRow: Codable {
        let roleName: String
        let totalCost: Double
        let resources: [ResourceAllocationRow]
    }

    struct ResourceAllocationRow: Codable {
        let resourceName: String
        let employmentType: String
        let totalCost: Double
        let assignments: [AssignmentRow]
    }

    struct AssignmentRow: Codable {
        let initiativeName: String
        let avgPercent: Double
        let cost: Double
        let costByYear: [String: Double]
    }

    struct RoleCapacityRow: Codable {
        let roleName: String
        let resources: [ResourceCapacity]
    }

    struct ResourceCapacity: Codable {
        let name: String
        let remainingPercent: Double
        let remainingAnnualCost: Double
    }

    static func exportReport(plan: Plan, resources: [Resource], roles: [Role], displayCurrency: String = "USD", conversionRates: [String: Double] = ["USD": 1.0]) -> Data {
        let ctx = ReportData.CurrencyContext(displayCurrency: displayCurrency, conversionRates: conversionRates)
        let years = ReportData.allActiveYears(plan: plan)

        // Cost by initiative
        let costByInit = plan.initiatives.map { initiative -> InitiativeRow in
            let yearly = ReportData.initiativeYearlyCosts(initiative: initiative, plan: plan, resources: resources, currencyContext: ctx)
            let otherByYear = ReportData.otherCostsByYear(initiative: initiative, currencyContext: ctx)
            let otherTotal = ReportData.otherCostsTotal(initiative: initiative, currencyContext: ctx)
            let roleCosts = ReportData.initiativeCostByRole(initiative: initiative, plan: plan, resources: resources, roles: roles, currencyContext: ctx)

            var yearCosts: [String: Double] = [:]
            for year in years {
                yearCosts[String(year)] = (yearly[year]?.total ?? 0) + (otherByYear[year] ?? 0)
            }
            let peopleTotal = yearly.values.reduce(0) { $0 + $1.total }

            return InitiativeRow(
                name: initiative.name.isEmpty ? "Untitled" : initiative.name,
                costByYear: yearCosts,
                totalCost: peopleTotal + otherTotal,
                roleBreakdown: roleCosts.map { rc in
                    RoleCostRow(
                        roleName: rc.roleName,
                        costByYear: rc.costByYear.reduce(into: [:]) { $0[String($1.key)] = $1.value },
                        totalCost: rc.totalCost
                    )
                },
                otherCosts: otherTotal
            )
        }

        // Committed vs placeholder
        let cvp = plan.initiatives.map { initiative -> CommittedPlaceholderRow in
            let yearly = ReportData.initiativeYearlyCosts(initiative: initiative, plan: plan, resources: resources, currencyContext: ctx)
            let otherTotal = ReportData.otherCostsTotal(initiative: initiative, currencyContext: ctx)
            let committed = yearly.values.reduce(0) { $0 + $1.committed } + otherTotal
            let placeholder = yearly.values.reduce(0) { $0 + $1.placeholder }
            return CommittedPlaceholderRow(
                initiativeName: initiative.name.isEmpty ? "Untitled" : initiative.name,
                committed: committed, placeholder: placeholder, total: committed + placeholder
            )
        }

        // Resource allocation
        let allocEntries = ReportData.resourceAllocationByRole(plan: plan, resources: resources, roles: roles, currencyContext: ctx)
        let alloc = allocEntries.map { roleEntry -> RoleAllocationRow in
            RoleAllocationRow(
                roleName: roleEntry.roleName,
                totalCost: roleEntry.totalCost,
                resources: roleEntry.resources.map { re in
                    ResourceAllocationRow(
                        resourceName: re.name,
                        employmentType: re.employmentType.rawValue,
                        totalCost: re.totalCost,
                        assignments: re.assignments.map { a in
                            AssignmentRow(
                                initiativeName: a.initiativeName,
                                avgPercent: a.avgPercent,
                                cost: a.cost,
                                costByYear: a.costByYear.reduce(into: [:]) { $0[String($1.key)] = $1.value }
                            )
                        }
                    )
                }
            )
        }

        // Remaining capacity
        let capEntries = ReportData.remainingCapacityByRole(plan: plan, resources: resources, roles: roles, currencyContext: ctx)
        let cap = capEntries.map { roleEntry -> RoleCapacityRow in
            RoleCapacityRow(
                roleName: roleEntry.roleName,
                resources: roleEntry.resources.map { r in
                    ResourceCapacity(name: r.name, remainingPercent: r.remainingPercent, remainingAnnualCost: r.remainingMonthlyCost * 12)
                }
            )
        }

        let snapshot = ReportSnapshot(
            generatedAt: Date(),
            planName: plan.name,
            displayCurrency: displayCurrency,
            costByInitiative: costByInit,
            committedVsPlaceholder: cvp,
            resourceAllocation: alloc,
            remainingCapacity: cap
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(snapshot)) ?? Data()
    }

    // MARK: - Initiative-level export

    struct InitiativeSnapshot: Codable {
        let generatedAt: Date
        let initiativeName: String
        let notes: String
        let totalCost: Double
        let expectedReturn: Double
        let netReturn: Double
        let roi: Double?
        let costByRole: [RoleCostRow]
        let assignedResources: [AssignedResourceRow]
        let otherCosts: [OtherCostExport]
        let costByYear: [String: Double]
    }

    struct AssignedResourceRow: Codable {
        let name: String
        let employmentType: String
        let avgAllocation: Double
        let totalCost: Double
        let costByYear: [String: Double]
    }

    struct OtherCostExport: Codable {
        let name: String
        let totalAmount: Double
        let months: Int
        let monthlyCost: Double
    }

    static func exportInitiative(initiative: Initiative, plan: Plan, resources: [Resource], roles: [Role], displayCurrency: String = "USD", conversionRates: [String: Double] = ["USD": 1.0]) -> Data {
        let ctx = ReportData.CurrencyContext(displayCurrency: displayCurrency, conversionRates: conversionRates)
        let breakdown = ReportData.resourceBreakdown(initiative: initiative, plan: plan, resources: resources, currencyContext: ctx)
        let roleCosts = ReportData.initiativeCostByRole(initiative: initiative, plan: plan, resources: resources, roles: roles, currencyContext: ctx)
        let otherTotal = ReportData.otherCostsTotal(initiative: initiative, currencyContext: ctx)
        let peopleCost = breakdown.reduce(0) { $0 + $1.totalCost }
        let totalCost = peopleCost + otherTotal
        let years = ReportData.allActiveYears(plan: plan)

        let totalReturn = ReportData.expectedReturnsTotal(initiative: initiative, currencyContext: ctx)
        let netReturn = totalReturn - totalCost
        let roi: Double? = totalReturn > 0 && totalCost > 0
            ? (netReturn / totalCost) * 100
            : nil

        var yearCosts: [String: Double] = [:]
        let otherByYear = ReportData.otherCostsByYear(initiative: initiative, currencyContext: ctx)
        for year in years {
            let peopleCostYear = breakdown.reduce(0.0) { $0 + ($1.costByYear[year] ?? 0) }
            yearCosts[String(year)] = peopleCostYear + (otherByYear[year] ?? 0)
        }

        let snapshot = InitiativeSnapshot(
            generatedAt: Date(),
            initiativeName: initiative.name.isEmpty ? "Untitled" : initiative.name,
            notes: initiative.notes,
            totalCost: totalCost,
            expectedReturn: totalReturn,
            netReturn: netReturn,
            roi: roi,
            costByRole: roleCosts.map { rc in
                RoleCostRow(
                    roleName: rc.roleName,
                    costByYear: rc.costByYear.reduce(into: [:]) { $0[String($1.key)] = $1.value },
                    totalCost: rc.totalCost
                )
            },
            assignedResources: breakdown.map { entry in
                AssignedResourceRow(
                    name: entry.name,
                    employmentType: entry.employmentType.rawValue,
                    avgAllocation: entry.avgAllocation,
                    totalCost: entry.totalCost,
                    costByYear: entry.costByYear.reduce(into: [:]) { $0[String($1.key)] = $1.value }
                )
            },
            otherCosts: initiative.otherCosts.map { cost in
                OtherCostExport(
                    name: cost.name,
                    totalAmount: cost.totalAmount,
                    months: cost.monthKeys.count,
                    monthlyCost: cost.monthlyCost
                )
            },
            costByYear: yearCosts
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(snapshot)) ?? Data()
    }
}
