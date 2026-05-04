import SwiftUI

private let monthlyCellWidth: CGFloat = 62
private let cellHeight: CGFloat = 28

// MARK: - Monthly cell

struct MonthlyGridCell: View {
    @Binding var allocation: Allocation
    let monthKey: MonthKey
    var tintColor: Color? = nil

    var body: some View {
        let percent = allocation.months[monthKey] ?? 0

        TextField("", value: percentBinding, format: .number)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            .font(.caption.monospacedDigit())
            .padding(.horizontal, 4)
            .frame(width: monthlyCellWidth - 4, height: cellHeight - 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(cellFill(percent: percent, tint: tintColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(cellStroke(percent: percent), lineWidth: 1)
            )
            .frame(width: monthlyCellWidth, height: cellHeight)
    }

    private var percentBinding: Binding<Int?> {
        Binding<Int?>(
            get: {
                let p = allocation.months[monthKey] ?? 0
                return p == 0 ? nil : Int(round(p * 100))
            },
            set: { newValue in
                let pct = Double(newValue ?? 0) / 100.0
                if pct == 0 {
                    allocation.months.removeValue(forKey: monthKey)
                } else {
                    allocation.months[monthKey] = pct
                }
            }
        )
    }
}

// MARK: - Cell styling

private func cellFill(percent: Double, tint: Color? = nil) -> Color {
    if percent > 1.0 { return .red.opacity(0.12) }
    if percent > 0 { return (tint ?? .blue).opacity(0.08) }
    return Color(nsColor: .textBackgroundColor)
}

private func cellStroke(percent: Double) -> Color {
    if percent > 1.0 { return .red.opacity(0.4) }
    return Color(nsColor: .separatorColor)
}
