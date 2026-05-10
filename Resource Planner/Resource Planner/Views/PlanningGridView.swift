import SwiftUI

// MARK: - Grid row model

enum GridRowKind {
    case initiative(Initiative)
    case assignment(Assignment)
    case allocation(assignmentID: UUID, allocationID: UUID)
}

struct PlanningRow: Identifiable {
    let id: String
    let kind: GridRowKind
    let indentLevel: Int
}

// MARK: - Constants

private let defaultFrozenColumnWidth: CGFloat = 120
private let minFrozenColumnWidth: CGFloat = 80
private let maxFrozenColumnWidth: CGFloat = 300
private let monthlyCellWidth: CGFloat = 62
private let rowHeight: CGFloat = 28

// MARK: - PlanningGridView

struct PlanningGridView: View {
    @Binding var plan: Plan
    @Binding var resources: [Resource]

    @State private var rangeStart: Date = Date()
    @State private var rangeEnd: Date = Calendar.gregorianUTC.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var showingNewAssignment = false
    @SceneStorage("planningGridFrozenColumnWidth") private var persistedColumnWidth: Double = Double(defaultFrozenColumnWidth)
    @State private var liveColumnWidth: Double = Double(defaultFrozenColumnWidth)
    @GestureState private var dragOffset: CGFloat = 0
    @State private var userHasManuallyResized: Bool = false
    @State private var collapsedInitiatives: Set<UUID> = []
    @State private var collapsedAssignments: Set<UUID> = []
    @State private var addingResourceToAssignment: UUID? = nil

    var body: some View {
        VStack(spacing: 0) {
            gridToolbar
            Divider()
            gridBody
        }
        .navigationTitle("Planning")
        .onAppear {
            fitToInitiatives()
            liveColumnWidth = persistedColumnWidth
            autoFitColumnWidthIfNeeded()
        }
        .onChange(of: plan.initiatives.count) { _, _ in autoFitColumnWidthIfNeeded() }
        .onChange(of: plan.assignments.count) { _, _ in autoFitColumnWidthIfNeeded() }
        .sheet(isPresented: $showingNewAssignment) {
            NewAssignmentSheetView(
                initiatives: plan.initiatives,
                resources: resources
            ) { name, initiativeID, resourceIDs in
                let allocations = resourceIDs.map { Allocation(resourceID: $0) }
                let assignment = Assignment(name: name, initiativeID: initiativeID, allocations: allocations)
                plan.assignments.append(assignment)
            }
        }

    }

    // MARK: - Computed columns

    private var monthKeys: [MonthKey] {
        var keys: [MonthKey] = []
        var current = rangeStart
        let cal = Calendar.gregorianUTC
        while current <= rangeEnd {
            let mk = MonthKey.from(date: current, calendar: cal)
            if !keys.contains(mk) { keys.append(mk) }
            current = cal.date(byAdding: .month, value: 1, to: current) ?? rangeEnd.addingTimeInterval(1)
        }
        return keys
    }

    private var effectiveColumnWidth: CGFloat {
        let raw = CGFloat(liveColumnWidth) + dragOffset
        return min(max(raw, minFrozenColumnWidth), maxFrozenColumnWidth)
    }

    private var gridContentWidth: CGFloat {
        CGFloat(monthKeys.count) * monthlyCellWidth
    }

    // MARK: - Grid rows

    private var gridRows: [PlanningRow] {
        var rows: [PlanningRow] = []
        for initiative in plan.initiatives {
            rows.append(PlanningRow(id: "init-\(initiative.id)", kind: .initiative(initiative), indentLevel: 0))
            guard !collapsedInitiatives.contains(initiative.id) else { continue }
            let initAssignments = plan.assignments.filter { $0.initiativeID == initiative.id }
            for assignment in initAssignments {
                rows.append(PlanningRow(id: "assign-\(assignment.id)", kind: .assignment(assignment), indentLevel: 1))
                guard !collapsedAssignments.contains(assignment.id) else { continue }
                for allocation in assignment.allocations {
                    rows.append(PlanningRow(
                        id: "alloc-\(allocation.id)",
                        kind: .allocation(assignmentID: assignment.id, allocationID: allocation.id),
                        indentLevel: 2
                    ))
                }
            }
        }
        return rows
    }

    // MARK: - Toolbar

