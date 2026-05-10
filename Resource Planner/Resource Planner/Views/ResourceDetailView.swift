import SwiftUI

private let newRoleSentinel = UUID(uuidString: "00000000-0000-0000-0000-00000000ADD0")!

struct ResourceDetailView: View {
    @Binding var resource: Resource
    @Binding var roles: [Role]
    let teams: [Team]
    let plan: Plan?
    let displayCurrency: String

    @State private var pendingBasis: RateBasis?
    @State private var showingNewRoleSheet = false
    @State private var newRoleName = ""

    var body: some View {
        Form {
            Section("Identity") {
                TextField("Name", text: $resource.name)
                    .textFieldStyle(.roundedBorder)

                Picker("Role", selection: rolePickerBinding) {
                    Text("None").tag(UUID?.none)
                    ForEach(roles) { role in
                        Text(role.name.isEmpty ? "Untitled role" : role.name)
                            .tag(UUID?.some(role.id))
                    }
                    Divider()
                    Text("New Role…").tag(UUID?.some(newRoleSentinel))
                }

                Picker("Type", selection: $resource.employmentType) {
                    ForEach(EmploymentType.allCases) { t in
                        Text(t.displayName).tag(t)
                    }
                }
                .pickerStyle(.segmented)

                if !teams.isEmpty {
                    Picker("Team", selection: teamPickerBinding) {
                        Text("None").tag(UUID?.none)
                        ForEach(teams) { team in
                            Text(team.name.isEmpty ? "Untitled team" : team.name)
                                .tag(UUID?.some(team.id))
                        }
                    }
                    if resource.isCustomTeam, let role = currentRole, role.defaultTeamID != nil, role.defaultTeamID != resource.teamID {
                        HStack {
                            Text("Custom team — overrides role default.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Spacer()
                            Button("Reset to role default") {
                                resource.adoptRoleTeamDefault(role)
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        }
                    }
                }
            }

            Section {
                Picker("Rate Basis", selection: basisBinding) {
                    ForEach(RateBasis.allCases) { b in
                        Text(b.displayName).tag(b)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Currency", selection: $resource.currencyCode) {
                    ForEach(SupportedCurrency.allCases) { c in
                        Text(c.rawValue).tag(c.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: resource.currencyCode) { _, _ in
                    resource.isCustomRate = true
                }

                LabeledContent(rateLabel) {
                    TextField("", value: rateBinding,
                              format: .number.precision(.fractionLength(0...2)))
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 160)
                }

                if resource.rateBasis == .hourly {
                    LabeledContent("Hours per week") {
                        TextField("", value: zeroEmptyBinding($resource.hoursPerWeek),
                                  format: .number.precision(.fractionLength(0...1)))
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                    }
                }

                if resource.rateBasis == .annual && resource.rate > 0 {
                    LabeledContent("Equivalent hourly (40h/wk)") {
                        Text(resource.monthlyCost / (52.0 / 12.0 * 40),
                             format: .currency(code: resource.currencyCode).precision(.fractionLength(2)))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                } else if resource.rateBasis == .monthly && resource.rate > 0 {
                    LabeledContent("Equivalent hourly (40h/wk)") {
                        Text(resource.monthlyCost / (52.0 / 12.0 * 40),
                             format: .currency(code: resource.currencyCode).precision(.fractionLength(2)))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent("Monthly cost") {
                    Text(resource.monthlyCost,
                         format: .currency(code: resource.currencyCode).precision(.fractionLength(2)))
                        .monospacedDigit()
                }

                LabeledContent("Annualized") {
                    Text(resource.monthlyCost * 12,
                         format: .currency(code: resource.currencyCode).precision(.fractionLength(0)))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            } header: {
                HStack {
                    Text("Compensation")
                    Spacer()
                    if currentRole != nil {
                        Button {
                            if let r = currentRole { resource.adoptRoleDefaults(r) }
                        } label: {
                            Label("Reconcile to role default", systemImage: "arrow.counterclockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .disabled(matchesDefault)
                        .help(matchesDefault
                              ? "Already matches role default"
                              : "Replace this resource's rate with the role's default")
                    }
                }
            } footer: {
                if resource.isCustomRate, let role = currentRole, !matchesDefault {
                    Label("Custom rate — diverges from \(role.name.isEmpty ? "role" : role.name) default of \(formattedDefault(role))",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            if let plan {
                Section("Allocations") {
                    let entries = resourceAllocations(resourceID: resource.id, plan: plan)
                    if entries.isEmpty {
                        Text("Not allocated to any initiatives.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(entries) { entry in
                            HStack {
                                Image(systemName: entry.icon)
                                    .foregroundStyle(entry.color.swiftUIColor)
                                    .frame(width: 16)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.initiativeName)
                                        .font(.body)
                                    Text(entry.assignmentName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: 4) {
                                        Text(entry.startDate, format: .dateTime.month(.abbreviated).year())
                                        Text("–")
                                        Text(entry.endDate, format: .dateTime.month(.abbreviated).year())
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                }
                                Spacer()
                                Text("Avg \(Int(round(entry.avgPercent * 100)))%")
                                    .font(.body.monospacedDigit())
                                    .foregroundStyle(entry.avgPercent > 0.8 ? .red : entry.avgPercent > 0.5 ? .orange : .secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(resource.name.isEmpty ? "Untitled" : resource.name)
        .alert("Convert rate?",
               isPresented: Binding(get: { pendingBasis != nil }, set: { if !$0 { pendingBasis = nil } }),
               presenting: pendingBasis) { newBasis in
            Button("Convert value") { applyBasis(newBasis, convert: true) }
            Button("Keep value") { applyBasis(newBasis, convert: false) }
            Button("Cancel", role: .cancel) {}
        } message: { newBasis in
            Text("Convert \(formattedRate(resource.rate, basis: resource.rateBasis)) to \(newBasis.displayName.lowercased()) so the monthly cost stays the same? Choose Keep to leave the number alone and just reinterpret it.")
        }
        .sheet(isPresented: $showingNewRoleSheet) {
            NewRoleSheet(name: $newRoleName) { commit in
                if commit, !newRoleName.trimmingCharacters(in: .whitespaces).isEmpty {
                    let role = Role(name: newRoleName.trimmingCharacters(in: .whitespaces))
                    roles.append(role)
                    resource.roleID = role.id
                    if !resource.isCustomRate { resource.adoptRoleDefaults(role) }
                    if !resource.isCustomTeam { resource.adoptRoleTeamDefault(role) }
                }
                newRoleName = ""
            }
        }
    }

    // MARK: Bindings

    private var rolePickerBinding: Binding<UUID?> {
        Binding(
            get: { resource.roleID },
            set: { newValue in
                if newValue == newRoleSentinel {
                    newRoleName = ""
                    showingNewRoleSheet = true
                } else {
                    resource.roleID = newValue
                    if let r = currentRole(for: newValue) {
                        if !resource.isCustomRate { resource.adoptRoleDefaults(r) }
                        if !resource.isCustomTeam { resource.adoptRoleTeamDefault(r) }
                    }
                }
            }
        )
    }

    private var teamPickerBinding: Binding<UUID?> {
        Binding(
            get: { resource.teamID },
            set: { newValue in
                if newValue != resource.teamID {
                    resource.teamID = newValue
                    resource.isCustomTeam = true
                }
            }
        )
    }

    private var basisBinding: Binding<RateBasis> {
        Binding(
            get: { resource.rateBasis },
            set: { newValue in
                guard newValue != resource.rateBasis else { return }
                if resource.rate == 0 {
                    resource.rateBasis = newValue
                } else {
                    pendingBasis = newValue
                }
            }
        )
    }

    /// Edits to the rate field mark the resource as having a custom rate.
    private var rateBinding: Binding<Double?> {
        Binding<Double?>(
            get: { resource.rate == 0 ? nil : resource.rate },
            set: { newValue in
                let v = newValue ?? 0
                if v != resource.rate {
                    resource.rate = v
                    resource.isCustomRate = true
                }
            }
        )
    }

    // MARK: Helpers

    private var currentRole: Role? { currentRole(for: resource.roleID) }

    private func currentRole(for id: UUID?) -> Role? {
        guard let id else { return nil }
        return roles.first(where: { $0.id == id })
    }

    private var matchesDefault: Bool { resource.matchesRoleDefault(currentRole) }

    private var rateLabel: String {
        switch resource.rateBasis {
        case .hourly:  return "Hourly rate"
        case .monthly: return "Monthly rate"
        case .annual:  return "Annual rate"
        }
    }

    private func applyBasis(_ newBasis: RateBasis, convert: Bool) {
        if convert {
            let monthly = resource.monthlyCost
            switch newBasis {
            case .annual:  resource.rate = monthly * 12
            case .monthly: resource.rate = monthly
            case .hourly:  resource.rate = resource.hoursPerWeek > 0 ? monthly / (resource.hoursPerWeek * (52.0 / 12.0)) : 0
            }
        }
        resource.rateBasis = newBasis
        resource.isCustomRate = true
    }

    private func formattedRate(_ value: Double, basis: RateBasis) -> String {
        let s = value.formatted(.currency(code: resource.currencyCode).precision(.fractionLength(0...2)))
        return "\(s) \(basis.displayName.lowercased())"
    }

    private func formattedDefault(_ role: Role) -> String {
        let s = role.defaultRate.formatted(.currency(code: role.currencyCode).precision(.fractionLength(0...2)))
        return "\(s) \(role.defaultRateBasis.displayName.lowercased())"
    }

}

// MARK: - Resource allocation lookup

private struct ResourceAllocationEntry: Identifiable {
    let id: UUID  // allocation ID
    let initiativeName: String
    let assignmentName: String
    let icon: String
    let color: InitiativeColor
    let startDate: Date
    let endDate: Date
    let avgPercent: Double
}

private func resourceAllocations(resourceID: UUID, plan: Plan) -> [ResourceAllocationEntry] {
    var entries: [ResourceAllocationEntry] = []
    for assignment in plan.assignments {
        guard let initiative = plan.initiatives.first(where: { $0.id == assignment.initiativeID }) else { continue }
        for allocation in assignment.allocations where allocation.resourceID == resourceID {
            let values = allocation.months.values.filter { $0 > 0 }
            guard !values.isEmpty else { continue }
            let avg = values.reduce(0, +) / Double(values.count)
            entries.append(ResourceAllocationEntry(
                id: allocation.id,
                initiativeName: initiative.name.isEmpty ? "Untitled" : initiative.name,
                assignmentName: assignment.name.isEmpty ? "Untitled" : assignment.name,
                icon: initiative.icon,
                color: initiative.color,
                startDate: initiative.startDate,
                endDate: initiative.endDate,
                avgPercent: avg
            ))
        }
    }
    return entries
}

private struct NewRoleSheet: View {
    @Binding var name: String
    @FocusState private var focused: Bool
    let onClose: (_ commit: Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Role").font(.title2).bold()
            Text("Give the role a name. You can set its default rate from the Roles tab.")
                .font(.callout)
                .foregroundStyle(.secondary)
            TextField("e.g. Developer", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { commit() }
            HStack {
                Spacer()
                Button("Cancel") { onClose(false); dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create") { commit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onAppear { focused = true }
    }

    private func commit() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        onClose(true)
        dismiss()
    }
}
