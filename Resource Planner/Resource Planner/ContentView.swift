import SwiftUI

// MARK: - Sidebar model

enum SidebarCategory: Hashable, CaseIterable, Identifiable {
    case resources, teams, roles, programs, initiatives, planning, reports

    var id: Self { self }

    var title: String {
        switch self {
        case .resources:   return "Resources"
        case .teams:       return "Teams"
        case .roles:       return "Roles"
        case .programs:    return "Programs"
        case .initiatives: return "Initiatives"
        case .planning:    return "Planning"
        case .reports:     return "Reports"
        }
    }

    var systemImage: String {
        switch self {
        case .resources:   return "person.2.fill"
        case .teams:       return "person.3.fill"
        case .roles:       return "tag.fill"
        case .programs:    return "rectangle.stack.fill"
        case .initiatives: return "flag.fill"
        case .planning:    return "calendar"
        case .reports:     return "chart.bar.fill"
        }
    }

    var hidesDetailColumn: Bool {
        self == .planning || self == .reports
    }
}

enum SidebarSelection: Hashable {
    case resource(UUID)
    case role(UUID)
    case team(UUID)
    case program(UUID)
    case initiative(UUID)
}

struct ContentView: View {
    @Binding var document: Resource_PlannerDocument
    @State private var category: SidebarCategory? = .resources
    @State private var itemSelection: SidebarSelection?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showingNewRoleSheet = false
    @State private var newRoleName = ""
    @State private var showingSettings = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } content: {
            content
                .navigationSplitViewColumnWidth(min: 220, ideal: 300, max: 420)
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 1000, minHeight: 600)
        .onAppear { ensureBaselinePlan() }
        .onChange(of: category) { _, new in
            columnVisibility = (new?.hidesDetailColumn ?? false) ? .doubleColumn : .all
        }
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
                        category = .roles
                        itemSelection = .role(role.id)
                    }
                }
                newRoleName = ""
            }
        }
    }

    // MARK: Sidebar (categories only)

    private var sidebar: some View {
        List(selection: $category) {
            Section("Plan") {
                categoryRow(.resources)
                categoryRow(.teams)
                categoryRow(.roles)
                categoryRow(.programs)
                categoryRow(.initiatives)
            }
            Section {
                categoryRow(.planning)
                categoryRow(.reports)
            } header: {
                HStack {
                    Text("Views")
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
        .navigationTitle("Resource Planner")
    }

    private func categoryRow(_ cat: SidebarCategory) -> some View {
        Label(cat.title, systemImage: cat.systemImage).tag(cat)
    }

    // MARK: Content (middle column)

    @ViewBuilder
    private var content: some View {
        switch category {
        case .resources:   resourcesList
        case .teams:       teamsList
        case .roles:       rolesList
        case .programs:    programsList
        case .initiatives: initiativesList
        case .planning:    planningView
        case .reports:     reportsView
        case .none:
            ContentUnavailableView(
                "Select a category",
                systemImage: "sidebar.left",
                description: Text("Pick a category in the sidebar.")
            )
        }
    }

    private var resourcesList: some View {
        List(selection: $itemSelection) {
            ForEach(document.planner.resources) { r in
                ResourceRow(resource: r, role: roleName(r.roleID))
                    .tag(SidebarSelection.resource(r.id))
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            document.planner.resources.removeAll { $0.id == r.id }
                            if itemSelection == .resource(r.id) { itemSelection = nil }
                        }
                    }
            }
        }
        .overlay {
            if document.planner.resources.isEmpty {
                ContentUnavailableView("No Resources", systemImage: "person.2",
                                       description: Text("Click + to add a resource."))
            }
        }
        .navigationTitle("Resources")
        .toolbar {
            ToolbarItem {
                Button { addResource() } label: {
                    Label("New Resource", systemImage: "plus")
                }
                .help("New resource")
            }
        }
    }

    private var teamsList: some View {
        List(selection: $itemSelection) {
            ForEach(document.planner.teams) { team in
                TeamSidebarRow(team: team, count: teamMemberCount(team.id))
                    .tag(SidebarSelection.team(team.id))
                    .contextMenu {
                        Button("Delete", role: .destructive) { deleteTeam(team.id) }
                    }
            }
        }
        .overlay {
            if document.planner.teams.isEmpty {
                ContentUnavailableView("No Teams", systemImage: "person.3",
                                       description: Text("Click + to add a team."))
            }
        }
        .navigationTitle("Teams")
        .toolbar {
            ToolbarItem {
                Button { addTeam() } label: {
                    Label("New Team", systemImage: "plus")
                }
                .help("New team")
            }
        }
    }

    private var rolesList: some View {
        List(selection: $itemSelection) {
            ForEach(document.planner.roles) { role in
                RoleSidebarRow(role: role, count: usageCount(role.id))
                    .tag(SidebarSelection.role(role.id))
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            if usageCount(role.id) == 0 {
                                document.planner.roles.removeAll { $0.id == role.id }
                                if itemSelection == .role(role.id) { itemSelection = nil }
                            }
                        }
                        .disabled(usageCount(role.id) > 0)
                    }
            }
        }
        .overlay {
            if document.planner.roles.isEmpty {
                ContentUnavailableView("No Roles", systemImage: "tag",
                                       description: Text("Click + to add a role."))
            }
        }
        .navigationTitle("Roles")
        .toolbar {
            ToolbarItem {
                Button {
                    newRoleName = ""
                    showingNewRoleSheet = true
                } label: {
                    Label("New Role", systemImage: "plus")
                }
                .help("New role")
            }
        }
    }

    private var programsList: some View {
        List(selection: $itemSelection) {
            if let planIdx = baselinePlanIndex {
                ForEach(document.planner.plans[planIdx].programs) { program in
                    ProgramSidebarRow(program: program, count: programInitiativeCount(program.id))
                        .tag(SidebarSelection.program(program.id))
                        .contextMenu {
                            Button("Delete", role: .destructive) { deleteProgram(program.id) }
                        }
                }
            }
        }
        .overlay {
            if (baselinePlanIndex.map { document.planner.plans[$0].programs.isEmpty } ?? true) {
                ContentUnavailableView("No Programs", systemImage: "rectangle.stack",
                                       description: Text("Click + to add a program."))
            }
        }
        .navigationTitle("Programs")
        .toolbar {
            ToolbarItem {
                Button { addProgram() } label: {
                    Label("New Program", systemImage: "plus")
                }
                .help("New program")
            }
        }
    }

    private var initiativesList: some View {
        List(selection: $itemSelection) {
            if let planIdx = baselinePlanIndex {
                ForEach(document.planner.plans[planIdx].initiatives) { initiative in
                    InitiativeSidebarRow(initiative: initiative)
                        .tag(SidebarSelection.initiative(initiative.id))
                        .contextMenu {
                            Button("Delete", role: .destructive) { deleteInitiative(initiative.id) }
                        }
                }
            }
        }
        .overlay {
            if (baselinePlanIndex.map { document.planner.plans[$0].initiatives.isEmpty } ?? true) {
                ContentUnavailableView("No Initiatives", systemImage: "flag",
                                       description: Text("Click + to add an initiative."))
            }
        }
        .navigationTitle("Initiatives")
        .toolbar {
            ToolbarItem {
                Button { addInitiative() } label: {
                    Label("New Initiative", systemImage: "plus")
                }
                .help("New initiative")
            }
        }
    }

    @ViewBuilder
    private var planningView: some View {
        if let planIdx = baselinePlanIndex {
            PlanningGridView(
                plan: $document.planner.plans[planIdx],
                resources: $document.planner.resources,
                teams: document.planner.teams,
                roles: document.planner.roles
            )
        } else {
            emptyDetail
        }
    }

    @ViewBuilder
    private var reportsView: some View {
        if let planIdx = baselinePlanIndex {
            ReportsView(
                plan: $document.planner.plans[planIdx],
                resources: $document.planner.resources,
                roles: document.planner.roles,
                displayCurrency: document.planner.displayCurrency,
                conversionRates: document.planner.conversionRates
            )
        } else {
            emptyDetail
        }
    }

    // MARK: Detail (right column)
    //
    // We pair the active category with the item selection so a stale selection
    // (e.g. .resource left over after switching to Teams) doesn't render.

    @ViewBuilder
    private var detail: some View {
        switch (category, itemSelection) {
        case (.resources, .resource(let id)):
            if let idx = document.planner.resources.firstIndex(where: { $0.id == id }) {
                ResourceDetailView(
                    resource: $document.planner.resources[idx],
                    roles: $document.planner.roles,
                    teams: document.planner.teams,
                    plan: baselinePlanIndex.map { document.planner.plans[$0] },
                    displayCurrency: document.planner.displayCurrency
                )
            } else { emptyDetail }

        case (.roles, .role(let id)):
            if let idx = document.planner.roles.firstIndex(where: { $0.id == id }) {
                RoleDetailView(
                    role: $document.planner.roles[idx],
                    resources: $document.planner.resources,
                    teams: document.planner.teams,
                    onAddResource: { newID in
                        category = .resources
                        DispatchQueue.main.async { itemSelection = .resource(newID) }
                    }
                )
            } else { emptyDetail }

        case (.teams, .team(let id)):
            if let idx = document.planner.teams.firstIndex(where: { $0.id == id }) {
                TeamDetailView(
                    team: $document.planner.teams[idx],
                    resources: $document.planner.resources,
                    roles: document.planner.roles,
                    plan: baselinePlanIndex.map { document.planner.plans[$0] },
                    displayCurrency: document.planner.displayCurrency,
                    onSelectResource: { rid in
                        category = .resources
                        DispatchQueue.main.async { itemSelection = .resource(rid) }
                    }
                )
            } else { emptyDetail }

        case (.programs, .program(let id)):
            if let planIdx = baselinePlanIndex,
               let progIdx = document.planner.plans[planIdx].programs.firstIndex(where: { $0.id == id }) {
                ProgramDetailView(
                    program: $document.planner.plans[planIdx].programs[progIdx],
                    plan: $document.planner.plans[planIdx],
                    resources: document.planner.resources,
                    displayCurrency: document.planner.displayCurrency,
                    conversionRates: document.planner.conversionRates,
                    onSelectInitiative: { initiativeID in
                        category = .initiatives
                        DispatchQueue.main.async { itemSelection = .initiative(initiativeID) }
                    }
                )
            } else { emptyDetail }

        case (.initiatives, .initiative(let id)):
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

        default:
            emptyDetail
        }
    }

    private var emptyDetail: some View {
        ContentUnavailableView(
            "Nothing Selected",
            systemImage: "sidebar.right",
            description: Text("Pick an item from the list.")
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
            itemSelection = .resource(new.id)
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
            itemSelection = .initiative(new.id)
        }
    }

    private func addTeam() {
        let new = Team(name: "")
        DispatchQueue.main.async {
            document.planner.teams.append(new)
            itemSelection = .team(new.id)
        }
    }

    private func teamMemberCount(_ id: UUID) -> Int {
        document.planner.resources.filter { $0.teamID == id }.count
    }

    private func deleteTeam(_ id: UUID) {
        for i in document.planner.resources.indices where document.planner.resources[i].teamID == id {
            document.planner.resources[i].teamID = nil
            document.planner.resources[i].isCustomTeam = false
        }
        for i in document.planner.roles.indices where document.planner.roles[i].defaultTeamID == id {
            document.planner.roles[i].defaultTeamID = nil
        }
        document.planner.teams.removeAll { $0.id == id }
        if itemSelection == .team(id) { itemSelection = nil }
    }

    private func addProgram() {
        ensureBaselinePlan()
        let today = Date()
        let oneYearLater = Calendar.gregorianUTC.date(byAdding: .year, value: 1, to: today) ?? today
        let new = Program(name: "", startDate: today, endDate: oneYearLater)
        guard let planIdx = baselinePlanIndex else { return }
        DispatchQueue.main.async {
            document.planner.plans[planIdx].programs.append(new)
            itemSelection = .program(new.id)
        }
    }

    private func programInitiativeCount(_ id: UUID) -> Int {
        guard let planIdx = baselinePlanIndex else { return 0 }
        return document.planner.plans[planIdx].initiatives.filter { $0.programID == id }.count
    }

    private func deleteProgram(_ id: UUID) {
        guard let planIdx = baselinePlanIndex else { return }
        for i in document.planner.plans[planIdx].initiatives.indices
            where document.planner.plans[planIdx].initiatives[i].programID == id {
            document.planner.plans[planIdx].initiatives[i].programID = nil
        }
        document.planner.plans[planIdx].programs.removeAll { $0.id == id }
        if itemSelection == .program(id) { itemSelection = nil }
    }

    private func deleteInitiative(_ id: UUID) {
        guard let planIdx = baselinePlanIndex else { return }
        document.planner.plans[planIdx].initiatives.removeAll { $0.id == id }
        document.planner.plans[planIdx].assignments.removeAll { $0.initiativeID == id }
        if itemSelection == .initiative(id) { itemSelection = nil }
    }
}

// MARK: - Sidebar row views (used by middle-column lists)

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

/// Sheet to create a new role with a name. Used from the Roles list toolbar.
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
