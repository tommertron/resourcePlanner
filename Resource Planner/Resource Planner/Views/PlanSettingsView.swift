import SwiftUI

struct PlanSettingsView: View {
    @Binding var document: PlannerDocument
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Document Settings").font(.title2).bold()

            Picker("Display Currency", selection: $document.displayCurrency) {
                ForEach(SupportedCurrency.allCases) { currency in
                    Text(currency.displayName).tag(currency.rawValue)
                }
            }

            Divider()

            Text("Conversion Rates")
                .font(.headline)
            Text("How much one unit of each currency is worth in \(document.displayCurrency).")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(SupportedCurrency.allCases) { currency in
                if currency.rawValue != document.displayCurrency {
                    HStack {
                        Text("1 \(currency.rawValue) =")
                            .frame(width: 70, alignment: .leading)
                        TextField(
                            "Rate",
                            value: conversionRateBinding(for: currency.rawValue),
                            format: .number.precision(.fractionLength(2...4))
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 100)
                        Text(document.displayCurrency)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 380, height: 320)
        .onChange(of: document.displayCurrency) { _, newValue in
            // The display currency always has a rate of 1.0
            document.conversionRates[newValue] = 1.0
        }
    }

    private func conversionRateBinding(for code: String) -> Binding<Double> {
        Binding(
            get: { document.conversionRates[code] ?? 1.0 },
            set: { document.conversionRates[code] = $0 }
        )
    }
}
