import SwiftUI

enum SidebarSelection: Hashable {
    case resource(UUID)
    case role(UUID)
    case team(UUID)
    case program(UUID)
    case initiative(UUID)
    case planning
    case reports
}

struct ContentView: View {
    @Binding var document: Resource_PlannerDocument
    @State private var selection: SidebarSelection?
    @State private var showingNewRoleSheet = false
    @State private var newRoleName = ""
    @State private var showingSettings = false

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 360)
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 880, minHeight: 560)
        .onAppear { ensureBaselinePlan() }
        .sheet(isPresented: $showingSettings) {
            PlanSettingsView(document: $document.planner)
        }
        .sheet(isPresented: $showingNewRoleSheet) {
            NewRoleSheetView(name: $newRoleName) { commit in
                if commit {
                    let trimmed = newRoleName.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        let role = Role(name: trimmed)
                        document.planner.roles.append(role)
                        selection = .role(role.id)
                    }
                }
                newRoleName = ""
            }
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            Section {
                ForEach(document.planner.resources) { r in
                    ResourceRow(resource: r, role: roleName(r.roleID))
                        .tag(SidebarSelection.resource(r.id))
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                document.planner.resources.removeAll { $0.id == r.id }
                                if selection == .resource(r.id) { selection = nil }
                            }
                        }
                }
                if document.planner.resources.isEmpty {
                    Text("No resources yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                sectionHeader(title: "Resources", systemImage: "person.2.fill", help: "New resource") {
                    addResource()
                }
            }

            Section {
                ForEach(document.planner.roles) { role in
                    RoleSidebarRow(role: role, count: usageCount(role.id))
                        .tag(SidebarSelection.role(role.id))
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                if usageCount(role.id) == 0 {
                                    document.planner.roles.removeAll { $0.id == role.id }
                                    if selection == .role(role.id) { selection = nil }
                                }
                            }
                            .disabled(usageCount(role.id) > 0)
                        }
                }
                if document.planner.roles.isEmpty {
                    Text("No roles yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                sectionHeader(title: "Roles", systemImage: "tag.fill", help: "New role") {
                    DispatchQueue.main.async {
                        newRoleName = ""
                        showingNewRoleSheet = true
                    }
                }
            }

            Section {
                ForEach(document.planner.teams) { team in
                    TeamSidebarRow(team: team, count: teamMemberCount(team.id))
                        .tag(SidebarSelection.team(team.id))
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                deleteTeam(team.id)
                            }
                        }
                }
                if document.planner.teams.isEmpty {
                    Text("No teams yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                sectionHeader(title: "Teams", systemImage: "person.3.fill", help: "New team") {
                    addTeam()
                }
            }

            Section {
                if let planIdx = baselinePlanIndex {
                    ForEach(document.planner.plans[planIdx].programs) { program in
                        ProgramSidebarRow(program: program, count: programInitiativeCount(program.id))
                            .tag(SidebarSelection.program(program.id))
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    deleteProgram(program.id)
                                }
                            }
                    }
                    if document.planner.plans[planIdx].programs.isEmpty {
                        Text("No programs yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No programs yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                sectionHeader(title: "Programs", systemImage: "rectangle.stack.fill", help: "New program") {
                    addProgram()
                }
            }

            Section {
                if let planIdx = baselinePlanIndex {
                    ForEach(document.planner.plans[planIdx].initiatives) { initiative in
                        InitiativeSidebarRow(initiative: initiative)
                            .tag(SidebarSelection.initiative(initiative.id))
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    deleteInitiative(initiative.id)
                                }
                            }
                    }
                    if document.planner.plans[planIdx].initiatives.isEmpty {
                        Text("No initiatives yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No initiatives yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                sectionHeader(title: "Initiatives", systemImage: "flag.fill", help: "New initiative") {
                    addInitiative()
                }
            }

            Section {
                Label("Planning", systemImage: "calendar")
                    .tag(SidebarSelection.planning)
                Label("Reports", systemImage: "chart.bar.fill")
                    .tag(SidebarSelection.reports)
            } header: {
                HStack {
                    Label("Plans", systemImage: "folder.fill")
                    Spacer()
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(.borderless)
                    .help("Document settings")
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func sectionHeader(title: String, systemImage: String, help: String, action: @escaping () -> Void) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Button(action: action) {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help(help)
        }
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .resource(let id):
            if let idx = document.planner.resources.firstIndex(where: { $0.id == id }) {
                ResourceDetailView(
                    resource: $document.planner.resources[idx],
                    roles: $document.planner.roles,
                    teams: document.planner.teams,
                    plan: baselinePlanIndex.map { document.planner.plans[$0] },
                    displayCurrency: document.planner.displayCurrency
                )
            } else { emptyDetail }

        case .role(let id):
            if let idx = document.planner.roles.firstIndex(where: { $0.id == id }) {
                RoleDetailView(
                    role: $document.planner.roles[idx],
                    resources: $document.planner.resources,
                    teams: document.planner.teams,
                    onAddResource: { newID in
                        selection = .resource(newID)
                    }
                )
            } else { emptyDetail }

        case .team(let id):
            if let idx = document.planner.teams.firstIndex(where: { $0.id == id }) {
                TeamDetailView(
                    team: $document.planner.teams[idx],
                    resources: $document.planner.resources,
                    roles: document.planner.roles,
                    plan: baselinePlanIndex.map { document.planner.plans[$0] },
                    displayCurrency: document.planner.displayCurrency,
                    onSelectResource: { rid in selection = .resource(rid) }
                )
            } else { emptyDetail }

        case .program(let id):
            if let planIdx = baselinePlanIndex,
               let progIdx = document.planner.plans[planIdx].programs.firstIndex(where: { $0.id == id }) {
                ProgramDetailView(
                    program: $document.planner.plans[planIdx].programs[progIdx],
                    plan: $document.planner.plans[planIdx],
                    resources: document.planner.resources,
                    displayCurrency: document.planner.displayCurrency,
                    conversionRates: document.planner.conversionRates,
                    onSelectInitiative: { initiativeID in
                        selection = .initiative(initiativeID)
                    }
                )
            } else { emptyDetail }

        case .initiative(let id):
            if let planIdx = document.planner.plans.firstIndex(where: { $0.initiatives.contains(where: { $0.id == id }) }),
               let initIdx = document.planner.plans[planIdx].initiatives.firstIndex(where: { $0.id == id }) {
                InitiativeDetailView(
                    initiative: $document.planner.plans[planIdx].initiatives[initIdx],
                    plan: document.planner.plans[planIdx],
                    resources: document.planner.resources,
                    roles: document.planner.roles,
                    displayCurrency: document.planner.displayCurrency,
                    conversionRates: document.planner.conversionRates
                )
            } else { emptyDetail }

        case .planning:
            if let planIdx = baselinePlanIndex {
                PlanningGridView(
                    plan: $document.planner.plans[planIdx],
                    resources: $document.planner.resources
                )
            } else { emptyDetail }

        case .reports:
            if let planIdx = baselinePlanIndex {
                ReportsView(
                    plan: $document.planner.plans[planIdx],
                    resources: $document.planner.resources,
                    roles: document.planner.roles,
                    displayCurrency: document.planner.displayCurrency,
                    conversionRates: document.planner.conversionRates
                )
            } else { emptyDetail }

        case .none:
            emptyDetail
        }
    }

    private var emptyDetail: some View {
        ContentUnavailableView(
            "Nothing Selected",
            systemImage: "sidebar.left",
            description: Text("Pick a resource, role, or section from the sidebar.")
        )
    }

    // MARK: Helpers

    private var baselinePlanIndex: Int? {
        document.planner.plans.firstIndex(where: { $0.name == "Baseline" })
    }

    private func ensureBaselinePlan() {
        if !document.planner.plans.contains(where: { $0.name == "Baseline" }) {
            document.planner.plans.append(Plan(name: "Baseline"))
        }
    }

    private func roleName(_ id: UUID?) -> String? {
        guard let id else { return nil }
        return document.planner.roles.first(where: { $0.id == id })?.name
    }

    private func usageCount(_ id: UUID) -> Int {
        document.planner.resources.filter { $0.roleID == id }.count
    }

    private func addResource() {
        let new = Resource(name: "")
        DispatchQueue.main.async {
            document.planner.resources.append(new)
            selection = .resource(new.id)
        }
    }

    private func addInitiative() {
        ensureBaselinePlan()
        let today = Date()
        let fourWeeksLater = Calendar.gregorianUTC.date(byAdding: .weekOfYear, value: 4, to: today) ?? today
        let new = Initiative(name: "", startDate: today, endDate: fourWeeksLater)
        guard let planIdx = baselinePlanIndex else { return }
        DispatchQueue.main.async {
            document.planner.plans[planIdx].initiatives.append(new)
            selection = .initiative(new.id)
        }
    }

    private func addTeam() {
        let new = Team(name: "")
        DispatchQueue.main.async {
            document.planner.teams.append(new)
            selection = .team(new.id)
        }
    }

    private func teamMemberCount(_ id: UUID) -> Int {
        document.planner.resources.filter { $0.teamID == id }.count
    }

    private func deleteTeam(_ id: UUID) {
        // Detach members
        for i in document.planner.resources.indices where document.planner.resources[i].teamID == id {
            document.planner.resources[i].teamID = nil
            document.planner.resources[i].isCustomTeam = false
        }
        // Clear from roles' defaults
        for i in document.planner.roles.indices where document.planner.roles[i].defaultTeamID == id {
            document.planner.roles[i].defaultTeamID = nil
        }
        document.planner.teams.removeAll { $0.id == id }
        if selection == .team(id) { selection = nil }
    }

    private func addProgram() {
        ensureBaselinePlan()
        let today = Date()
        let oneYearLater = Calendar.gregorianUTC.date(byAdding: .year, value: 1, to: today) ?? today
        let new = Program(name: "", startDate: today, endDate: oneYearLater)
        guard let planIdx = baselinePlanIndex else { return }
        DispatchQueue.main.async {
            document.planner.plans[planIdx].programs.append(new)
            selection = .program(new.id)
        }
    }

    private func programInitiativeCount(_ id: UUID) -> Int {
        guard let planIdx = baselinePlanIndex else { return 0 }
        return document.planner.plans[planIdx].initiatives.filter { $0.programID == id }.count
    }

    private func deleteProgram(_ id: UUID) {
        guard let planIdx = baselinePlanIndex else { return }
        // Detach any member initiatives — keep them but unset their programID.
        for i in document.planner.plans[planIdx].initiatives.indices
            where document.planner.plans[planIdx].initiatives[i].programID == id {
            document.planner.plans[planIdx].initiatives[i].programID = nil
        }
        document.planner.plans[planIdx].programs.removeAll { $0.id == id }
        if selection == .program(id) { selection = nil }
    }

    private func deleteInitiative(_ id: UUID) {
        guard let planIdx = baselinePlanIndex else { return }
        document.planner.plans[planIdx].initiatives.removeAll { $0.id == id }
        // Clean up assignments that reference this initiative
        document.planner.plans[planIdx].assignments.removeAll { $0.initiativeID == id }
        if selection == .initiative(id) { selection = nil }
    }
}