    private var gridToolbar: some View {
        HStack(spacing: 16) {
            DatePicker("From", selection: $rangeStart, displayedComponents: .date)
                .frame(width: 200)
            DatePicker("To", selection: $rangeEnd, in: rangeStart..., displayedComponents: .date)
                .frame(width: 200)

            Button {
                fitToInitiatives()
            } label: {
                Label("Fit to initiatives", systemImage: "arrow.left.and.right.square")
            }
            .help("Set range to cover all initiative dates")

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    collapsedInitiatives = Set(plan.initiatives.map(\.id))
                    collapsedAssignments = Set(plan.assignments.map(\.id))
                }
            } label: {
                Label("Collapse All", systemImage: "rectangle.compress.vertical")
            }
            .help("Collapse all rows")

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    collapsedInitiatives.removeAll()
                    collapsedAssignments.removeAll()
                }
            } label: {
                Label("Expand All", systemImage: "rectangle.expand.vertical")
            }
            .help("Expand all rows")

            Spacer()

            Button {
                showingNewAssignment = true
            } label: {
                Label("New Assignment", systemImage: "plus")
            }
            .disabled(plan.initiatives.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Grid body (single horizontal scroll for alignment)

    private var gridBody: some View {
        HStack(alignment: .top, spacing: 0) {
            // Frozen left column — pinned to exact width
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Corner header
                    Text("Assignment / Resource")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: rowHeight)
                        .padding(.leading, 4)
                        .background(Color(nsColor: .controlBackgroundColor))
                    Divider()

                    // Row labels
                    ForEach(gridRows) { row in
                        rowLabel(row)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: rowHeight)
                        Divider()
                    }

                    // Capacity header
                    if !allocatedResourceIDs.isEmpty {
                        Text("Remaining Capacity")
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: rowHeight)
                            .padding(.leading, 4)
                            .background(Color(nsColor: .controlBackgroundColor))
                        Divider()

                        ForEach(allocatedResources) { resource in
                            HStack(spacing: 4) {
                                Spacer().frame(width: 4)
                                Image(systemName: "person.fill").foregroundStyle(.secondary).frame(width: 14)
                                Text(resource.name.isEmpty ? "Untitled" : resource.name)
                                    .font(.caption.bold())
                                    .lineLimit(1)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: rowHeight)
                            Divider()
                        }
                    }

                    if gridRows.isEmpty {
                        Spacer().frame(height: 200)
                    }
                }
            }
            .frame(width: effectiveColumnWidth)
            .clipped()
            .padding(.leading, 4)

            // Draggable divider
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 1)
                .overlay {
                    Color.clear
                        .frame(width: 8)
                        .contentShape(Rectangle())
                        .pointerStyle(.columnResize)
                        .onTapGesture(count: 2) {
                            userHasManuallyResized = false
                            autoFitColumnWidthIfNeeded()
                        }
                        .gesture(
                            DragGesture(minimumDistance: 1)
                                .updating($dragOffset) { value, state, _ in
                                    state = value.translation.width
                                }
                                .onEnded { value in
                                    let newWidth = CGFloat(liveColumnWidth) + value.translation.width
                                    let clamped = Double(min(max(newWidth, minFrozenColumnWidth), maxFrozenColumnWidth))
                                    liveColumnWidth = clamped
                                    persistedColumnWidth = clamped
                                    userHasManuallyResized = true
                                }
                        )
                }

            // Scrollable right area — fills all remaining space
            ScrollView(.vertical, showsIndicators: false) {
                ScrollView(.horizontal, showsIndicators: true) {
                    VStack(spacing: 0) {
                        // Column headers
                        columnHeaders
                        Divider()

                        // Data rows
                        ForEach(gridRows) { row in
                            rowCells(row)
                            Divider()
                        }

                        // Capacity rows
                        if !allocatedResourceIDs.isEmpty {
                            // Capacity section header (blank cells row)
                            Color.clear.frame(width: gridContentWidth, height: rowHeight)
                            Divider()

                            ForEach(allocatedResources) { resource in
                                capacityRow(resource)
                                Divider()
                            }
                        }

                        if gridRows.isEmpty {
                            ContentUnavailableView(
                                "No Initiatives",
                                systemImage: "flag",
                                description: Text("Add initiatives from the sidebar, then create assignments here.")
                            )
                            .frame(width: gridContentWidth, height: 200)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Column headers

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            ForEach(monthKeys, id: \.self) { mk in
                Text(mk.shortLabel)
                    .font(.caption2.bold())
                    .frame(width: monthlyCellWidth, height: rowHeight)
                    .background(Color(nsColor: .controlBackgroundColor))
            }
        }
    }

    // MARK: - Row label

    private func disclosureChevron(isExpanded: Bool) -> some View {
        Image(systemName: "chevron.right")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
            .animation(.easeInOut(duration: 0.15), value: isExpanded)
            .frame(width: 10)
    }

    @ViewBuilder
    private func rowLabel(_ row: PlanningRow) -> some View {
        HStack(spacing: 4) {
            Spacer().frame(width: CGFloat(row.indentLevel) * 12 + 4)
            switch row.kind {
            case .initiative(let initiative):
                let isExpanded = !collapsedInitiatives.contains(initiative.id)
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        if isExpanded {
                            collapsedInitiatives.insert(initiative.id)
                        } else {
                            collapsedInitiatives.remove(initiative.id)
                        }
                    }
                } label: {
                    disclosureChevron(isExpanded: isExpanded)
                }
                .buttonStyle(.borderless)
                Image(systemName: initiative.icon).foregroundStyle(initiative.color.swiftUIColor).frame(width: 14)
                Text(initiative.name.isEmpty ? "Untitled initiative" : initiative.name)
                    .font(.caption.bold())
                    .lineLimit(1)
                Spacer()
                Button {
                    addAssignment(to: initiative.id)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Add assignment")
            case .assignment(let assignment):
                if let binding = assignmentNameBinding(assignment.id) {
                    let isExpanded = !collapsedAssignments.contains(assignment.id)
                    let hasAllocations = !assignment.allocations.isEmpty
                    if hasAllocations {
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if isExpanded {
                                    collapsedAssignments.insert(assignment.id)
                                } else {
                                    collapsedAssignments.remove(assignment.id)
                                }
                            }
                        } label: {
                            disclosureChevron(isExpanded: isExpanded)
                        }
                        .buttonStyle(.borderless)
                    } else {
                        Spacer().frame(width: 10)
                    }
                    Image(systemName: "doc.text.fill").foregroundStyle(.blue).frame(width: 14)
                    TextField("Assignment name", text: binding)
                        .font(.caption)
                        .textFieldStyle(.plain)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        addingResourceToAssignment = assignment.id
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("Add resource")
                    .popover(isPresented: Binding(
                        get: { addingResourceToAssignment == assignment.id },
                        set: { if !$0 { addingResourceToAssignment = nil } }
                    )) {
                        ResourcePickerPopover(
                            resources: resources,
                            excludedIDs: Set(assignment.allocations.map(\.resourceID))
                        ) { resourceID in
                            addAllocation(resourceID: resourceID, toAssignment: assignment.id)
                            addingResourceToAssignment = nil
                        }
                    }
                    Button {
                        deleteAssignment(assignment.id)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("Delete assignment")
                }
            case .allocation(let assignmentID, let allocationID):
                let resourceName = allocationResourceName(allocationID)
                Spacer().frame(width: 10) // aligns with chevron in parent rows
                Image(systemName: "person.fill").foregroundStyle(.secondary).frame(width: 14)
                Text(resourceName.isEmpty ? "Untitled" : resourceName)
                    .font(.caption)
                    .lineLimit(1)
                Spacer()
                Button {
                    removeAllocation(allocationID: allocationID, fromAssignment: assignmentID)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Remove resource from assignment")
            }
        }.padding(.trailing, 8)
        .contextMenu { rowContextMenu(row) }
    }

    @ViewBuilder
    private func rowContextMenu(_ row: PlanningRow) -> some View {
        switch row.kind {
        case .assignment(let assignment):
            Button("Delete Assignment", role: .destructive) {
                deleteAssignment(assignment.id)
            }
        case .allocation(let assignmentID, let allocationID):
            Button("Remove Resource from Assignment", role: .destructive) {
                removeAllocation(allocationID: allocationID, fromAssignment: assignmentID)
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Row cells

    private func rowCells(_ row: PlanningRow) -> some View {
        HStack(spacing: 0) {
            switch row.kind {
            case .initiative(let initiative):
                ForEach(monthKeys, id: \.self) { mk in
                    initiativeCell(initiative: initiative, monthKey: mk)
                }

            case .assignment(let assignment):
                let initiative = plan.initiatives.first(where: { $0.id == assignment.initiativeID })
                ForEach(monthKeys, id: \.self) { mk in
                    let hasData = assignment.allocations.contains { ($0.months[mk] ?? 0) > 0 }
                    Rectangle()
                        .fill(hasData ? (initiative?.color.swiftUIColor ?? .gray).opacity(0.10) : Color(nsColor: .controlBackgroundColor).opacity(0.5))
                        .frame(width: monthlyCellWidth, height: rowHeight)
                        .border(.quaternary, width: 0.5)
                }

            case .allocation(let assignmentID, let allocationID):
                let initiative = initiativeForAssignment(assignmentID)
                ForEach(Array(monthKeys.enumerated()), id: \.element) { idx, mk in
                    if let binding = allocationBinding(assignmentID: assignmentID, allocationID: allocationID) {
                        MonthlyGridCell(
                            allocation: binding,
                            monthKey: mk,
                            tintColor: initiative?.color.swiftUIColor,
                            columnIndex: idx,
                            onDragFill: { sourceCol, delta, phase in
                                handleDragFill(
                                    assignmentID: assignmentID,
                                    allocationID: allocationID,
                                    sourceCol: sourceCol,
                                    delta: delta,
                                    phase: phase
                                )
                            }
                        )
                    } else {
                        Color.clear.frame(width: monthlyCellWidth, height: rowHeight)
                    }
                }
            }
        }
        .coordinateSpace(name: "planningRow")
        .contextMenu { allocationContextMenu(row: row) }
    }

    @ViewBuilder
    private func allocationContextMenu(row: PlanningRow) -> some View {
        if case let .allocation(assignmentID, allocationID) = row.kind {
            Button("Fill across row from first non-zero cell") {
                fillRowFromFirstValue(assignmentID: assignmentID, allocationID: allocationID)
            }
            Button("Clear row", role: .destructive) {
                clearAllocationRow(assignmentID: assignmentID, allocationID: allocationID)
            }
        }
    }

    private func handleDragFill(
        assignmentID: UUID,
        allocationID: UUID,
        sourceCol: Int,
        delta: Int,
        phase: DragFillPhase
    ) {
        guard delta != 0 else { return }
        guard let binding = allocationBinding(assignmentID: assignmentID, allocationID: allocationID) else { return }
        let keys = monthKeys
        guard sourceCol >= 0, sourceCol < keys.count else { return }
        let sourceKey = keys[sourceCol]
        let value = binding.wrappedValue.months[sourceKey] ?? 0
        guard value > 0 else { return }
        let lo = max(0, min(sourceCol, sourceCol + delta))
        let hi = min(keys.count - 1, max(sourceCol, sourceCol + delta))
        // Apply on every change so users see the fill happen live; .ended is a no-op.
        guard phase == .changed else { return }
        for i in lo...hi where i != sourceCol {
            binding.wrappedValue.months[keys[i]] = value
        }
    }

    private func fillRowFromFirstValue(assignmentID: UUID, allocationID: UUID) {
        guard let binding = allocationBinding(assignmentID: assignmentID, allocationID: allocationID) else { return }
        let keys = monthKeys
        guard let firstFilled = keys.first(where: { (binding.wrappedValue.months[$0] ?? 0) > 0 }),
              let value = binding.wrappedValue.months[firstFilled], value > 0 else { return }
        for k in keys {
            binding.wrappedValue.months[k] = value
        }
    }

    private func clearAllocationRow(assignmentID: UUID, allocationID: UUID) {
        guard let binding = allocationBinding(assignmentID: assignmentID, allocationID: allocationID) else { return }
        for k in monthKeys {
            binding.wrappedValue.months.removeValue(forKey: k)
        }
    }

    private func initiativeCell(initiative: Initiative, monthKey: MonthKey) -> some View {
        let inRange = isMonthInInitiativeRange(monthKey, initiative: initiative)
        let color = initiative.color.swiftUIColor

        return ZStack {
            if inRange {
                color.opacity(0.18)
            } else {
                Color(nsColor: .controlBackgroundColor).opacity(0.5)
            }
        }
        .frame(width: monthlyCellWidth, height: rowHeight)
        .border(.quaternary, width: 0.5)
    }

    private func isMonthInInitiativeRange(_ mk: MonthKey, initiative: Initiative?) -> Bool {
        guard let initiative else { return false }
        let cal = Calendar.gregorianUTC
        let startMK = MonthKey.from(date: initiative.startDate, calendar: cal)
        let endMK = MonthKey.from(date: initiative.endDate, calendar: cal)
        return mk >= startMK && mk <= endMK
    }

    private func initiativeForAssignment(_ assignmentID: UUID) -> Initiative? {
        guard let assignment = plan.assignments.first(where: { $0.id == assignmentID }) else { return nil }
        return plan.initiatives.first(where: { $0.id == assignment.initiativeID })
    }

    // MARK: - Capacity row

    private func capacityRow(_ resource: Resource) -> some View {
        HStack(spacing: 0) {
            ForEach(monthKeys, id: \.self) { mk in
                let alloc = plan.monthAllocation(for: resource.id, in: mk)
                capacityCell(allocated: alloc, width: monthlyCellWidth)
            }
        }
    }

    private func capacityCell(allocated: Double, width: CGFloat) -> some View {
        let free = 100 - Int(round(allocated * 100))
        let capacityColor: Color = allocated == 0 ? .clear : allocated > 0.8 ? .red : allocated > 0.5 ? .yellow : .green
        let capacityBG: Color = allocated == 0 ? .clear : allocated > 0.8 ? .red.opacity(0.10) : allocated > 0.5 ? .yellow.opacity(0.08) : .green.opacity(0.08)
        return Text(allocated == 0 ? "" : "\(free)%")
            .font(.caption2.monospacedDigit())
            .foregroundStyle(allocated == 0 ? .secondary : capacityColor)
            .frame(width: width, height: rowHeight)
            .background(capacityBG)
            .border(.quaternary, width: 0.5)
    }

    // MARK: - Helpers

    private var allocatedResourceIDs: Set<UUID> {
        var ids = Set<UUID>()
        for assignment in plan.assignments {
            for allocation in assignment.allocations {
                ids.insert(allocation.resourceID)
            }
        }
        return ids
    }

    private var allocatedResources: [Resource] {
        let ids = allocatedResourceIDs
        return resources
            .filter { ids.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func computeIdealColumnWidth() -> CGFloat {
        var maxChars = "Assignment / Resource".count

        for initiative in plan.initiatives {
            let name = initiative.name.isEmpty ? "Untitled initiative" : initiative.name
            maxChars = max(maxChars, name.count)
        }

        for assignment in plan.assignments {
            let name = assignment.name.isEmpty ? "Assignment name" : assignment.name
            maxChars = max(maxChars, name.count + 2) // indent offset
        }

        for assignment in plan.assignments {
            for allocation in assignment.allocations {
                let name = resources.first(where: { $0.id == allocation.resourceID })?.name ?? "Unknown"
                let displayName = name.isEmpty ? "Untitled" : name
                maxChars = max(maxChars, displayName.count + 4) // double indent offset
            }
        }

        let clampedChars = min(maxChars, 50)
        // ~6.5pt per character in caption font + overhead for icons, chevrons, buttons
        let estimatedWidth = CGFloat(clampedChars) * 6.5 + 56
        return min(max(estimatedWidth, minFrozenColumnWidth), maxFrozenColumnWidth)
    }

    private func autoFitColumnWidthIfNeeded() {
        guard !userHasManuallyResized else { return }
        let ideal = Double(computeIdealColumnWidth())
        liveColumnWidth = ideal
        persistedColumnWidth = ideal
    }

    private func fitToInitiatives() {
        guard !plan.initiatives.isEmpty else { return }
        let starts = plan.initiatives.map(\.startDate)
        let ends = plan.initiatives.map(\.endDate)
        if let earliest = starts.min(), let latest = ends.max() {
            rangeStart = earliest
            rangeEnd = latest
        }
    }

    private func allocationResourceName(_ allocationID: UUID) -> String {
        for assignment in plan.assignments {
            if let alloc = assignment.allocations.first(where: { $0.id == allocationID }) {
                return resources.first(where: { $0.id == alloc.resourceID })?.name ?? "Unknown"
            }
        }
        return "Unknown"
    }

    private func assignmentNameBinding(_ assignmentID: UUID) -> Binding<String>? {
        guard let ai = plan.assignments.firstIndex(where: { $0.id == assignmentID }) else { return nil }
        return $plan.assignments[ai].name
    }

    private func deleteAssignment(_ assignmentID: UUID) {
        plan.assignments.removeAll { $0.id == assignmentID }
    }

    private func removeAllocation(allocationID: UUID, fromAssignment assignmentID: UUID) {
        guard let ai = plan.assignments.firstIndex(where: { $0.id == assignmentID }) else { return }
        plan.assignments[ai].allocations.removeAll { $0.id == allocationID }
    }

    private func allocationBinding(assignmentID: UUID, allocationID: UUID) -> Binding<Allocation>? {
        guard let ai = plan.assignments.firstIndex(where: { $0.id == assignmentID }),
              let li = plan.assignments[ai].allocations.firstIndex(where: { $0.id == allocationID }) else {
            return nil
        }
        return $plan.assignments[ai].allocations[li]
    }

    private func addAssignment(to initiativeID: UUID) {
        let assignment = Assignment(name: "", initiativeID: initiativeID, allocations: [])
        plan.assignments.append(assignment)
    }

    private func addAllocation(resourceID: UUID, toAssignment assignmentID: UUID) {
        guard let ai = plan.assignments.firstIndex(where: { $0.id == assignmentID }) else { return }
        let allocation = Allocation(resourceID: resourceID)
        plan.assignments[ai].allocations.append(allocation)
    }
}

// MARK: - Resource picker popover

private struct ResourcePickerPopover: View {
    let resources: [Resource]
    let excludedIDs: Set<UUID>
    let onSelect: (UUID) -> Void

    private var availableResources: [Resource] {
        resources.filter { !excludedIDs.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Add Resource").font(.caption.bold())
            if availableResources.isEmpty {
                Text("All resources already assigned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                List {
                    ForEach(availableResources) { resource in
                        Button {
                            onSelect(resource.id)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 14)
                                Text(resource.name.isEmpty ? "Untitled" : resource.name)
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
                .frame(height: min(CGFloat(availableResources.count) * 24, 150))
            }
        }
        .padding(8)
        .frame(width: 200)
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State var plan: Plan = {
            let cal = Calendar.gregorianUTC
            let now = Date()
            let threeMonths = cal.date(byAdding: .month, value: 3, to: now)!

            let resourceID1 = UUID()
            let resourceID2 = UUID()

            let initiative = Initiative(
                name: "Project Alpha",
                startDate: now,
                endDate: threeMonths,
                color: .blue,
                icon: "flag.fill"
            )

            let mk1 = MonthKey.from(date: now, calendar: cal)
            let mk2 = MonthKey.from(date: cal.date(byAdding: .month, value: 1, to: now)!, calendar: cal)

            let allocation1 = Allocation(resourceID: resourceID1, months: [mk1: 0.5, mk2: 0.75])
            let allocation2 = Allocation(resourceID: resourceID2, months: [mk1: 0.25])

            let assignment = Assignment(
                name: "Design Work",
                initiativeID: initiative.id,
                allocations: [allocation1, allocation2]
            )

            return Plan(
                name: "Preview Plan",
                initiatives: [initiative],
                assignments: [assignment]
            )
        }()

        @State var resources: [Resource] = {
            return [
                Resource(name: "Alice"),
                Resource(name: "Bob")
            ]
        }()

        var body: some View {
            // Patch resource IDs to match the allocations
            let _ = patchResourceIDs()
            PlanningGridView(plan: $plan, resources: $resources)
                .frame(width: 600, height: 400)
        }

        func patchResourceIDs() {
            let allocationResIDs = plan.assignments.flatMap(\.allocations).map(\.resourceID)
            for (i, resID) in allocationResIDs.enumerated() where i < resources.count {
                if resources[i].id != resID {
                    resources[i] = Resource(
                        id: resID,
                        name: resources[i].name
                    )
                }
            }
        }
    }

    return PreviewWrapper()
}

// MARK: - Short labels for column headers

extension MonthKey {
    var shortLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yy"
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        if let date = Calendar.gregorianUTC.date(from: comps) {
            return formatter.string(from: date)
        }
        return description
    }
}
