import SwiftUI

struct TeamDetailView: View {
    @Binding var team: Team
    @Binding var resources: [Resource]
    let roles: [Role]
    let plan: Plan?
    let displayCurrency: String
    var onSelectResource: ((UUID) -> Void)? = nil

    private var members: [Resource] {
        resources.filter { $0.teamID == team.id }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        HSplitView {
            // Left: editable fields
            Form {
                Section("Team") {
                    TextField("Name", text: $team.name)
                        .textFieldStyle(.roundedBorder)

                    Picker("Color", selection: $team.color) {
                        ForEach(InitiativeColor.allCases) { c in
                            Label(c.displayName, systemImage: "circle.fill")
                                .foregroundStyle(c.swiftUIColor)
                                .tag(c)
                        }
                    }
                }

                Section("Members (\(members.count))") {
                    if members.isEmpty {
                        Text("No resources are on this team yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(members) { resource in
                            Button {
                                onSelectResource?(resource.id)
                            } label: {
                                HStack {
                                    Image(systemName: icon(for: resource.employmentType))
                                        .foregroundStyle(tint(for: resource.employmentType))
                                        .frame(width: 18)
                                    VStack(alignment: .leading) {
                                        Text(resource.name.isEmpty ? "Untitled" : resource.name)
                                        if let roleID = resource.roleID,
                                           let roleName = roles.first(where: { $0.id == roleID })?.name {
                                            Text(roleName)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text(resource.monthlyCost,
                                         format: .currency(code: resource.currencyCode).precision(.fractionLength(0)))
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section("Roles defaulting to this team") {
                    let defaultingRoles = roles.filter { $0.defaultTeamID == team.id }
                    if defaultingRoles.isEmpty {
                        Text("No roles default new resources to this team.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(defaultingRoles) { role in
                            Label(role.name.isEmpty ? "Untitled role" : role.name, systemImage: "tag.fill")
                                .foregroundStyle(.purple)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .frame(minWidth: 300, idealWidth: 380)

            // Right: rolled-up team report
            if let plan {
                teamReport(plan: plan)
                    .frame(minWidth: 360, idealWidth: 460)
            }
        }
        .navigationTitle(team.name.isEmpty ? "Untitled Team" : team.name)
    }

    @ViewBuilder
    private func teamReport(plan: Plan) -> some View {
        let ctx = ReportData.CurrencyContext(displayCurrency: displayCurrency, conversionRates: ["USD": 1.0])
        let rollup = ReportData.teamRollup(team: team, plan: plan, resources: resources, roles: roles, currencyContext: ctx)
        let years = rollup.costByYear.keys.sorted()
        let combinedMonthly = members.reduce(0) { $0 + $1.monthlyCost }

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: team.icon)
                        .foregroundStyle(team.color.swiftUIColor)
                    Text(team.name.isEmpty ? "Untitled Team" : team.name)
                        .font(.title2.bold())
                    Spacer()
                }

                Divider()

                // Hero: total allocated cost
                VStack(alignment: .leading, spacing: 4) {
                    Text("Allocated Cost")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(rollup.totalCost,
                         format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("Sum of all member allocations across this plan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Capacity hero: full team monthly + annual
                if !members.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Team Capacity (100%)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(combinedMonthly,
                                     format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                    .font(.title3.bold().monospacedDigit())
                                Text("per month").font(.caption).foregroundStyle(.secondary)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(combinedMonthly * 12,
                                     format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                    .font(.title3.bold().monospacedDigit())
                                Text("annualized").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Per-year
                if years.count > 0 {
                    Divider()
                    sectionHeader("Cost by Year")
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                        ForEach(years, id: \.self) { y in
                            GridRow {
                                Text(String(y))
                                Text(rollup.costByYear[y] ?? 0,
                                     format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                    .monospacedDigit()
                                    .gridColumnAlignment(.trailing)
                            }
                        }
                    }
                }

                if !rollup.byRole.isEmpty {
                    Divider()
                    sectionHeader("Cost by Role")
                    breakdownGrid(entries: rollup.byRole, years: years)
                }

                if !rollup.byInitiative.isEmpty {
                    Divider()
                    sectionHeader("Cost by Initiative")
                    breakdownGrid(entries: rollup.byInitiative, years: years)
                }

                if !rollup.byProgram.isEmpty {
                    Divider()
                    sectionHeader("Cost by Program")
                    breakdownGrid(entries: rollup.byProgram, years: years)
                }

                if rollup.totalCost == 0 {
                    Text("No allocations yet for this team's members.")
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    @ViewBuilder
    private func breakdownGrid(entries: [ReportData.TeamBreakdownEntry], years: [Int]) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
            GridRow {
                Text("").gridCellUnsizedAxes(.horizontal)
                ForEach(years, id: \.self) { y in
                    Text(String(y))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                }
                Text("Total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .gridColumnAlignment(.trailing)
            }
            ForEach(entries) { entry in
                GridRow {
                    HStack(spacing: 6) {
                        Image(systemName: entry.icon)
                            .foregroundStyle(entry.color.swiftUIColor)
                        Text(entry.name)
                    }
                    ForEach(years, id: \.self) { y in
                        Text(entry.costByYear[y] ?? 0,
                             format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                            .monospacedDigit()
                            .gridColumnAlignment(.trailing)
                    }
                    Text(entry.totalCost,
                         format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                        .monospacedDigit()
                        .bold()
                        .gridColumnAlignment(.trailing)
                }
            }
        }
    }

    private func icon(for type: EmploymentType) -> String {
        switch type {
        case .fullTime:    return "person.fill"
        case .contractor:  return "briefcase.fill"
        case .placeholder: return "questionmark.circle.fill"
        }
    }

    private func tint(for type: EmploymentType) -> Color {
        switch type {
        case .fullTime:    return .blue
        case .contractor:  return .orange
        case .placeholder: return .gray
        }
    }
}