private struct RoleSidebarRow: View {
    let role: Role
    let count: Int
    var body: some View {
        HStack {
            Image(systemName: "tag.fill")
                .foregroundStyle(.purple)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(role.name.isEmpty ? "Untitled role" : role.name)
                    .foregroundStyle(role.name.isEmpty ? .secondary : .primary)
                Text("\(count) \(count == 1 ? "resource" : "resources")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct TeamSidebarRow: View {
    let team: Team
    let count: Int

    var body: some View {
        HStack {
            Image(systemName: team.icon)
                .foregroundStyle(team.color.swiftUIColor)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(team.name.isEmpty ? "Untitled team" : team.name)
                    .foregroundStyle(team.name.isEmpty ? .secondary : .primary)
                Text("\(count) \(count == 1 ? "member" : "members")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct ProgramSidebarRow: View {
    let program: Program
    let count: Int

    var body: some View {
        HStack {
            Image(systemName: program.icon)
                .foregroundStyle(program.color.swiftUIColor)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(program.name.isEmpty ? "Untitled program" : program.name)
                    .foregroundStyle(program.name.isEmpty ? .secondary : .primary)
                Text("\(count) \(count == 1 ? "initiative" : "initiatives")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct InitiativeSidebarRow: View {
    let initiative: Initiative

    var body: some View {
        HStack {
            Image(systemName: initiative.icon)
                .foregroundStyle(initiative.color.swiftUIColor)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(initiative.name.isEmpty ? "Untitled initiative" : initiative.name)
                    .foregroundStyle(initiative.name.isEmpty ? .secondary : .primary)
                Text(dateRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var dateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(formatter.string(from: initiative.startDate)) – \(formatter.string(from: initiative.endDate))"
    }
}

/// Sheet to create a new role with a name. Used from the sidebar header + button.
struct NewRoleSheetView: View {
    @Binding var name: String
    let onClose: (_ commit: Bool) -> Void
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Role").font(.title2).bold()
            Text("Give the role a name. You can set its default rate from the role's detail panel.")
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

#Preview {
    ContentView(document: .constant(Resource_PlannerDocument()))
}
