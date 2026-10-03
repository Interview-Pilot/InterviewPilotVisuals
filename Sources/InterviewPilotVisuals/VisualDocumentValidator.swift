import Foundation

public enum InterviewVisualValidationError: Error, Equatable, Sendable {
    case invalidContract
    case invalidDocument
}

public extension InterviewVisualDocument {
    func validated() throws -> InterviewVisualDocument {
        guard contractVersion == 1,
              sourceAnswerHash.count == 64,
              sourceAnswerHash.allSatisfy({ $0.isHexDigit && !$0.isUppercase }),
              visuals.count <= 3 else {
            throw InterviewVisualValidationError.invalidContract
        }

        let chartCount = visuals.reduce(0) { count, visual in
            if case .chart = visual { return count + 1 }
            return count
        }
        guard chartCount <= 2, visuals.count - chartCount <= 2 else {
            throw InterviewVisualValidationError.invalidDocument
        }

        var visualIDs = Set<String>()
        for visual in visuals {
            guard visualIDs.insert(visual.id).inserted else {
                throw InterviewVisualValidationError.invalidDocument
            }
            switch visual {
            case .chart(let chart):
                try validate(chart)
            case .diagram(let diagram):
                try validate(diagram)
            }
        }
        return self
    }

    private func validate(_ chart: InterviewChartVisual) throws {
        guard chart.kind == "chart",
              isValidText(chart.id, maximum: 64),
              isValidText(chart.title, maximum: 120),
              isValidText(chart.accessibilitySummary, maximum: 500),
              chart.series.count >= 1,
              chart.series.count <= 4 else {
            throw InterviewVisualValidationError.invalidDocument
        }
        if let xAxisLabel = chart.xAxisLabel, !isValidText(xAxisLabel, maximum: 80) {
            throw InterviewVisualValidationError.invalidDocument
        }
        if let yAxisLabel = chart.yAxisLabel, !isValidText(yAxisLabel, maximum: 80) {
            throw InterviewVisualValidationError.invalidDocument
        }
        if let unit = chart.unit, !isValidText(unit, maximum: 40) {
            throw InterviewVisualValidationError.invalidDocument
        }

        var pointCount = 0
        for series in chart.series {
            guard isValidText(series.name, maximum: 80),
                  !series.points.isEmpty,
                  series.points.count <= 24 else {
                throw InterviewVisualValidationError.invalidDocument
            }
            pointCount += series.points.count
            for point in series.points {
                guard isValidText(point.label, maximum: 80), point.value.isFinite else {
                    throw InterviewVisualValidationError.invalidDocument
                }
            }
        }
        guard pointCount <= 48 else {
            throw InterviewVisualValidationError.invalidDocument
        }
    }

    private func validate(_ diagram: InterviewDiagramVisual) throws {
        guard diagram.kind == "diagram",
              isValidText(diagram.id, maximum: 64),
              isValidText(diagram.title, maximum: 120),
              isValidText(diagram.accessibilitySummary, maximum: 500),
              diagram.canvasWidth.isFinite,
              diagram.canvasHeight.isFinite,
              diagram.canvasWidth > 0,
              diagram.canvasHeight > 0,
              diagram.canvasWidth <= 4000,
              diagram.canvasHeight <= 4000,
              diagram.nodes.count >= 2,
              diagram.nodes.count <= 16,
              diagram.edges.count >= 1,
              diagram.edges.count <= 24 else {
            throw InterviewVisualValidationError.invalidDocument
        }

        let nodeIDs = Set(diagram.nodes.map(\.id))
        guard nodeIDs.count == diagram.nodes.count else {
            throw InterviewVisualValidationError.invalidDocument
        }
        for node in diagram.nodes {
            guard isValidText(node.id, maximum: 32),
                  isValidText(node.label, maximum: 100),
                  node.x.isFinite,
                  node.y.isFinite,
                  node.width.isFinite,
                  node.height.isFinite,
                  node.x >= 0,
                  node.y >= 0,
                  node.width > 0,
                  node.height > 0,
                  node.x + node.width <= diagram.canvasWidth + 1,
                  node.y + node.height <= diagram.canvasHeight + 1 else {
                throw InterviewVisualValidationError.invalidDocument
            }
        }

        var edgeIDs = Set<String>()
        for edge in diagram.edges {
            guard edgeIDs.insert(edge.id).inserted,
                  isValidText(edge.id, maximum: 64),
                  nodeIDs.contains(edge.source),
                  nodeIDs.contains(edge.target),
                  edge.source != edge.target,
                  edge.points.count >= 2,
                  edge.points.count <= 64 else {
                throw InterviewVisualValidationError.invalidDocument
            }
            if let label = edge.label, !isValidText(label, maximum: 100) {
                throw InterviewVisualValidationError.invalidDocument
            }
            for point in edge.points {
                guard point.x.isFinite,
                      point.y.isFinite,
                      point.x >= 0,
                      point.y >= 0,
                      point.x <= diagram.canvasWidth + 1,
                      point.y <= diagram.canvasHeight + 1 else {
                    throw InterviewVisualValidationError.invalidDocument
                }
            }
        }
    }

    private func isValidText(_ value: String, maximum: Int) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= maximum
    }
}
