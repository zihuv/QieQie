import SwiftUI

struct HistorySectionHeader: View {
    let title: String
    let subtitle: String
    let query: FocusStatisticsQuery
    let granularityOptions: [FocusStatisticsGranularity]
    let canNavigateForward: Bool
    let onGranularityChange: (FocusStatisticsGranularity) -> Void
    let onShift: (Int) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: FocusPanelSpacing.lg) {
            VStack(alignment: .leading, spacing: FocusPanelSpacing.xxs) {
                Text(title)
                    .font(FocusPanelTypography.sectionTitle)

                Text(subtitle)
                    .font(FocusPanelTypography.supportingText)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: FocusPanelSpacing.sm)

            VStack(alignment: .trailing, spacing: FocusPanelSpacing.sm) {
                Picker("", selection: Binding(
                    get: { query.granularity },
                    set: onGranularityChange
                )) {
                    ForEach(granularityOptions) { granularity in
                        Text(granularity.title).tag(granularity)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: segmentedControlWidth(for: granularityOptions))

                HStack(spacing: FocusPanelSpacing.xxs) {
                    Button(action: { onShift(-1) }) {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.borderless)

                    Text(FocusDisplayFormatter.periodTitle(for: query))
                        .font(FocusPanelTypography.bodyLabel)
                        .monospacedDigit()
                        .frame(minWidth: 108)

                    Button(action: { onShift(1) }) {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canNavigateForward)
                }
            }
        }
    }

    private func segmentedControlWidth(for options: [FocusStatisticsGranularity]) -> CGFloat {
        CGFloat(max(156, options.count * 44))
    }
}
