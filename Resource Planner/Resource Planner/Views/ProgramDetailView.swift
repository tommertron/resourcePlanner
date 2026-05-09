import SwiftUI

struct ProgramDetailView: View {
    @Binding var program: Program
    @Binding var plan: Plan
    let resources: [Resource]
    let displayCurrency: String
    let conversionRates: [String: Double]
    var onSelectInitiative: ((UUID) -> Void)? = nil

    @State private var showingNewInitiativeSheet = false

    private var currencyContext: ReportData.CurrencyContext {
        ReportData.CurrencyContext(displayCurrency: displayCurrency, conversionRates: conversionRates)
    }

    private var memberInitiatives: [Initiative] {
        plan.initiatives.filter { $0.programID == program.id }
    }

    private var rolledUp: ReportData.ProgramCostEntry? {
        ReportData.programYearlyCosts(plan: plan, resources: resources, currencyContext: currencyContext)
            .first(where: { $0.id == program.id })
    }

    private var years: [Int] {
        ReportData.allActiveYears(plan: plan)
    }

    var body: some View {
        Form {
            Section("Program") {
                TextField("Name", text: $program.name)
                    .textFieldStyle(.roundedBorder)
                DatePicker("Start", selection: $program.startDate, displayedComponents: .date)
                DatePicker("End", selection: $program.endDate, in: program.startDate..., displayedComponents: .date)

                Picker("Color", selection: $program.color) {
                    ForEach(InitiativeColor.allCases) { c in
                        Label(c.displayName, systemImage: "circle.fill")
                            .foregroundStyle(c.swiftUIColor)
                            .tag(c)
                    }
                }
            }

            Section("Notes") {
                TextEditor(text: $program.notes)
                    .frame(minHeight: 80)
                    .font(.body)
            }

            Section("Cost rollup (\(memberInitiatives.count) \(memberInitiatives.count == 1 ? "initiative" : "initiatives"))") {
                if let rolledUp, !years.isEmpty {
                    LabeledContent("Total") {
                        Text(rolledUp.totalCost,
                             format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                            .monospacedDigit()
                            .bold()
                    }
                    ForEach(years, id: \.self) { year in
                        LabeledContent(String(year)) {
                            Text(rolledUp.costByYear[year] ?? 0,
                                 format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("No costs yet — add initiatives below.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Initiatives in this program") {
                if memberInitiatives.isEmpty {
                    Text("No initiatives yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(memberInitiatives) { initiative in
                        Button {
                            onSelectInitiative?(initiative.id)
                        } label: {
                            HStack {
                                Image(systemName: initiative.icon)
                                    .foregroundStyle(initiative.color.swiftUIColor)
                                    .frame(width: 18)
                                Text(initiative.name.isEmpty ? "Untitled initiative" : initiative.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                }

                Button {
                    addInitiativeToProgram()
                } label: {
                    Label("Add Initiative to Program", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(program.name.isEmpty ? "Untitled Program" : program.name)
    }

    private func addInitiativeToProgram() {
        // New initiatives in a program inherit the program's date range as their default.
        let new = Initiative(
            name: "",
            startDate: program.startDate,
            endDate: program.endDate,
            color: program.color,
            programID: program.id
        )
        plan.initiatives.append(new)
        onSelectInitiative?(new.id)
    }
}
