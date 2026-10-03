import Charts
import SwiftUI

public struct InterviewVisualsView: View {
    private let document: InterviewVisualDocument

    public init(document: InterviewVisualDocument) {
        self.document = document
    }

    public var body: some View {
        if !document.visuals.isEmpty {
            VStack(spacing: 14) {
                ForEach(document.visuals) { visual in
                    switch visual {
                    case .chart(let chart):
                        InterviewChartView(chart: chart)
                    case .diagram(let diagram):
                        InterviewDiagramView(diagram: diagram)
                    }
                }
            }
        }
    }
}

private struct ChartDatum: Identifiable {
    let id: String
    let series: String
    let label: String
    let value: Double
}

private struct InterviewChartView: View {
    let chart: InterviewChartVisual

    private var data: [ChartDatum] {
        chart.series.enumerated().flatMap { seriesIndex, series in
            series.points.enumerated().map { pointIndex, point in
                ChartDatum(
                    id: "\(seriesIndex)-\(pointIndex)",
                    series: series.name,
                    label: point.label,
                    value: point.value
                )
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(chart.title)
                .font(.headline)

            if let yAxisLabel = chart.yAxisLabel {
                Text(axisTitle(yAxisLabel))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart(data) { datum in
                switch chart.chartType {
                case .bar:
                    BarMark(
                        x: .value(chart.xAxisLabel ?? "", datum.label),
                        y: .value(chart.yAxisLabel ?? "", datum.value)
                    )
                    .foregroundStyle(by: .value("", datum.series))
                    .position(by: .value("", datum.series))
                case .line:
                    LineMark(
                        x: .value(chart.xAxisLabel ?? "", datum.label),
                        y: .value(chart.yAxisLabel ?? "", datum.value)
                    )
                    .foregroundStyle(by: .value("", datum.series))
                    .symbol(by: .value("", datum.series))
                    PointMark(
                        x: .value(chart.xAxisLabel ?? "", datum.label),
                        y: .value(chart.yAxisLabel ?? "", datum.value)
                    )
                    .foregroundStyle(by: .value("", datum.series))
                }
            }
            .chartLegend(chart.series.count > 1 ? .visible : .hidden)
            .frame(minHeight: 210)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(chart.accessibilitySummary)

            if let xAxisLabel = chart.xAxisLabel {
                Text(xAxisLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
    }

    private func axisTitle(_ label: String) -> String {
        guard let unit = chart.unit else { return label }
        return "\(label) (\(unit))"
    }
}

private struct InterviewDiagramView: View {
    let diagram: InterviewDiagramVisual

    private var visibleHeight: CGFloat {
        min(max(CGFloat(diagram.canvasHeight), 180), 520)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(diagram.title)
                .font(.headline)

            GeometryReader { proxy in
                let canvasWidth = CGFloat(diagram.canvasWidth)
                let canvasHeight = CGFloat(diagram.canvasHeight)
                let renderWidth = max(canvasWidth, proxy.size.width)
                let horizontalOffset = max(0, (renderWidth - canvasWidth) / 2)

                ScrollView([.horizontal, .vertical]) {
                    ZStack(alignment: .topLeading) {
                        diagramCanvas(horizontalOffset: horizontalOffset)

                        ForEach(diagram.edges) { edge in
                            if let label = edge.label, let midpoint = edgeMidpoint(edge) {
                                Text(label)
                                    .font(.caption2)
                                    .lineLimit(2)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(.regularMaterial, in: Capsule())
                                    .position(
                                        x: midpoint.x + horizontalOffset,
                                        y: midpoint.y - 10
                                    )
                            }
                        }

                        ForEach(diagram.nodes) { node in
                            Text(node.label)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .minimumScaleFactor(0.8)
                                .padding(.horizontal, 10)
                                .frame(
                                    width: CGFloat(node.width),
                                    height: CGFloat(node.height)
                                )
                                .background(
                                    Color.accentColor.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.accentColor.opacity(0.45), lineWidth: 1)
                                }
                                .position(
                                    x: CGFloat(node.x + node.width / 2) + horizontalOffset,
                                    y: CGFloat(node.y + node.height / 2)
                                )
                        }
                    }
                    .frame(width: renderWidth, height: canvasHeight)
                }
                .scrollIndicators(.automatic)
            }
            .frame(height: visibleHeight)
        }
        .padding(16)
        .background(.quaternary.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(diagram.accessibilitySummary)
    }

    private func diagramCanvas(horizontalOffset: CGFloat) -> some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, _ in
            if diagram.diagramType == .sequence {
                drawSequenceLifelines(
                    context: &context,
                    horizontalOffset: horizontalOffset
                )
            }
            for edge in diagram.edges {
                draw(edge: edge, context: &context, horizontalOffset: horizontalOffset)
            }
        }
        .accessibilityHidden(true)
    }

    private func drawSequenceLifelines(
        context: inout GraphicsContext,
        horizontalOffset: CGFloat
    ) {
        for node in diagram.nodes {
            let x = CGFloat(node.x + node.width / 2) + horizontalOffset
            var path = Path()
            path.move(to: CGPoint(x: x, y: CGFloat(node.y + node.height)))
            path.addLine(to: CGPoint(x: x, y: CGFloat(diagram.canvasHeight - 12)))
            context.stroke(
                path,
                with: .color(.secondary.opacity(0.35)),
                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
            )
        }
    }

    private func draw(
        edge: InterviewDiagramEdge,
        context: inout GraphicsContext,
        horizontalOffset: CGFloat
    ) {
        guard edge.points.count >= 2 else { return }
        let points = edge.points.map {
            CGPoint(x: CGFloat($0.x) + horizontalOffset, y: CGFloat($0.y))
        }
        var path = Path()
        path.move(to: points[0])
        points.dropFirst().forEach { path.addLine(to: $0) }
        context.stroke(
            path,
            with: .color(.secondary.opacity(0.75)),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
        )
        drawArrowhead(points: points, context: &context)
    }

    private func drawArrowhead(points: [CGPoint], context: inout GraphicsContext) {
        guard let end = points.last else { return }
        let previous = points[points.count - 2]
        let angle = atan2(end.y - previous.y, end.x - previous.x)
        let length: CGFloat = 7
        let spread: CGFloat = .pi / 6
        var arrow = Path()
        arrow.move(to: end)
        arrow.addLine(to: CGPoint(
            x: end.x - length * cos(angle - spread),
            y: end.y - length * sin(angle - spread)
        ))
        arrow.move(to: end)
        arrow.addLine(to: CGPoint(
            x: end.x - length * cos(angle + spread),
            y: end.y - length * sin(angle + spread)
        ))
        context.stroke(
            arrow,
            with: .color(.secondary.opacity(0.75)),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
        )
    }

    private func edgeMidpoint(_ edge: InterviewDiagramEdge) -> CGPoint? {
        guard let first = edge.points.first, let last = edge.points.last else { return nil }
        return CGPoint(x: (first.x + last.x) / 2, y: (first.y + last.y) / 2)
    }
}
