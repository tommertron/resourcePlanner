import Foundation

enum ReportCSVExporter {

    // MARK: - Reports: Overview

    static func exportOverviewReport(plan: Plan, resources: [Resource], roles: [Role], displayCurrency: String = "USD", conversionRates: [String: Double] = ["USD": 1.0]) -> Data {
        let ctx = ReportData.CurrencyContext(displayCurrency: displayCurrency, conversionRates: conversionRates)
        var lines: [String] = []
        lines.append("Currency,\(displayCurrency)")
        let years = ReportData.allActiveYears(plan: plan)

        // Section 1: Cost by Initiative
        lines.append("Cost by Initiative")
        lines.append(csvRow(["Initiative"] + years.map(String.init) + ["Total"]))
        for initiative in plan.initiatives {
            let yearly = ReportData.initiativeYearlyCosts(initiative: initiative, plan: plan, resources: resources, currencyContext: ctx)
            let otherByYear = ReportData.otherCostsByYear(initiative: initiative, currencyContext: ctx)
            let otherTotal = ReportData.otherCostsTotal(initiative: initiative, currencyContext: ctx)
            let name = initiative.name.isEmpty ? "Untitled" : initiative.name
            var row = [name]
            for year in years {
                let peopleCost = yearly[year]?.total ?? 0
                let otherCost = otherByYear[year] ?? 0
                row.append(fmt(peopleCost + otherCost))
            }
            let peopleTotal = yearly.values.reduce(0) { $0 + $1.total }
            row.append(fmt(peopleTotal + otherTotal))
            lines.append(csvRow(row))
        }
        let grandTotal = plan.initiatives.reduce(0.0) { sum, init_ in
            let yearly = ReportData.initiativeYearlyCosts(initiative: init_, plan: plan, resources: resources, currencyContext: ctx)
            return sum + yearly.values.reduce(0) { $0 + $1.total } + ReportData.otherCostsTotal(initiative: init_, currencyContext: ctx)
        }
        var totalRow = ["Total"]
        for year in years {
            let yearTotal = plan.initiatives.reduce(0.0) { sum, init_ in
                let yearly = ReportData.initiativeYearlyCosts(initiative: init_, plan: plan, resources: resources, currencyContext: ctx)
                let otherYear = ReportData.otherCostsByYear(initiative: init_, currencyContext: ctx)[year] ?? 0
                return sum + (yearly[year]?.total ?? 0) + otherYear
            }
            totalRow.append(fmt(yearTotal))
        }
        totalRow.append(fmt(grandTotal))
        lines.append(csvRow(totalRow))

        lines.append("")

        // Section 2: Committed vs Placeholder
        lines.append("Committed vs Placeholder")
        lines.append(csvRow(["Initiative", "Committed", "Placeholder", "Total"]))
        for initiative in plan.initiatives {
            let yearly = ReportData.initiativeYearlyCosts(initiative: initiative, plan: plan, resources: resources, currencyContext: ctx)
            let otherTotal = ReportData.otherCostsTotal(initiative: initiative, currencyContext: ctx)
            let committed = yearly.values.reduce(0) { $0 + $1.committed } + otherTotal
            let placeholder = yearly.values.reduce(0) { $0 + $1.placeholder }
            let name = initiative.name.isEmpty ? "Untitled" : initiative.name
            lines.append(csvRow([name, fmt(committed), fmt(placeholder), fmt(committed + placeholder)]))
        }

        return Data(lines.joined(separator: "\n").utf8)
    }

    // MARK: - Reports: Resource Allocation

    static func exportResourceAllocationReport(plan: Plan, resources: [Resource], roles: [Role], displayCurrency: String = "USD", conversionRates: [String: Double] = ["USD": 1.0]) -> Data {
        let ctx = ReportData.CurrencyContext(displayCurrency: displayCurrency, conversionRates: conversionRates)
        var lines: [String] = []
        lines.append("Currency,\(displayCurrency)")
        let years = ReportData.allActiveYears(plan: plan)
        let entries = ReportData.resourceAllocationByRole(plan: plan, resources: resources, roles: roles, currencyContext: ctx)

        lines.append("Resource Allocation by Role")
        lines.append(csvRow(["Role", "Resource", "Initiative", "Avg %"] + years.map(String.init) + ["Total"]))
        for roleEntry in entries {
            for resourceEntry in roleEntry.resources {
                for assignment in resourceEntry.assignments {
                    var row = [roleEntry.roleName, resourceEntry.name, assignment.initiativeName]
                    row.append("\(Int(round(assignment.avgPercent * 100)))%")
                    for year in years {
                        row.append(fmt(assignment.costByYear[year] ?? 0))
                    }
                    row.append(fmt(assignment.cost))
                    lines.append(csvRow(row))
                }
            }
        }

        lines.append("")

        // Remaining Capacity
        let capacity = ReportData.remainingCapacityByRole(plan: plan, resources: resources, roles: roles, currencyContext: ctx)
        lines.append("Remaining Capacity")
        lines.append(csvRow(["Role", "Resource", "Remaining %", "Remaining Annual Cost"]))
        for roleEntry in capacity {
            for entry in roleEntry.resources {
                lines.append(csvRow([
                    roleEntry.roleName,
                    entry.name,
                    "\(Int(round(entry.remainingPercent * 100)))%",
                    fmt(entry.remainingMonthlyCost * 12)
                ]))
            }
        }

        return Data(lines.joined(separator: "\n").utf8)
    }

