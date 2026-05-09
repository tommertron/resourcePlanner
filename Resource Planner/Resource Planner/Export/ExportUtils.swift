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

/// Shows an NSSavePanel for exporting a file in the given format,
/// then writes `data` to the chosen URL. Surfaces failures via NSAlert.
func exportData(
    _ data: Data,
    title: String,
    defaultName: String,
    format: ExportFormat
) {
    let panel = NSSavePanel()
    panel.title = title
    // NSSavePanel will append the extension itself based on allowedContentTypes,
    // so don't pre-append it here (that produced "Name.pdf.pdf" before).
    panel.nameFieldStringValue = sanitizeFilename(defaultName)
    panel.allowedContentTypes = [format.utType]
    panel.canCreateDirectories = true

    panel.begin { response in
        guard response == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Export failed"
            alert.informativeText = "Could not write \(format.displayName) to \(url.path):\n\(error.localizedDescription)"
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

/// File system reserved characters and characters that confuse some file pickers.
private func sanitizeFilename(_ name: String) -> String {
    var s = name
    for c in [":", "/", "\\"] { s = s.replacingOccurrences(of: c, with: "-") }
    return s
}
