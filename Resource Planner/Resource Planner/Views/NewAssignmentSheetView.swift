import SwiftUI

struct NewAssignmentSheetView: View {
    let initiatives: [Initiative]
    let resources: [Resource]
    let onCommit: (_ name: String, _ initiativeID: UUID, _ resourceIDs: [UUID]) -> Void

    @State private var name = ""
    @State private var selectedInitiativeID: UUID?
    @State private var selectedResourceIDs: Set<UUID> = []
    @FocusState private var nameFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Assignment").font(.title2).bold()
            Text("Create an assignment under an initiative and pick which resources to allocate.")
                .font(.callout)
                .foregroundStyle(.secondary)

            TextField("Assignment name", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($nameFocused)
                .onSubmit { commit() }

            Picker("Initiative", selection: $selectedInitiativeID) {
                Text("Select…").tag(UUID?.none)
                ForEach(initiatives) { initiative in
                    Text(initiative.name.isEmpty ? "Untitled initiative" : initiative.name)
                        .tag(UUID?.some(initiative.id))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Resources")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                List(resources, selection: $selectedResourceIDs) { resource in
                    Text(resource.name.isEmpty ? "Untitled" : resource.name)
                }
                .listStyle(.bordered)
                .frame(height: 150)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create") { commit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canCommit)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            nameFocused = true
            selectedInitiativeID = initiatives.first?.id
        }
    }

    private var canCommit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && selectedInitiativeID != nil
            && !selectedResourceIDs.isEmpty
    }

    private func commit() {
        guard canCommit, let initID = selectedInitiativeID else { return }
        onCommit(name.trimmingCharacters(in: .whitespaces), initID, Array(selectedResourceIDs))
        dismiss()
    }
}