    // MARK: - Initiative Detail

    static func exportInitiativeReport(initiative: Initiative, plan: Plan, resources: [Resource], roles: [Role], displayCurrency: String = "USD", conversionRates: [String: Double] = ["USD": 1.0]) -> Data {
        let ctx = ReportData.CurrencyContext(displayCurrency: displayCurrency, conversionRates: conversionRates)
        var lines: [String] = []
        lines.append("Currency,\(displayCurrency)")
        let years = ReportData.allActiveYears(plan: plan)
        let breakdown = ReportData.resourceBreakdown(initiative: initiative, plan: plan, resources: resources, currencyContext: ctx)
        let roleCosts = ReportData.initiativeCostByRole(initiative: initiative, plan: plan, resources: resources, roles: roles, currencyContext: ctx)
        let otherTotal = ReportData.otherCostsTotal(initiative: initiative, currencyContext: ctx)
        let peopleCost = breakdown.reduce(0) { $0 + $1.totalCost }
        let totalCost = peopleCost + otherTotal

        lines.append("Initiative: \(initiative.name.isEmpty ? "Untitled" : initiative.name)")
        lines.append("")

        // Summary
        let totalReturn = ReportData.expectedReturnsTotal(initiative: initiative, currencyContext: ctx)
        lines.append("Summary")
        lines.append(csvRow(["Total Cost", fmt(totalCost)]))
        if totalReturn > 0 {
            let netReturn = totalReturn - totalCost
            let roi = totalCost > 0 ? (netReturn / totalCost) * 100 : 0
            lines.append(csvRow(["Expected Return", fmt(totalReturn)]))
            lines.append(csvRow(["Net Return", fmt(netReturn)]))
            lines.append(csvRow(["ROI", String(format: "%+.0f%%", roi)]))
        }
        lines.append("")

        // Cost by Role
        if !roleCosts.isEmpty {
            lines.append("Cost by Role")
            lines.append(csvRow(["Role"] + years.map(String.init) + ["Total"]))
            for entry in roleCosts {
                var row = [entry.roleName]
                for year in years { row.append(fmt(entry.costByYear[year] ?? 0)) }
                row.append(fmt(entry.totalCost))
                lines.append(csvRow(row))
            }
            lines.append("")
        }

        // Assigned Resources
        if !breakdown.isEmpty {
            lines.append("Assigned Resources")
            lines.append(csvRow(["Resource", "Avg %"] + years.map(String.init) + ["Total"]))
            for entry in breakdown {
                var row = [entry.name.isEmpty ? "Untitled" : entry.name]
                row.append("\(Int(round(entry.avgAllocation * 100)))%")
                for year in years { row.append(fmt(entry.costByYear[year] ?? 0)) }
                row.append(fmt(entry.totalCost))
                lines.append(csvRow(row))
            }
            lines.append("")
        }

        // Other Costs
        if !initiative.otherCosts.isEmpty {
            lines.append("Other Costs")
            lines.append(csvRow(["Name", "Period (months)"] + years.map(String.init) + ["Total"]))
            for cost in initiative.otherCosts {
                var row = [cost.name.isEmpty ? "Untitled" : cost.name, "\(cost.monthKeys.count)"]
                for year in years { row.append(fmt(cost.costByYear[year] ?? 0)) }
                row.append(fmt(cost.totalAmount))
                lines.append(csvRow(row))
            }
        }

        return Data(lines.joined(separator: "\n").utf8)
    }

    // MARK: - Helpers

    private static func fmt(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func csvRow(_ fields: [String]) -> String {
        fields.map { field in
            if field.contains(",") || field.contains("\"") || field.contains("\n") {
                return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return field
        }.joined(separator: ",")
    }
}
