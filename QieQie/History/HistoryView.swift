import SwiftUI

enum StatisticsWindowLayout {
    static let defaultSize = CGSize(width: 880, height: 640)
    static let minSize = CGSize(width: 800, height: 560)
}

struct HistoryView: View {
    let historyManager: FocusHistoryManager

    @State private var detailQuery = FocusStatisticsQuery(granularity: .week, anchorDate: Date())
    @State private var trendQuery = FocusStatisticsQuery(granularity: .week, anchorDate: Date())
    @State private var detailSnapshot = FocusStatisticsPageSnapshot()
    @State private var trendSnapshot = FocusStatisticsPageSnapshot()
    @State private var selectedTrendPointDate: Date?

    private let summaryColumns = [
        GridItem(.flexible(), spacing: FocusPanelSpacing.lg),
        GridItem(.flexible(), spacing: FocusPanelSpacing.lg),
        GridItem(.flexible(), spacing: FocusPanelSpacing.lg),
        GridItem(.flexible(), spacing: FocusPanelSpacing.lg)
    ]
    private let detailCardHeight: CGFloat = 356
    private let detailGranularityOptions: [FocusStatisticsGranularity] = [.day, .week, .month, .year]
    private let trendGranularityOptions: [FocusStatisticsGranularity] = [.week, .month, .year]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: FocusPanelSpacing.xl) {
                HistorySummarySection(
                    overview: detailSnapshot.overview,
                    columns: summaryColumns
                )

                HStack(alignment: .top, spacing: FocusPanelSpacing.lg) {
                    HistoryFocusDetailSection(
                        query: detailQuery,
                        snapshot: detailSnapshot,
                        granularityOptions: detailGranularityOptions,
                        cardHeight: detailCardHeight,
                        onGranularityChange: { granularity in
                            detailQuery = FocusStatisticsQuery(
                                granularity: granularity,
                                anchorDate: detailQuery.anchorDate
                            )
                        },
                        onShift: { offset in
                            detailQuery = effectiveDetailQuery.shifted(by: offset)
                        }
                    )

                    HistoryRecordsSection(
                        query: effectiveDetailQuery,
                        recentSessions: detailSnapshot.recentSessions,
                        cardHeight: detailCardHeight
                    )
                }

                HistoryTrendSection(
                    query: trendQuery,
                    snapshot: trendSnapshot,
                    selectedTrendPointDate: $selectedTrendPointDate,
                    granularityOptions: trendGranularityOptions,
                    onGranularityChange: { granularity in
                        trendQuery = FocusStatisticsQuery(
                            granularity: granularity,
                            anchorDate: trendQuery.anchorDate
                        )
                    },
                    onShift: { offset in
                        trendQuery = effectiveTrendQuery.shifted(by: offset)
                    }
                )
            }
            .padding(FocusPanelSpacing.xxl)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(
            minWidth: StatisticsWindowLayout.minSize.width,
            maxWidth: .infinity,
            minHeight: StatisticsWindowLayout.minSize.height,
            maxHeight: .infinity,
            alignment: .top
        )
        .background(Color(nsColor: NSColor.windowBackgroundColor))
        .onAppear(perform: loadData)
        .onChange(of: detailQuery) { _, _ in
            loadData()
        }
        .onChange(of: trendQuery) { _, _ in
            loadData()
        }
    }

    private func loadData() {
        detailSnapshot = historyManager.getStatisticsPageSnapshot(query: effectiveDetailQuery)
        trendSnapshot = historyManager.getStatisticsPageSnapshot(query: effectiveTrendQuery)
        if let selectedTrendPointDate,
           !trendSnapshot.trendPoints.contains(where: { $0.date == selectedTrendPointDate }) {
            self.selectedTrendPointDate = nil
        }
    }

    private var effectiveDetailQuery: FocusStatisticsQuery {
        detailQuery.normalized()
    }

    private var effectiveTrendQuery: FocusStatisticsQuery {
        trendQuery.normalized()
    }
}
