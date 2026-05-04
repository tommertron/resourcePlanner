import AppKit
import UniformTypeIdentifiers

enum ExportFormat: String, CaseIterable {
    case pdf, json, csv

    var fileExtension: String { rawValue }

    var utType: UTType {
        switch self {
        case .pdf:  return .pdf
        case .json: return .json
        case .csv:  return .commaSeparatedText
        }
    }

    var displayName: String {
        switch self {
        case .pdf:  return "PDF"
        case .json: return "JSON"
        case .csv:  return "CSV"
        }
    }
}

/// Shows an NSSavePanel for exporting a file in the given format.
/// Calls `completion` with the chosen URL, or nil if cancelled.
func showExportSavePanel(
    title: String,
    defaultName: String,
    format: ExportFormat,
    completion: @escaping (URL?) -> Void
) {
    let panel = NSSavePanel()
    panel.title = title
    panel.nameFieldStringValue = "\(defaultName).\(format.fileExtension)"
    panel.allowedContentTypes = [format.utType]
    panel.canCreateDirectories = true

    panel.begin { response in
        completion(response == .OK ? panel.url : nil)
    }
}
