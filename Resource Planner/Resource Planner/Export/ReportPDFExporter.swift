import AppKit
import CoreGraphics
import Foundation

enum ReportPDFExporter {

    // MARK: - Page constants

    private static let pageWidth: CGFloat = 612   // US Letter
    private static let pageHeight: CGFloat = 792
    private static let marginX: CGFloat = 50
    private static let marginTop: CGFloat = 60
    private static let marginBottom: CGFloat = 50
    private static let contentWidth: CGFloat = pageWidth - marginX * 2

    // MARK: - Fonts

    private static let titleFont = NSFont.boldSystemFont(ofSize: 18)
    private static let headingFont = NSFont.boldSystemFont(ofSize: 13)
    private static let bodyFont = NSFont.systemFont(ofSize: 10)
    private static let bodyBoldFont = NSFont.boldSystemFont(ofSize: 10)
    private static let captionFont = NSFont.systemFont(ofSize: 8)

    // MARK: - Public API

    static func exportOverviewReport(plan: Plan, resources: [Resource], roles: [Role], displayCurrency: String = "USD", conversionRates: [String: Double] = ["USD": 1.0]) -> Data {
        let ctx = ReportData.CurrencyContext(displayCurrency: displayCurrency, conversionRates: conversionRates)
        let cur = currencyFormatter(code: displayCurrency)
        let renderer = PDFRenderer(title: "\(plan.name) — Overview Report")
        let years = ReportData.allActiveYears(plan: plan)

        // Cost by Program (top of report)
        let programEntries = ReportData.programYearlyCosts(plan: plan, resources: resources, currencyContext: ctx)
        if !programEntries.isEmpty {
            renderer.addHeading("Cost by Program")
            let progHeader = ["Program"] + years.map(String.init) + ["Total"]
            var progRows: [[String]] = []
            for entry in programEntries {
                var row = ["\(entry.name) (\(entry.initiativeCount))"]
                for year in years { row.append(cur(entry.costByYear[year] ?? 0)) }
                row.append(cur(entry.totalCost))
                progRows.append(row)
            }
            var progTotalRow = ["Total"]
            for year in years {
                progTotalRow.append(cur(programEntries.reduce(0) { $0 + ($1.costByYear[year] ?? 0) }))
            }
            progTotalRow.append(cur(programEntries.reduce(0) { $0 + $1.totalCost }))
            renderer.addTable(headers: progHeader, rows: progRows, totalRow: progTotalRow)
            renderer.addSpacing(16)
        }

        // Cost by Initiative
        renderer.addHeading("Cost by Initiative")
        var header = ["Initiative"] + years.map(String.init) + ["Total"]
        var rows: [[String]] = []
        for initiative in plan.initiatives {
            let yearly = ReportData.initiativeYearlyCosts(initiative: initiative, plan: plan, resources: resources, currencyContext: ctx)
            let otherByYear = ReportData.otherCostsByYear(initiative: initiative, currencyContext: ctx)
            let otherTotal = ReportData.otherCostsTotal(initiative: initiative, currencyContext: ctx)
            let name = initiative.name.isEmpty ? "Untitled" : initiative.name
            var row = [name]
            for year in years {
                row.append(cur((yearly[year]?.total ?? 0) + (otherByYear[year] ?? 0)))
            }
            let peopleTotal = yearly.values.reduce(0) { $0 + $1.total }
            row.append(cur(peopleTotal + otherTotal))
            rows.append(row)
        }
        // Total row
        let grandTotal = plan.initiatives.reduce(0.0) { sum, init_ in
            let yearly = ReportData.initiativeYearlyCosts(initiative: init_, plan: plan, resources: resources, currencyContext: ctx)
            return sum + yearly.values.reduce(0) { $0 + $1.total } + ReportData.otherCostsTotal(initiative: init_, currencyContext: ctx)
        }
        var totalRow = ["Total"]
        for year in years {
            let yt = plan.initiatives.reduce(0.0) { sum, init_ in
                let yearly = ReportData.initiativeYearlyCosts(initiative: init_, plan: plan, resources: resources, currencyContext: ctx)
                return sum + (yearly[year]?.total ?? 0) + (ReportData.otherCostsByYear(initiative: init_, currencyContext: ctx)[year] ?? 0)
            }
            totalRow.append(cur(yt))
        }
        totalRow.append(cur(grandTotal))
        renderer.addTable(headers: header, rows: rows, totalRow: totalRow)

        renderer.addSpacing(16)

        // Committed vs Placeholder
        renderer.addHeading("Committed vs Placeholder")
        header = ["Initiative", "Committed", "Placeholder", "Total"]
        rows = []
        var allCommitted = 0.0
        var allPlaceholder = 0.0
        for initiative in plan.initiatives {
            let yearly = ReportData.initiativeYearlyCosts(initiative: initiative, plan: plan, resources: resources, currencyContext: ctx)
            let otherTotal = ReportData.otherCostsTotal(initiative: initiative, currencyContext: ctx)
            let committed = yearly.values.reduce(0) { $0 + $1.committed } + otherTotal
            let placeholder = yearly.values.reduce(0) { $0 + $1.placeholder }
            allCommitted += committed
            allPlaceholder += placeholder
            rows.append([
                initiative.name.isEmpty ? "Untitled" : initiative.name,
                cur(committed), cur(placeholder), cur(committed + placeholder)
            ])
        }
        renderer.addTable(headers: header, rows: rows,
                          totalRow: ["Total", cur(allCommitted), cur(allPlaceholder), cur(allCommitted + allPlaceholder)])

        return renderer.finalize()
    }

