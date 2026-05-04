import SwiftUI

// MARK: - ReportsView

struct ReportsView: View {
    @Binding var plan: Plan
    @Binding var resources: [Resource]
    let roles: [Role]
    let displayCurrency: String
    let conversionRates: [String: Double]

    @State private var excludedPlaceholders: Set<UUID> = []

    private var currencyContext: ReportData.CurrencyContext {
        ReportData.CurrencyContext(displayCurrency: displayCurrency, conversionRates: conversionRates)
    }

    private var years: [Int] { ReportData.allActiveYears(plan: plan) }
    private var hasData: Bool { !years.isEmpty && !plan.initiatives.isEmpty }

    @State private var reportTab: ReportTab = .overview

    private enum ReportTab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case resourceAllocation = "Resource Allocation"
        var id: String { rawValue }
    }

    var body: some View {
        Group {
            if hasData {
                VStack(spacing: 0) {
                    // Tab picker + export button
                    HStack {
                        Picker("Report", selection: $reportTab) {
                            ForEach(ReportTab.allCases) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)

                        exportMenu
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    // Paper-style container
                    ScrollView {
                        HStack {
                            Spacer(minLength: 0)
                            VStack(alignment: .leading, spacing: 24) {
                                switch reportTab {
                                case .overview:
                                    overviewContent
                                case .resourceAllocation:
                                    resourceAllocationContent
                                }
                            }
                            .padding(32)
                            .frame(maxWidth: reportTab == .overview ? 816 : .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(nsColor: .textBackgroundColor))
                                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
                            )
                            .padding(.vertical, 20)
                            .padding(.horizontal, reportTab == .resourceAllocation ? 20 : 0)
                            Spacer(minLength: 0)
                        }
                    }
                    .background(Color(nsColor: .windowBackgroundColor))
                }
            } else {
                ContentUnavailableView(
                    "No Report Data",
                    systemImage: "chart.bar.fill",
                    description: Text("Add initiatives and allocations in the Planning view to see cost reports.")
                )
            }
        }
        .navigationTitle("")
    }

    // MARK: - Export

    private var exportMenu: some View {
        Menu {
            Button("Export as PDF\u{2026}") { exportCurrentTab(.pdf) }
            Button("Export as CSV\u{2026}") { exportCurrentTab(.csv) }
            Button("Export as JSON\u{2026}") { exportCurrentTab(.json) }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func exportCurrentTab(_ format: ExportFormat) {
        let defaultName: String
        let data: Data

        switch reportTab {
        case .overview:
            defaultName = "\(plan.name) — Overview"
            switch format {
            case .pdf:  data = ReportPDFExporter.exportOverviewReport(plan: plan, resources: resources, roles: roles, displayCurrency: displayCurrency, conversionRates: conversionRates)
            case .csv:  data = ReportCSVExporter.exportOverviewReport(plan: plan, resources: resources, roles: roles, displayCurrency: displayCurrency, conversionRates: conversionRates)
            case .json: data = ReportJSONExporter.exportReport(plan: plan, resources: resources, roles: roles, displayCurrency: displayCurrency, conversionRates: conversionRates)
            }
        case .resourceAllocation:
            defaultName = "\(plan.name) — Resource Allocation"
            switch format {
            case .pdf:  data = ReportPDFExporter.exportResourceAllocationReport(plan: plan, resources: resources, roles: roles, displayCurrency: displayCurrency, conversionRates: conversionRates)
            case .csv:  data = ReportCSVExporter.exportResourceAllocationReport(plan: plan, resources: resources, roles: roles, displayCurrency: displayCurrency, conversionRates: conversionRates)
            case .json: data = ReportJSONExporter.exportReport(plan: plan, resources: resources, roles: roles, displayCurrency: displayCurrency, conversionRates: conversionRates)
            }
        }

        showExportSavePanel(title: "Export Report", defaultName: defaultName, format: format) { url in
            guard let url else { return }
            try? data.write(to: url)
        }
    }

    // MARK: - Overview tab content

    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            costByInitiativeSection
            Divider()
            committedVsPlaceholderSection
            Divider()
            placeholderImpactSection
        }
    }

    // MARK: - Resource Allocation tab content

    private var resourceAllocationContent: some View {
        let entries = ReportData.resourceAllocationByRole(plan: plan, resources: resources, roles: roles, currencyContext: currencyContext)

        return VStack(alignment: .leading, spacing: 16) {
            Text("Resource Allocation by Role")
                .font(.title2.bold())
            Text("How resources in each role are assigned to initiatives and at what cost.")
                .font(.body)
                .foregroundStyle(.secondary)

            if entries.isEmpty {
                Text("No resource allocations found.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                Grid(alignment: .trailing, horizontalSpacing: 16, verticalSpacing: 6) {
                    // Header row
                    GridRow {
                        Text("")
                            .gridColumnAlignment(.leading)
                        ForEach(years, id: \.self) { year in
                            Text(String(year))
                                .font(.subheadline.bold())
                        }
                        Text("Total")
                            .font(.subheadline.bold())
                    }
                    Divider()

                    ForEach(entries) { roleEntry in
                        // Role header row
                        GridRow {
                            HStack {
                                Image(systemName: "tag.fill")
                                    .foregroundStyle(.purple)
                                    .frame(width: 16)
                                Text(roleEntry.roleName)
                                    .font(.headline)
                            }
                            .gridColumnAlignment(.leading)

                            ForEach(years, id: \.self) { year in
                                Text(roleEntry.costForYear(year), format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                    .font(.subheadline.bold().monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Text(roleEntry.totalCost, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                .font(.headline.monospacedDigit())
                        }

                        // Resources in this role
                        ForEach(roleEntry.resources) { resourceEntry in
                            // Resource header row
                            GridRow {
                                HStack {
                                    Spacer().frame(width: 8)
                                    Image(systemName: resourceIcon(resourceEntry.employmentType))
                                        .foregroundStyle(resourceTint(resourceEntry.employmentType))
                                        .frame(width: 16)
                                    Text(resourceEntry.name.isEmpty ? "Untitled" : resourceEntry.name)
                                        .font(.subheadline.bold())
                                }
                                .gridColumnAlignment(.leading)

                                ForEach(years, id: \.self) { year in
                                    Text(resourceEntry.costForYear(year), format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                Text(resourceEntry.totalCost, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                    .font(.subheadline.bold().monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }

                            // Assignment sub-rows
                            ForEach(resourceEntry.assignments) { assignment in
                                GridRow {
                                    HStack(spacing: 6) {
                                        Spacer().frame(width: 32)
                                        Circle()
                                            .fill(assignment.color.swiftUIColor)
                                            .frame(width: 8, height: 8)
                                        Text(assignment.initiativeName)
                                            .font(.body)
                                            .lineLimit(1)
                                        Text("\(Int(round(assignment.avgPercent * 100)))%")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                    .gridColumnAlignment(.leading)

                                    ForEach(years, id: \.self) { year in
                                        Text(assignment.costByYear[year] ?? 0, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.tertiary)
                                    }
                                    Text(assignment.cost, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                        .font(.body.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Divider()
                    }
                }
            }

            Divider()
            remainingCapacitySection
        }
    }

    // MARK: - Section 1: Cost by Initiative (yearly)

    private var costByInitiativeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cost by Initiative")
                .font(.title2.bold())

            Grid(alignment: .trailing, horizontalSpacing: 16, verticalSpacing: 6) {
                // Header
                GridRow {
                    Text("Initiative")
                        .font(.subheadline.bold())
                        .gridColumnAlignment(.leading)
                    ForEach(years, id: \.self) { year in
                        Text(String(year))
                            .font(.subheadline.bold())
                    }
                    Text("Total")
                        .font(.subheadline.bold())
                }
                Divider()

                // Rows per initiative with per-role sub-rows
                ForEach(plan.initiatives) { initiative in
                    let yearly = ReportData.initiativeYearlyCosts(
                        initiative: initiative, plan: plan, resources: resources,
                        currencyContext: currencyContext
                    )
                    let otherByYear = ReportData.otherCostsByYear(initiative: initiative, currencyContext: currencyContext)
                    let otherTotal = ReportData.otherCostsTotal(initiative: initiative, currencyContext: currencyContext)
                    let hasOtherCosts = otherTotal > 0

                    GridRow {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(initiative.color.swiftUIColor)
                                .frame(width: 10, height: 10)
                            Text(initiative.name.isEmpty ? "Untitled" : initiative.name)
                                .font(.body)
                                .lineLimit(1)
                        }
                        .gridColumnAlignment(.leading)

                        ForEach(years, id: \.self) { year in
                            let peopleCost = yearly[year]?.total ?? 0
                            let otherCost = otherByYear[year] ?? 0
                            Text(peopleCost + otherCost, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                .font(.body.monospacedDigit())
                        }
                        let peopleTotal = yearly.values.reduce(0) { $0 + $1.total }
                        Text(peopleTotal + otherTotal, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                            .font(.body.bold().monospacedDigit())
                    }

                    // Per-role sub-rows with tree connector
                    let roleCosts = ReportData.initiativeCostByRole(initiative: initiative, plan: plan, resources: resources, roles: roles, currencyContext: currencyContext)
                    let subRowCount = roleCosts.count + (hasOtherCosts ? 1 : 0)
                    ForEach(Array(roleCosts.enumerated()), id: \.element.id) { idx, roleCost in
                        GridRow {
                            HStack(spacing: 4) {
                                Text(idx == subRowCount - 1 ? "└" : "├")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.quaternary)
                                Text(roleCost.roleName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .gridColumnAlignment(.leading)

                            ForEach(years, id: \.self) { year in
                                Text(roleCost.costByYear[year] ?? 0, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Text(roleCost.totalCost, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Other costs sub-row
                    if hasOtherCosts {
                        GridRow {
                            HStack(spacing: 4) {
                                Text("└")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.quaternary)
                                Text("Other Costs")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .gridColumnAlignment(.leading)

                            ForEach(years, id: \.self) { year in
                                Text(otherByYear[year] ?? 0, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Text(otherTotal, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Total row
                Divider()
                GridRow {
                    Text("Total")
                        .font(.body.bold())
                        .gridColumnAlignment(.leading)
                    ForEach(years, id: \.self) { year in
                        let yearTotal = plan.initiatives.reduce(0.0) { sum, init_ in
                            let yearly = ReportData.initiativeYearlyCosts(
                                initiative: init_, plan: plan, resources: resources,
                                currencyContext: currencyContext
                            )
                            let otherYear = ReportData.otherCostsByYear(initiative: init_, currencyContext: currencyContext)[year] ?? 0
                            return sum + (yearly[year]?.total ?? 0) + otherYear
                        }
                        Text(yearTotal, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                            .font(.body.bold().monospacedDigit())
                    }
                    let grandTotal = plan.initiatives.reduce(0.0) { sum, init_ in
                        let yearly = ReportData.initiativeYearlyCosts(
                            initiative: init_, plan: plan, resources: resources,
                            currencyContext: currencyContext
                        )
                        return sum + yearly.values.reduce(0) { $0 + $1.total } + ReportData.otherCostsTotal(initiative: init_, currencyContext: currencyContext)
                    }
                    Text(grandTotal, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                        .font(.body.bold().monospacedDigit())
                }
            }
        }
    }

    // MARK: - Section 2: Committed vs Placeholder

    private var committedVsPlaceholderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Committed vs Placeholder Cost")
                .font(.title2.bold())

            Grid(alignment: .trailing, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("Initiative")
                        .font(.subheadline.bold())
                        .gridColumnAlignment(.leading)
                    Text("Committed")
                        .font(.subheadline.bold())
                    Text("Placeholder")
                        .font(.subheadline.bold())
                    Text("Total")
                        .font(.subheadline.bold())
                }
                Divider()

                ForEach(plan.initiatives) { initiative in
                    let yearly = ReportData.initiativeYearlyCosts(
                        initiative: initiative, plan: plan, resources: resources,
                        currencyContext: currencyContext
                    )
                    let otherTotal = ReportData.otherCostsTotal(initiative: initiative, currencyContext: currencyContext)
                    let committed = yearly.values.reduce(0) { $0 + $1.committed } + otherTotal
                    let placeholder = yearly.values.reduce(0) { $0 + $1.placeholder }
                    let total = committed + placeholder

                    GridRow {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(initiative.color.swiftUIColor)
                                .frame(width: 10, height: 10)
                            Text(initiative.name.isEmpty ? "Untitled" : initiative.name)
                                .font(.body)
                                .lineLimit(1)
                        }
                        .gridColumnAlignment(.leading)

                        Text(committed, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                            .font(.body.monospacedDigit())
                        Text(placeholder, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(placeholder > 0 ? .orange : .secondary)
                        Text(total, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                            .font(.body.bold().monospacedDigit())
                    }
                }

                Divider()
                let allCommitted = plan.initiatives.reduce(0.0) { sum, init_ in
                    let yearly = ReportData.initiativeYearlyCosts(initiative: init_, plan: plan, resources: resources, currencyContext: currencyContext)
                    return sum + yearly.values.reduce(0) { $0 + $1.committed } + ReportData.otherCostsTotal(initiative: init_, currencyContext: currencyContext)
                }
                let allPlaceholder = plan.initiatives.reduce(0.0) { sum, init_ in
                    let yearly = ReportData.initiativeYearlyCosts(initiative: init_, plan: plan, resources: resources, currencyContext: currencyContext)
                    return sum + yearly.values.reduce(0) { $0 + $1.placeholder }
                }
                GridRow {
                    Text("Total")
                        .font(.body.bold())
                        .gridColumnAlignment(.leading)
                    Text(allCommitted, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                        .font(.body.bold().monospacedDigit())
                    Text(allPlaceholder, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                        .font(.body.bold().monospacedDigit())
                        .foregroundStyle(allPlaceholder > 0 ? .orange : .secondary)
                    Text(allCommitted + allPlaceholder, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                        .font(.body.bold().monospacedDigit())
                }
            }
        }
    }

    // MARK: - Section 3: Placeholder Impact

    private var placeholderImpactSection: some View {
        let placeholders = ReportData.placeholderResourcesInPlan(plan: plan, resources: resources)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Placeholder Impact")
                .font(.title2.bold())
            Text("Toggle placeholder resources to see their incremental cost impact.")
                .font(.body)
                .foregroundStyle(.secondary)

            if placeholders.isEmpty {
                Text("No placeholder resources have allocations in this plan.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(placeholders) { resource in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { !excludedPlaceholders.contains(resource.id) },
                                set: { included in
                                    if included {
                                        excludedPlaceholders.remove(resource.id)
                                    } else {
                                        excludedPlaceholders.insert(resource.id)
                                    }
                                }
                            )) {
                                HStack(spacing: 6) {
                                    Image(systemName: "questionmark.circle.fill")
                                        .foregroundStyle(.gray)
                                        .frame(width: 16)
                                    Text(resource.name.isEmpty ? "Untitled" : resource.name)
                                        .font(.body)
                                    Spacer()
                                    Text(resource.monthlyCost * 12, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                        .font(.body.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                }

                Divider().padding(.vertical, 4)

                let totalWithAll = ReportData.totalPlanCost(plan: plan, resources: resources, excludedResourceIDs: [], currencyContext: currencyContext)
                let totalWithExclusions = ReportData.totalPlanCost(plan: plan, resources: resources, excludedResourceIDs: excludedPlaceholders, currencyContext: currencyContext)
                let incremental = totalWithAll - totalWithExclusions

                Grid(alignment: .trailing, horizontalSpacing: 16, verticalSpacing: 6) {
                    GridRow {
                        Text("Total (all resources)")
                            .font(.body)
                            .gridColumnAlignment(.leading)
                        Text(totalWithAll, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                            .font(.body.monospacedDigit())
                    }
                    GridRow {
                        Text("Total (without unchecked)")
                            .font(.body)
                            .gridColumnAlignment(.leading)
                        Text(totalWithExclusions, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                            .font(.body.monospacedDigit())
                    }
                    Divider()
                    GridRow {
                        Text("Incremental cost of unchecked")
                            .font(.body.bold())
                            .gridColumnAlignment(.leading)
                        Text(incremental, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                            .font(.body.bold().monospacedDigit())
                            .foregroundStyle(incremental > 0 ? .orange : .secondary)
                    }
                }
            }
        }
    }

    // MARK: - Section 4: Remaining Capacity by Role

    private var remainingCapacitySection: some View {
        let entries = ReportData.remainingCapacityByRole(plan: plan, resources: resources, roles: roles, currencyContext: currencyContext)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Remaining Capacity")
                .font(.title2.bold())
            Text("Un-allocated capacity across the plan's active date range, grouped by role.")
                .font(.body)
                .foregroundStyle(.secondary)

            if entries.isEmpty {
                Text("All resources are fully allocated.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(entries) { roleEntry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "tag.fill")
                                .foregroundStyle(.purple)
                                .frame(width: 16)
                            Text(roleEntry.roleName)
                                .font(.subheadline.bold())
                            Spacer()
                            Text(roleEntry.totalRemainingMonthlyCost * 12, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                .font(.subheadline.bold().monospacedDigit())
                                .foregroundStyle(.secondary)
                            Text("/yr remaining")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        ForEach(roleEntry.resources) { entry in
                            HStack(spacing: 8) {
                                Spacer().frame(width: 24)
                                Text(entry.name.isEmpty ? "Untitled" : entry.name)
                                    .font(.body)
                                Spacer()
                                Text("\(Int(round(entry.remainingPercent * 100)))% free")
                                    .font(.body.monospacedDigit())
                                    .foregroundStyle(.green)
                                Text(entry.remainingMonthlyCost * 12, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                    .font(.body.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 100, alignment: .trailing)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Helpers

    private func resourceIcon(_ type: EmploymentType) -> String {
        switch type {
        case .fullTime: return "person.fill"
        case .contractor: return "briefcase.fill"
        case .placeholder: return "questionmark.circle.fill"
        }
    }

    private func resourceTint(_ type: EmploymentType) -> Color {
        switch type {
        case .fullTime: return .blue
        case .contractor: return .orange
        case .placeholder: return .gray
        }
    }
}
