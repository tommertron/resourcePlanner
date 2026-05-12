import SwiftUI

// MARK: - Initiative color mapping

extension InitiativeColor {
    var swiftUIColor: Color {
        switch self {
        case .blue:   return .blue
        case .green:  return .green
        case .purple: return .purple
        case .orange: return .orange
        case .red:    return .red
        case .teal:   return .teal
        case .pink:   return .pink
        case .indigo: return .indigo
        case .mint:   return .mint
        case .brown:  return .brown
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Display name extensions

extension EmploymentType {
    var displayName: String {
        switch self {
        case .fullTime:    return "Full-time"
        case .contractor:  return "Contractor"
        case .placeholder: return "Placeholder"
        }
    }
}

extension RateBasis {
    var displayName: String {
        switch self {
        case .hourly:  return "Hourly"
        case .monthly: return "Monthly"
        case .annual:  return "Annual"
        }
    }
}

// MARK: - Supported currencies

enum SupportedCurrency: String, CaseIterable, Identifiable {
    case usd = "USD"
    case cad = "CAD"
    case eur = "EUR"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .usd: return "US Dollar (USD)"
        case .cad: return "Canadian Dollar (CAD)"
        case .eur: return "Euro (EUR)"
        }
    }
}

// MARK: - Resource sidebar row

struct ResourceRow: View {
    let resource: Resource
    let role: String?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(resource.name.isEmpty ? "Untitled" : resource.name)
                    .font(.body)
                    .foregroundStyle(resource.name.isEmpty ? .secondary : .primary)
                HStack(spacing: 6) {
                    if let role { Text(role) }
                    if role != nil { Text("•").foregroundStyle(.tertiary) }
                    Text(resource.employmentType.displayName).foregroundStyle(tint)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var icon: String {
        switch resource.employmentType {
        case .fullTime:    return "person.fill"
        case .contractor:  return "briefcase.fill"
        case .placeholder: return "questionmark.circle.fill"
        }
    }

    private var tint: Color {
        switch resource.employmentType {
        case .fullTime:    return .blue
        case .contractor:  return .orange
        case .placeholder: return .gray
        }
    }
}

// MARK: - Role detail (right pane when a role is selected)

struct RoleDetailView: View {
    @Binding var role: Role
    @Binding var resources: [Resource]
    let teams: [Team]
    var onAddResource: ((UUID) -> Void)? = nil

    var body: some View {
        Form {
            Section("Role") {
                TextField("Name", text: $role.name)
                    .textFieldStyle(.roundedBorder)

                if !teams.isEmpty {
                    Picker("Default Team", selection: $role.defaultTeamID) {
                        Text("None").tag(UUID?.none)
                        ForEach(teams) { team in
                            Text(team.name.isEmpty ? "Untitled team" : team.name)
                                .tag(UUID?.some(team.id))
                        }
                    }
                }
            }

            Section("Default compensation") {
                Picker("Rate Basis", selection: $role.defaultRateBasis) {
                    ForEach(RateBasis.allCases) { b in
                        Text(b.displayName).tag(b)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Currency", selection: $role.currencyCode) {
                    ForEach(SupportedCurrency.allCases) { c in
                        Text(c.rawValue).tag(c.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                LabeledContent(rateLabel) {
                    TextField("", value: zeroEmptyBinding($role.defaultRate),
                              format: .number.precision(.fractionLength(0...2)))
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 160)
                }

                if role.defaultRateBasis == .hourly {
                    LabeledContent("Hours per week") {
                        TextField("", value: zeroEmptyBinding($role.defaultHoursPerWeek),
                                  format: .number.precision(.fractionLength(0...1)))
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                    }
                }

                if role.defaultRateBasis == .annual && role.defaultRate > 0 {
                    LabeledContent("Equivalent hourly (40h/wk)") {
                        Text(role.defaultMonthlyCost / (52.0 / 12.0 * 40),
                             format: .currency(code: role.currencyCode).precision(.fractionLength(2)))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                } else if role.defaultRateBasis == .monthly && role.defaultRate > 0 {
                    LabeledContent("Equivalent hourly (40h/wk)") {
                        Text(role.defaultMonthlyCost / (52.0 / 12.0 * 40),
                             format: .currency(code: role.currencyCode).precision(.fractionLength(2)))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent("Annualized") {
                    Text(role.defaultMonthlyCost * 12,
                         format: .currency(code: role.currencyCode).precision(.fractionLength(0)))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            Section("Resources with this role (\(usingResources.count))") {
                if usingResources.isEmpty {
                    Text("No resources assigned to this role yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(usingResources) { r in
                        HStack {
                            Image(systemName: icon(for: r.employmentType))
                                .foregroundStyle(tint(for: r.employmentType))
                                .frame(width: 18)
                            VStack(alignment: .leading) {
                                Text(r.name.isEmpty ? "Untitled" : r.name)
                                Text(r.employmentType.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !r.matchesRoleDefault(role) {
                                Text("Custom rate")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            Text(r.monthlyCost * 12,
                                 format: .currency(code: r.currencyCode).precision(.fractionLength(0)))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }

                Button {
                    var newResource = Resource(name: "")
                    newResource.roleID = role.id
                    newResource.adoptRoleDefaults(role)
                    newResource.adoptRoleTeamDefault(role)
                    resources.append(newResource)
                    onAddResource?(newResource.id)
                } label: {
                    Label("Add Resource with This Role", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(role.name.isEmpty ? "Untitled Role" : role.name)
    }

    private var rateLabel: String {
        switch role.defaultRateBasis {
        case .hourly:  return "Default hourly rate"
        case .monthly: return "Default monthly rate"
        case .annual:  return "Default annual rate"
        }
    }

    private var usingResources: [Resource] {
        resources.filter { $0.roleID == role.id }
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

// MARK: - 0 ↔ nil binding helper for TextFields

func zeroEmptyBinding(_ source: Binding<Double>) -> Binding<Double?> {
    Binding<Double?>(
        get: { source.wrappedValue == 0 ? nil : source.wrappedValue },
        set: { source.wrappedValue = $0 ?? 0 }
    )
}