    static func exportResourceAllocationReport(plan: Plan, resources: [Resource], roles: [Role], displayCurrency: String = "USD", conversionRates: [String: Double] = ["USD": 1.0]) -> Data {
        let ctx = ReportData.CurrencyContext(displayCurrency: displayCurrency, conversionRates: conversionRates)
        let cur = currencyFormatter(code: displayCurrency)
        let renderer = PDFRenderer(title: "\(plan.name) — Resource Allocation")
        let years = ReportData.allActiveYears(plan: plan)
        let entries = ReportData.resourceAllocationByRole(plan: plan, resources: resources, roles: roles, currencyContext: ctx)

        renderer.addHeading("Resource Allocation by Role")
        let header = ["Role / Resource / Initiative", "Avg %"] + years.map(String.init) + ["Total"]
        var rows: [[String]] = []
        for roleEntry in entries {
            rows.append([roleEntry.roleName, "", ] + years.map { cur(roleEntry.costForYear($0)) } + [cur(roleEntry.totalCost)])
            for re in roleEntry.resources {
                rows.append(["  \(re.name.isEmpty ? "Untitled" : re.name)", ""] + years.map { cur(re.costForYear($0)) } + [cur(re.totalCost)])
                for a in re.assignments {
                    rows.append(["    \(a.initiativeName)", "\(Int(round(a.avgPercent * 100)))%"] + years.map { cur(a.costByYear[$0] ?? 0) } + [cur(a.cost)])
                }
            }
        }
        renderer.addTable(headers: header, rows: rows, totalRow: nil)

        renderer.addSpacing(16)

        // Remaining Capacity
        let capacity = ReportData.remainingCapacityByRole(plan: plan, resources: resources, roles: roles, currencyContext: ctx)
        if !capacity.isEmpty {
            renderer.addHeading("Remaining Capacity")
            var capRows: [[String]] = []
            for roleEntry in capacity {
                for entry in roleEntry.resources {
                    capRows.append([roleEntry.roleName, entry.name.isEmpty ? "Untitled" : entry.name,
                                    "\(Int(round(entry.remainingPercent * 100)))%",
                                    cur(entry.remainingMonthlyCost * 12)])
                }
            }
            renderer.addTable(headers: ["Role", "Resource", "Remaining %", "Annual Cost"], rows: capRows, totalRow: nil)
        }

        return renderer.finalize()
    }

