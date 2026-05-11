import SwiftUI

private let monthlyCellWidth: CGFloat = 62
private let defaultCellHeight: CGFloat = 28

// MARK: - Monthly cell

struct MonthlyGridCell: View {
    @Binding var allocation: Allocation
    let monthKey: MonthKey
    var tintColor: Color? = nil
    /// 0-based column index within the row. Required for drag-fill.
    var columnIndex: Int = 0
    /// Row height — must match the parent grid's per-row height so columns stay aligned.
    var rowHeight: CGFloat = defaultCellHeight
    /// Font for the typed percentage value. Should scale with the parent grid font.
    var valueFont: Font = .caption.monospacedDigit()
    /// Called when the user drags this cell's fill handle. `delta` is the signed
    /// number of cells away from this one to fill (negative = left, positive = right).
    /// `phase` is .changed during drag, .ended on release.
    var onDragFill: ((_ sourceColumn: Int, _ delta: Int, _ phase: DragFillPhase) -> Void)? = nil

    @State private var hovering = false
    @State private var fillDelta: Int = 0

    var body: some View {
        let percent = allocation.months[monthKey] ?? 0

        ZStack(alignment: .bottomTrailing) {
            TextField("", text: percentTextBinding)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .font(valueFont)
                .padding(.horizontal, 4)
                .frame(width: monthlyCellWidth - 4, height: rowHeight - 6)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(cellFill(percent: percent, tint: tintColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(cellStroke(percent: percent), lineWidth: 1)
                )
                .frame(width: monthlyCellWidth, height: rowHeight)

            // Drag-fill handle — visible on hover when cell has a value
            if hovering && percent > 0 && onDragFill != nil {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 7, height: 7)
                    .offset(x: -4, y: -4)
                    .gesture(fillDragGesture)
                    .help("Drag to fill across row")
            }
        }
        .frame(width: monthlyCellWidth, height: rowHeight)
        .onHover { hovering = $0 }
    }

    private var fillDragGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("planningRow"))
            .onChanged { value in
                let delta = Int((value.translation.width / monthlyCellWidth).rounded())
                if delta != fillDelta {
                    fillDelta = delta
                    onDragFill?(columnIndex, delta, .changed)
                }
            }
            .onEnded { _ in
                onDragFill?(columnIndex, fillDelta, .ended)
                fillDelta = 0
            }
    }

    /// Text binding that interprets typed/pasted values smartly:
    /// - empty → clears the cell
    /// - 0     → clears the cell
    /// - 0 < v < 1 → treated as a fraction (0.04 → 4%)
    /// - v ≥ 1 → treated as percent points (4 → 4%, 150 → 150%)
    private var percentTextBinding: Binding<String> {
        Binding<String>(
            get: {
                let p = allocation.months[monthKey] ?? 0
                return p == 0 ? "" : String(Int(round(p * 100)))
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "%", with: "")
                guard !trimmed.isEmpty,
                      let v = Double(trimmed) else {
                    allocation.months.removeValue(forKey: monthKey)
                    return
                }
                let pct: Double
                if v == 0 {
                    allocation.months.removeValue(forKey: monthKey)
                    return
                } else if v > 0 && v < 1 {
                    pct = v
                } else {
                    pct = v / 100.0
                }
                allocation.months[monthKey] = pct
            }
        )
    }
}

enum DragFillPhase {
    case changed, ended
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
