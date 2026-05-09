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

    private var months: [MonthKey] {
        guard let plan else { return [] }
        return ReportData.allActiveMonths(plan: plan)
    }

    private var totalMonthlyCost: Double {
        members.reduce(0) { $0 + $1.monthlyCost }
    }

    var body: some View {
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
                                    HStack(spacing: 6) {
                                        if let roleID = resource.roleID,
                                           let roleName = roles.first(where: { $0.id == roleID })?.name {
                                            Text(roleName)
                                        }
                                        if let plan {
                                            Text("•").foregroundStyle(.tertiary)
                                            Text(allocationText(for: resource, plan: plan))
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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

            if !members.isEmpty {
                Section("Rollup") {
                    LabeledContent("Combined monthly cost") {
                        Text(totalMonthlyCost,
                             format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                            .monospacedDigit()
                            .bold()
                    }
                    LabeledContent("Annualized") {
                        Text(totalMonthlyCost * 12,
                             format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
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
        .navigationTitle(team.name.isEmpty ? "Untitled Team" : team.name)
    }

    private func allocationText(for resource: Resource, plan: Plan) -> String {
        guard !months.isEmpty else { return "no allocations" }
        let avg = plan.averageAllocation(for: resource.id, in: months)
        return "\(Int(round(avg * 100)))% avg"
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