    static func exportInitiativeReport(initiative: Initiative, plan: Plan, resources: [Resource], roles: [Role], displayCurrency: String = "USD", conversionRates: [String: Double] = ["USD": 1.0]) -> Data {
        let ctx = ReportData.CurrencyContext(displayCurrency: displayCurrency, conversionRates: conversionRates)
        let cur = currencyFormatter(code: displayCurrency)
        let name = initiative.name.isEmpty ? "Untitled" : initiative.name
        let renderer = PDFRenderer(title: "\(name) — Cost Report")
        let years = ReportData.allActiveYears(plan: plan)
        let breakdown = ReportData.resourceBreakdown(initiative: initiative, plan: plan, resources: resources, currencyContext: ctx)
        let roleCosts = ReportData.initiativeCostByRole(initiative: initiative, plan: plan, resources: resources, roles: roles, currencyContext: ctx)
        let otherTotal = ReportData.otherCostsTotal(initiative: initiative, currencyContext: ctx)
        let peopleCost = breakdown.reduce(0) { $0 + $1.totalCost }
        let totalCost = peopleCost + otherTotal

        // Summary
        let totalReturn = ReportData.expectedReturnsTotal(initiative: initiative, currencyContext: ctx)
        renderer.addHeading("Summary")
        renderer.addTextLine("Total Cost: \(cur(totalCost))")
        if totalReturn > 0 {
            let netReturn = totalReturn - totalCost
            let roi = totalCost > 0 ? (netReturn / totalCost) * 100 : 0
            renderer.addTextLine("Expected Return: \(cur(totalReturn))")
            renderer.addTextLine("Net Return: \(cur(netReturn))")
            renderer.addTextLine("ROI: \(String(format: "%+.0f", roi))%")
        }
        if !initiative.notes.isEmpty {
            renderer.addSpacing(8)
            renderer.addTextLine("Notes: \(initiative.notes)")
        }
        renderer.addSpacing(12)

        // Cost by Role
        if !roleCosts.isEmpty {
            renderer.addHeading("Cost by Role")
            let header = ["Role"] + years.map(String.init) + ["Total"]
            let rows = roleCosts.map { entry in
                [entry.roleName] + years.map { cur(entry.costByYear[$0] ?? 0) } + [cur(entry.totalCost)]
            }
            renderer.addTable(headers: header, rows: rows, totalRow: nil)
            renderer.addSpacing(12)
        }

        // Assigned Resources
        if !breakdown.isEmpty {
            renderer.addHeading("Assigned Resources")
            let header = ["Resource", "Avg %"] + years.map(String.init) + ["Total"]
            let rows = breakdown.map { entry in
                [entry.name.isEmpty ? "Untitled" : entry.name,
                 "\(Int(round(entry.avgAllocation * 100)))%"]
                + years.map { cur(entry.costByYear[$0] ?? 0) } + [cur(entry.totalCost)]
            }
            renderer.addTable(headers: header, rows: rows, totalRow: nil)
            renderer.addSpacing(12)
        }

        // Other Costs
        if !initiative.otherCosts.isEmpty {
            renderer.addHeading("Other Costs")
            let header = ["Name", "Months"] + years.map(String.init) + ["Total"]
            let rows = initiative.otherCosts.map { cost in
                [cost.name.isEmpty ? "Untitled" : cost.name, "\(cost.monthKeys.count)"]
                + years.map { cur(cost.costByYear[$0] ?? 0) } + [cur(cost.totalAmount)]
            }
            renderer.addTable(headers: header, rows: rows, totalRow: nil)
        }

        return renderer.finalize()
    }

    // MARK: - Currency helper

    private static func currencyFormatter(code: String) -> (Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = 0
        return { value in
            formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        }
    }
}

// MARK: - PDF Renderer

private class PDFRenderer {
    private var data = NSMutableData()
    private var context: CGContext!
    private var y: CGFloat = 0
    private let title: String
    private var pageNumber = 0

    private let pageWidth: CGFloat = 612
    private let pageHeight: CGFloat = 792
    private let marginX: CGFloat = 50
    private let marginTop: CGFloat = 60
    private let marginBottom: CGFloat = 50
    private var contentWidth: CGFloat { pageWidth - marginX * 2 }

    init(title: String) {
        self.title = title
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let consumer = CGDataConsumer(data: data),
              let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }
        context = ctx
        beginPage()

        // Title
        drawText(title, font: .boldSystemFont(ofSize: 16), x: marginX, maxWidth: contentWidth)
        y -= 4

