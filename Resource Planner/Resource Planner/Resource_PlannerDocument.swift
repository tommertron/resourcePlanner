import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let resourcePlan = UTType(exportedAs: "com.tommertron.resourceplanner.rplan")
}

struct Resource_PlannerDocument: FileDocument {
    var planner: PlannerDocument

    init(planner: PlannerDocument = PlannerDocument()) {
        self.planner = planner
    }

    nonisolated static let readableContentTypes: [UTType] = [.resourcePlan, .json]
    nonisolated static let writableContentTypes: [UTType] = [.resourcePlan]

    // FileDocument calls init and fileWrapper on a background thread,
    // so these must be nonisolated to avoid MainActor isolation crashes.
    nonisolated init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.planner = try PlannerDocument.decoded(from: data)
    }

    nonisolated func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try planner.encoded()
        return FileWrapper(regularFileWithContents: data)
    }
}
