import SwiftUI

struct InitiativeDetailView: View {
    @Binding var initiative: Initiative
    let plan: Plan?
    let resources: [Resource]
    let roles: [Role]
    let displayCurrency: String
    let conversionRates: [String: Double]

    private var currencyContext: ReportData.CurrencyContext {
        ReportData.CurrencyContext(displayCurrency: displayCurrency, conversionRates: conversionRates)
    }

    var body: some View {
        HSplitView {
            // Left: editable fields
            Form {
                Section("Initiative") {
                    TextField("Name", text: $initiative.name)
                        .textFieldStyle(.roundedBorder)

                    LabeledContent("Color") {
                        Menu {
                            ForEach(InitiativeColor.allCases) { c in
                                Button {
                                    initiative.color = c
                                } label: {
                                    Label {
                                        Text(c.displayName)
                                    } icon: {
                                        Image(nsImage: colorSwatchImage(c.swiftUIColor))
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(initiative.color.swiftUIColor)
                                    .frame(width: 12, height: 12)
                                Text(initiative.color.displayName)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }

                    LabeledContent("Icon") {
                        Menu {
                            ForEach(initiativeIconOptions, id: \.self) { iconName in
                                Button {
                                    initiative.icon = iconName
                                } label: {
                                    Label(iconDisplayName(iconName), systemImage: iconName)
                                }
                            }
                        } label: {
                            Image(systemName: initiative.icon)
                                .frame(width: 16)
                        }
                    }
                }

                Section("Description") {
                    TextEditor(text: $initiative.notes)
                        .frame(minHeight: 80)
                        .font(.body)
                        .border(Color(nsColor: .separatorColor), width: 1)
                }

                Section("Timeline") {
                    DatePicker("Start date", selection: $initiative.startDate, displayedComponents: .date)

                    DatePicker(
                        "End date",
                        selection: endDateBinding,
                        in: initiative.startDate...,
                        displayedComponents: .date
                    )

                    if initiative.endDate < initiative.startDate {
                        Label("End date must be on or after start date", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    LabeledContent("Duration") {
                        Text(durationText)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    if initiative.expectedReturns.isEmpty {
                        Text("No expected returns")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach($initiative.expectedReturns) { $ret in
                            ExpectedReturnRow(ret: $ret) {
                                initiative.expectedReturns.removeAll { $0.id == ret.id }
                            }
                        }
                    }

                    Button {
                        let fourWeeksLater = Calendar.gregorianUTC.date(byAdding: .weekOfYear, value: 4, to: initiative.startDate) ?? initiative.endDate
                        initiative.expectedReturns.append(
                            ExpectedReturn(
                                name: "",
                                startDate: initiative.startDate,
                                endDate: min(fourWeeksLater, initiative.endDate)
                            )
                        )
                    } label: {
                        Label("Add Return", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderless)
                } header: {
                    HStack {
                        Text("Expected Returns")
                        Spacer()
                        if !initiative.expectedReturns.isEmpty {
                            let total = initiative.expectedReturns.reduce(0) { $0 + currencyContext.convert($1.totalAmount, from: $1.currencyCode) }
                            Text(total, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Investment Window") {
                    DatePicker("Window end", selection: investmentWindowEndBinding, in: initiative.startDate..., displayedComponents: .date)

                    LabeledContent("Window") {
                        Text(investmentWindowText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    if initiative.otherCosts.isEmpty {
                        Text("No other costs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach($initiative.otherCosts) { $cost in
                            OtherCostRow(cost: $cost) {
                                initiative.otherCosts.removeAll { $0.id == cost.id }
                            }
                        }
                    }

                    Button {
                        let fourWeeksLater = Calendar.gregorianUTC.date(byAdding: .weekOfYear, value: 4, to: initiative.startDate) ?? initiative.endDate
                        initiative.otherCosts.append(
                            OtherCost(
                                name: "",
                                startDate: initiative.startDate,
                                endDate: min(fourWeeksLater, initiative.endDate)
                            )
                        )
                    } label: {
                        Label("Add Cost", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderless)
                } header: {
                    HStack {
                        Text("Other Costs")
                        Spacer()
                        if !initiative.otherCosts.isEmpty {
                            let total = initiative.otherCosts.reduce(0) { $0 + currencyContext.convert($1.totalAmount, from: $1.currencyCode) }
                            Text(total, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .frame(minWidth: 300, idealWidth: 380)

            // Right: initiative cost report
            if let plan {
                initiativeReport(plan: plan)
                    .frame(minWidth: 340, idealWidth: 420)
            }
        }
        .navigationTitle(initiative.name.isEmpty ? "Untitled Initiative" : initiative.name)
    }

    // MARK: - Initiative Report (right pane)

    @ViewBuilder
    private func initiativeReport(plan: Plan) -> some View {
        let breakdown = ReportData.resourceBreakdown(initiative: initiative, plan: plan, resources: resources, currencyContext: currencyContext)
        let peopleCost = breakdown.reduce(0) { $0 + $1.totalCost }
        let otherCostsTotal = ReportData.otherCostsTotal(initiative: initiative, currencyContext: currencyContext)
        let totalCost = peopleCost + otherCostsTotal
        let totalReturn = ReportData.expectedReturnsTotal(initiative: initiative, currencyContext: currencyContext)
        let roleCosts = ReportData.initiativeCostByRole(initiative: initiative, plan: plan, resources: resources, roles: roles, currencyContext: currencyContext)
        let otherCostsByYear = ReportData.otherCostsByYear(initiative: initiative, currencyContext: currencyContext)
        let returnsByYear = ReportData.expectedReturnsByYear(initiative: initiative, currencyContext: currencyContext)
        let activeYears = initiativeYears(plan: plan)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header: name + export
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: initiative.icon)
                                .foregroundStyle(initiative.color.swiftUIColor)
                            Text(initiative.name.isEmpty ? "Untitled Initiative" : initiative.name)
                                .font(.title2.bold())
                        }

                        if !initiative.notes.isEmpty {
                            Text(initiative.notes)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }

                    Spacer()
                    initiativeExportMenu(plan: plan)
                }

                Divider()

                // Large total cost hero with yearly breakdown
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Cost")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(totalCost, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    if activeYears.count > 1 {
                        HStack(spacing: 16) {
                            ForEach(activeYears, id: \.self) { year in
                                let peopleYear = breakdown.reduce(0.0) { $0 + ($1.costByYear[year] ?? 0) }
                                let otherYear = otherCostsByYear[year] ?? 0
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(String(year))
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                    Text(peopleYear + otherYear, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.bottom, 4)

                // Return & ROI summary
                if totalReturn > 0 {
                    let netReturn = totalReturn - totalCost
                    let roiPercent = totalCost > 0 ? (netReturn / totalCost) * 100 : 0
                    let paybackMonths = paybackPeriodMonths(totalCost: totalCost)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Expected Return")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(totalReturn, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                    .font(.title2.bold().monospacedDigit())
                                    .foregroundStyle(.green)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Net Return")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(netReturn, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                    .font(.title2.bold().monospacedDigit())
                                    .foregroundStyle(netReturn >= 0 ? .green : .red)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ROI")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("\(roiPercent, specifier: "%+.0f")%")
                                    .font(.title2.bold().monospacedDigit())
                                    .foregroundStyle(roiPercent >= 0 ? .green : .red)
                            }
                        }

                        if let months = paybackMonths {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(.secondary)
                                Text("Payback period: \(months) \(months == 1 ? "month" : "months")")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if activeYears.count > 1 {
                            HStack(spacing: 16) {
                                ForEach(activeYears, id: \.self) { year in
                                    let yearReturn = returnsByYear[year] ?? 0
                                    if yearReturn > 0 {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(String(year))
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                            Text(yearReturn, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                                .font(.subheadline.monospacedDigit())
                                                .foregroundStyle(.green.opacity(0.8))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 4)
                }

                Divider()

                // Cost by role with yearly columns
                if !roleCosts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cost by Role")
                            .font(.headline)

                        Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 4) {
                            // Header
                            if activeYears.count > 1 {
                                GridRow {
                                    Text("")
                                        .gridColumnAlignment(.leading)
                                    ForEach(activeYears, id: \.self) { year in
                                        Text(String(year))
                                            .font(.caption.bold())
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("Total")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                }
                            }

                            ForEach(roleCosts) { entry in
                                GridRow {
                                    HStack {
                                        Image(systemName: "tag.fill")
                                            .foregroundStyle(.purple)
                                            .frame(width: 14)
                                        Text(entry.roleName)
                                            .font(.body)
                                    }
                                    .gridColumnAlignment(.leading)

                                    if activeYears.count > 1 {
                                        ForEach(activeYears, id: \.self) { year in
                                            Text(entry.costByYear[year] ?? 0, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                                .font(.body.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Text(entry.totalCost, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                        .font(.body.bold().monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Divider()
                }

                // Assigned resources with yearly columns
                if breakdown.isEmpty {
                    Text("No resources allocated to this initiative.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Assigned Resources")
                            .font(.headline)

                        Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 6) {
                            GridRow {
                                Text("Resource")
                                    .font(.subheadline.bold())
                                    .gridColumnAlignment(.leading)
                                Text("Avg %")
                                    .font(.subheadline.bold())
                                if activeYears.count > 1 {
                                    ForEach(activeYears, id: \.self) { year in
                                        Text(String(year))
                                            .font(.subheadline.bold())
                                    }
                                }
                                Text("Total")
                                    .font(.subheadline.bold())
                            }
                            Divider()

                            ForEach(breakdown) { entry in
                                GridRow {
                                    HStack(spacing: 4) {
                                        Text(entry.name.isEmpty ? "Untitled" : entry.name)
                                            .font(.body)
                                        if entry.employmentType == .placeholder {
                                            Text("P")
                                                .font(.caption2.bold())
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                    .gridColumnAlignment(.leading)

                                    Text("\(Int(round(entry.avgAllocation * 100)))%")
                                        .font(.body.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                    if activeYears.count > 1 {
                                        ForEach(activeYears, id: \.self) { year in
                                            Text(entry.costByYear[year] ?? 0, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                                .font(.body.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Text(entry.totalCost, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                        .font(.body.bold().monospacedDigit())
                                }
                            }

                            Divider()
                            GridRow {
                                Text("Total")
                                    .font(.body.bold())
                                    .gridColumnAlignment(.leading)
                                Text("")
                                if activeYears.count > 1 {
                                    ForEach(activeYears, id: \.self) { year in
                                        let yearTotal = breakdown.reduce(0.0) { $0 + ($1.costByYear[year] ?? 0) }
                                        Text(yearTotal, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                            .font(.body.bold().monospacedDigit())
                                    }
                                }
                                Text(totalCost, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                    .font(.body.bold().monospacedDigit())
                            }
                        }
                    }
                }
                // Other costs section
                if !initiative.otherCosts.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Other Costs")
                            .font(.headline)

                        Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 6) {
                            GridRow {
                                Text("Cost")
                                    .font(.subheadline.bold())
                                    .gridColumnAlignment(.leading)
                                Text("Period")
                                    .font(.subheadline.bold())
                                if activeYears.count > 1 {
                                    ForEach(activeYears, id: \.self) { year in
                                        Text(String(year))
                                            .font(.subheadline.bold())
                                    }
                                }
                                Text("Total")
                                    .font(.subheadline.bold())
                            }
                            Divider()

                            ForEach(initiative.otherCosts) { cost in
                                GridRow {
                                    Text(cost.name.isEmpty ? "Untitled" : cost.name)
                                        .font(.body)
                                        .gridColumnAlignment(.leading)
                                    Text(costPeriodText(cost))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if activeYears.count > 1 {
                                        ForEach(activeYears, id: \.self) { year in
                                            Text(currencyContext.convert(cost.costByYear[year] ?? 0, from: cost.currencyCode), format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                                .font(.body.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Text(currencyContext.convert(cost.totalAmount, from: cost.currencyCode), format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                        .font(.body.bold().monospacedDigit())
                                }
                            }

                            Divider()
                            GridRow {
                                Text("Total")
                                    .font(.body.bold())
                                    .gridColumnAlignment(.leading)
                                Text("")
                                if activeYears.count > 1 {
                                    ForEach(activeYears, id: \.self) { year in
                                        Text(otherCostsByYear[year] ?? 0, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                            .font(.body.bold().monospacedDigit())
                                    }
                                }
                                Text(otherCostsTotal, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                    .font(.body.bold().monospacedDigit())
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func costPeriodText(_ cost: OtherCost) -> String {
        let months = cost.monthKeys.count
        return "\(months) \(months == 1 ? "mo" : "mos")"
    }

    // MARK: - Computation Helpers

    // MARK: - Export

    private func initiativeExportMenu(plan: Plan) -> some View {
        Menu {
            Button("Export as PDF\u{2026}") { exportInitiative(.pdf, plan: plan) }
            Button("Export as CSV\u{2026}") { exportInitiative(.csv, plan: plan) }
            Button("Export as JSON\u{2026}") { exportInitiative(.json, plan: plan) }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func exportInitiative(_ format: ExportFormat, plan: Plan) {
        let name = initiative.name.isEmpty ? "Untitled Initiative" : initiative.name
        let defaultName = "\(plan.name) — \(name)"
        let data: Data

        switch format {
        case .pdf:  data = ReportPDFExporter.exportInitiativeReport(initiative: initiative, plan: plan, resources: resources, roles: roles, displayCurrency: displayCurrency, conversionRates: conversionRates)
        case .csv:  data = ReportCSVExporter.exportInitiativeReport(initiative: initiative, plan: plan, resources: resources, roles: roles, displayCurrency: displayCurrency, conversionRates: conversionRates)
        case .json: data = ReportJSONExporter.exportInitiative(initiative: initiative, plan: plan, resources: resources, roles: roles, displayCurrency: displayCurrency, conversionRates: conversionRates)
        }

        showExportSavePanel(title: "Export Initiative Report", defaultName: defaultName, format: format) { url in
            guard let url else { return }
            try? data.write(to: url)
        }
    }

    private func initiativeYears(plan: Plan) -> [Int] {
        var yearSet = Set(ReportData.allActiveMonths(plan: plan).map(\.year))
        for cost in initiative.otherCosts {
            for mk in cost.monthKeys { yearSet.insert(mk.year) }
        }
        for ret in initiative.expectedReturns {
            for mk in ret.monthKeys { yearSet.insert(mk.year) }
        }
        return yearSet.sorted()
    }

    /// Computes payback period in months: how many months of return needed to cover totalCost.
    private func paybackPeriodMonths(totalCost: Double) -> Int? {
        guard totalCost > 0 else { return nil }
        // Collect all return month-keys with their amortized monthly value, sorted chronologically
        var monthlyReturns: [(MonthKey, Double)] = []
        for ret in initiative.expectedReturns {
            let perMonth = ret.monthlyReturn
            guard perMonth > 0 else { continue }
            for mk in ret.monthKeys {
                monthlyReturns.append((mk, currencyContext.convert(perMonth, from: ret.currencyCode)))
            }
        }
        guard !monthlyReturns.isEmpty else { return nil }
        monthlyReturns.sort { $0.0 < $1.0 }

        var cumulative = 0.0
        var months = 0
        for (_, amount) in monthlyReturns {
            cumulative += amount
            months += 1
            if cumulative >= totalCost { return months }
        }
        return nil // never pays back within the return window
    }

    // MARK: - Bindings

    /// Clamps end date so it can never go before start date.
    private var endDateBinding: Binding<Date> {
        Binding(
            get: { initiative.endDate },
            set: { newValue in
                initiative.endDate = max(newValue, initiative.startDate)
            }
        )
    }

    /// Binding for the investment window end date, defaulting to initiative endDate.
    private var investmentWindowEndBinding: Binding<Date> {
        Binding(
            get: { initiative.investmentWindowEnd ?? initiative.endDate },
            set: { initiative.investmentWindowEnd = $0 }
        )
    }

    private var investmentWindowText: String {
        let cal = Calendar.gregorianUTC
        let start = cal.startOfDay(for: initiative.startDate)
        let end = cal.startOfDay(for: initiative.effectiveInvestmentWindowEnd)
        let months = cal.dateComponents([.month], from: start, to: end).month ?? 0
        if months < 1 {
            let days = cal.dateComponents([.day], from: start, to: end).day ?? 0
            return "\(max(days, 0)) \(days == 1 ? "day" : "days")"
        }
        let years = months / 12
        let remainingMonths = months % 12
        var parts: [String] = []
        if years > 0 { parts.append("\(years) \(years == 1 ? "year" : "years")") }
        if remainingMonths > 0 { parts.append("\(remainingMonths) \(remainingMonths == 1 ? "month" : "months")") }
        return parts.joined(separator: ", ")
    }

    // MARK: - Helpers

    private var durationText: String {
        let cal = Calendar.gregorianUTC
        let start = cal.startOfDay(for: initiative.startDate)
        let end = cal.startOfDay(for: initiative.endDate)

        let days = cal.dateComponents([.day], from: start, to: end).day ?? 0
        let weeks = days / 7
        let remainingDays = days % 7

        if days < 7 {
            return "\(max(days, 0)) \(days == 1 ? "day" : "days")"
        }

        let months = cal.dateComponents([.month], from: start, to: end).month ?? 0

        var parts: [String] = []
        if months > 0 {
            parts.append("\(months) \(months == 1 ? "month" : "months")")
        }
        parts.append("\(weeks) \(weeks == 1 ? "week" : "weeks")")
        if remainingDays > 0 {
            parts.append("\(remainingDays) \(remainingDays == 1 ? "day" : "days")")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Other Cost Row

private struct OtherCostRow: View {
    @Binding var cost: OtherCost
    let onDelete: () -> Void

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 8) {
                TextField("Name", text: $cost.name)
                    .textFieldStyle(.roundedBorder)

                LabeledContent("Currency") {
                    Picker("", selection: $cost.currencyCode) {
                        ForEach(SupportedCurrency.allCases) { c in
                            Text(c.rawValue).tag(c.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                }

                LabeledContent("Amount") {
                    TextField("", value: zeroEmptyBinding($cost.totalAmount),
                              format: .currency(code: cost.currencyCode).precision(.fractionLength(0...2)))
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                }

                DatePicker("Start", selection: $cost.startDate, displayedComponents: .date)
                DatePicker("End", selection: costEndDateBinding, in: cost.startDate..., displayedComponents: .date)

                LabeledContent("Amortized") {
                    let months = cost.monthKeys.count
                    Text("\(cost.monthlyCost, format: .currency(code: cost.currencyCode).precision(.fractionLength(0)))/mo over \(months) \(months == 1 ? "month" : "months")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Spacer()
                    Button("Delete", role: .destructive) {
                        onDelete()
                    }
                    .font(.caption)
                }
            }
        } label: {
            HStack {
                Text(cost.name.isEmpty ? "Untitled cost" : cost.name)
                    .foregroundStyle(cost.name.isEmpty ? .secondary : .primary)
                Spacer()
                Text(cost.totalAmount, format: .currency(code: cost.currencyCode).precision(.fractionLength(0)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            // Auto-expand new costs with no name
            if cost.name.isEmpty && cost.totalAmount == 0 {
                isExpanded = true
            }
        }
    }

    private var costEndDateBinding: Binding<Date> {
        Binding(
            get: { cost.endDate },
            set: { cost.endDate = max($0, cost.startDate) }
        )
    }
}

// MARK: - Expected Return Row

private struct ExpectedReturnRow: View {
    @Binding var ret: ExpectedReturn
    let onDelete: () -> Void

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 8) {
                TextField("Name", text: $ret.name)
                    .textFieldStyle(.roundedBorder)

                LabeledContent("Currency") {
                    Picker("", selection: $ret.currencyCode) {
                        ForEach(SupportedCurrency.allCases) { c in
                            Text(c.rawValue).tag(c.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                }

                LabeledContent("Amount") {
                    TextField("", value: zeroEmptyBinding($ret.totalAmount),
                              format: .currency(code: ret.currencyCode).precision(.fractionLength(0...2)))
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                }

                DatePicker("Start", selection: $ret.startDate, displayedComponents: .date)
                DatePicker("End", selection: retEndDateBinding, in: ret.startDate..., displayedComponents: .date)

                LabeledContent("Amortized") {
                    let months = ret.monthKeys.count
                    Text("\(ret.monthlyReturn, format: .currency(code: ret.currencyCode).precision(.fractionLength(0)))/mo over \(months) \(months == 1 ? "month" : "months")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Spacer()
                    Button("Delete", role: .destructive) {
                        onDelete()
                    }
                    .font(.caption)
                }
            }
        } label: {
            HStack {
                Text(ret.name.isEmpty ? "Untitled return" : ret.name)
                    .foregroundStyle(ret.name.isEmpty ? .secondary : .primary)
                Spacer()
                Text(ret.totalAmount, format: .currency(code: ret.currencyCode).precision(.fractionLength(0)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if ret.name.isEmpty && ret.totalAmount == 0 {
                isExpanded = true
            }
        }
    }

    private var retEndDateBinding: Binding<Date> {
        Binding(
            get: { ret.endDate },
            set: { ret.endDate = max($0, ret.startDate) }
        )
    }
}

private let initiativeIconOptions: [String] = [
    "flag.fill",
    "star.fill",
    "bolt.fill",
    "target",
    "hammer.fill",
    "wrench.and.screwdriver.fill",
    "shippingbox.fill",
    "chart.line.uptrend.xyaxis",
    "lightbulb.fill",
    "leaf.fill",
    "shield.fill",
    "paperplane.fill",
    "puzzlepiece.fill",
    "building.2.fill",
    "globe",
]

private let iconDisplayNames: [String: String] = [
    "flag.fill": "Flag",
    "star.fill": "Star",
    "bolt.fill": "Bolt",
    "target": "Target",
    "hammer.fill": "Hammer",
    "wrench.and.screwdriver.fill": "Tools",
    "shippingbox.fill": "Shipping",
    "chart.line.uptrend.xyaxis": "Chart",
    "lightbulb.fill": "Lightbulb",
    "leaf.fill": "Leaf",
    "shield.fill": "Shield",
    "paperplane.fill": "Rocket",
    "puzzlepiece.fill": "Puzzle",
    "building.2.fill": "Building",
    "globe": "Globe",
]

private func iconDisplayName(_ icon: String) -> String {
    iconDisplayNames[icon] ?? icon
}

/// Creates a small colored circle NSImage for use in Menu items on macOS,
/// where SwiftUI's .foregroundStyle() is ignored on Image views.
private func colorSwatchImage(_ color: Color) -> NSImage {
    let size = NSSize(width: 14, height: 14)
    let image = NSImage(size: size, flipped: false) { rect in
        let nsColor = NSColor(color)
        nsColor.setFill()
        NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
        return true
    }
    image.isTemplate = false
    return image
}
// MARK: - Preview

#Preview {
    @Previewable @State var initiative = Initiative(
        name: "Project Alpha",
        startDate: Calendar.gregorianUTC.date(from: DateComponents(year: 2026, month: 1, day: 5))!,
        endDate: Calendar.gregorianUTC.date(from: DateComponents(year: 2026, month: 9, day: 30))!,
        notes: "A sample initiative for previewing the detail view.",
        color: .blue,
        icon: "bolt.fill",
        otherCosts: [
            OtherCost(
                name: "AWS Hosting",
                startDate: Calendar.gregorianUTC.date(from: DateComponents(year: 2026, month: 1, day: 5))!,
                endDate: Calendar.gregorianUTC.date(from: DateComponents(year: 2026, month: 6, day: 30))!,
                totalAmount: 12000
            )
        ],
        expectedReturns: [
            ExpectedReturn(
                name: "Cost Savings",
                startDate: Calendar.gregorianUTC.date(from: DateComponents(year: 2026, month: 4, day: 1))!,
                endDate: Calendar.gregorianUTC.date(from: DateComponents(year: 2026, month: 12, day: 31))!,
                totalAmount: 250_000
            )
        ]
    )

    let role = Role(name: "Engineer", defaultRate: 150_000, defaultRateBasis: .annual)
    let resource = Resource(name: "Alice", roleID: role.id, rate: 150_000, rateBasis: .annual)

    let plan = Plan(
        name: "2026 Roadmap",
        initiatives: [initiative],
        assignments: [
            Assignment(
                name: "Alice → Project Alpha",
                initiativeID: initiative.id,
                allocations: [
                    Allocation(
                        resourceID: resource.id,
                        months: [
                            MonthKey(year: 2026, month: 1): 0.5,
                            MonthKey(year: 2026, month: 2): 0.5,
                            MonthKey(year: 2026, month: 3): 0.75,
                        ]
                    )
                ]
            )
        ]
    )

    InitiativeDetailView(
        initiative: $initiative,
        plan: plan,
        resources: [resource],
        roles: [role],
        displayCurrency: "USD",
        conversionRates: [:]
    )
    .frame(width: 900, height: 700)
}