        // Date
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        drawText("Generated \(formatter.string(from: Date()))", font: .systemFont(ofSize: 8), x: marginX, maxWidth: contentWidth, color: .secondaryLabelColor)
        y -= 12
    }

    func addHeading(_ text: String) {
        ensureSpace(30)
        y -= 8
        drawText(text, font: .boldSystemFont(ofSize: 13), x: marginX, maxWidth: contentWidth)
        y -= 6
    }

    func addTextLine(_ text: String) {
        ensureSpace(16)
        drawText(text, font: .systemFont(ofSize: 10), x: marginX, maxWidth: contentWidth)
        y -= 2
    }

    func addSpacing(_ points: CGFloat) {
        y -= points
    }

    func addTable(headers: [String], rows: [[String]], totalRow: [String]?) {
        let colCount = headers.count
        guard colCount > 0 else { return }

        // Column widths: first column gets more space, rest split evenly
        let firstColWidth = min(contentWidth * 0.35, 200.0)
        let remainingWidth = contentWidth - firstColWidth
        let otherColWidth = colCount > 1 ? remainingWidth / CGFloat(colCount - 1) : 0

        func colX(_ col: Int) -> CGFloat {
            col == 0 ? marginX : marginX + firstColWidth + otherColWidth * CGFloat(col - 1)
        }
        func colW(_ col: Int) -> CGFloat {
            col == 0 ? firstColWidth : otherColWidth
        }

        let rowHeight: CGFloat = 14
        let headerFont = NSFont.boldSystemFont(ofSize: 9)
        let cellFont = NSFont.systemFont(ofSize: 9)
        let boldCellFont = NSFont.boldSystemFont(ofSize: 9)

        // Header
        ensureSpace(rowHeight + 4)
        drawRow(cells: headers, font: headerFont, colX: colX, colW: colW, color: .secondaryLabelColor, height: rowHeight)
        y -= 2
        drawHLine()
        y -= 2

        // Rows
        for row in rows {
            ensureSpace(rowHeight)
            drawRow(cells: row, font: cellFont, colX: colX, colW: colW, color: .labelColor, height: rowHeight)
        }

        // Total row
        if let totalRow {
            y -= 1
            drawHLine()
            y -= 2
            ensureSpace(rowHeight)
            drawRow(cells: totalRow, font: boldCellFont, colX: colX, colW: colW, color: .labelColor, height: rowHeight)
        }
    }

    /// Draws a single row of cells at the current `y`, with all cells aligned to the same baseline,
    /// then advances `y` by `height` exactly once.
    private func drawRow(
        cells: [String],
        font: NSFont,
        colX: (Int) -> CGFloat,
        colW: (Int) -> CGFloat,
        color: NSColor,
        height: CGFloat
    ) {
        let rowTop = y
        for (i, cell) in cells.enumerated() {
            let alignment: NSTextAlignment = i == 0 ? .left : .right
            // Reset y to the row's top before each column so columns share a baseline.
            y = rowTop
            drawText(cell, font: font, x: colX(i), maxWidth: colW(i) - 4, alignment: alignment, color: color)
        }
        // Advance y by the nominal row height — independent of any individual cell's measured height.
        y = rowTop - height
    }

    func finalize() -> Data {
        addPageNumber()
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    // MARK: - Drawing primitives

    private func beginPage() {
        pageNumber += 1
        context.beginPDFPage(nil)
        y = pageHeight - marginTop
    }

    private func ensureSpace(_ needed: CGFloat) {
        if y - needed < marginBottom {
            addPageNumber()
            context.endPDFPage()
            beginPage()
        }
    }

    private func addPageNumber() {
        let text = "Page \(pageNumber)"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let x = pageWidth - marginX - size.width
        let str = NSAttributedString(string: text, attributes: attrs)
        let line = CTLineCreateWithAttributedString(str)
        context.saveGState()
        context.textPosition = CGPoint(x: x, y: 20)
        CTLineDraw(line, context)
        context.restoreGState()
    }

    @discardableResult
    private func drawText(
        _ text: String,
        font: NSFont,
        x: CGFloat,
        maxWidth: CGFloat,
        alignment: NSTextAlignment = .left,
        color: NSColor = .labelColor
    ) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        let attrStr = NSAttributedString(string: text, attributes: attrs)

        let size = attrStr.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin]
        )
        let lineHeight = ceil(size.height)
        let drawY = y - lineHeight

        // Use CTLine for single-line drawing
        let framesetter = CTFramesetterCreateWithAttributedString(attrStr)
        let path = CGPath(rect: CGRect(x: x, y: drawY, width: maxWidth, height: lineHeight + 2), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)

        context.saveGState()
        CTFrameDraw(frame, context)
        context.restoreGState()

        y = drawY
        return lineHeight
    }

    private func drawHLine() {
        context.saveGState()
        context.setStrokeColor(NSColor.separatorColor.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: marginX, y: y))
        context.addLine(to: CGPoint(x: pageWidth - marginX, y: y))
        context.strokePath()
        context.restoreGState()
    }
}
