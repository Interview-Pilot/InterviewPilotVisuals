import Foundation

public struct InterviewVisualDocument: Codable, Equatable, Sendable {
    public let contractVersion: Int
    public let sourceAnswerHash: String
    public let visuals: [InterviewVisual]

    public init(
        contractVersion: Int,
        sourceAnswerHash: String,
        visuals: [InterviewVisual]
    ) {
        self.contractVersion = contractVersion
        self.sourceAnswerHash = sourceAnswerHash
        self.visuals = visuals
    }
}

public enum InterviewVisual: Codable, Equatable, Sendable, Identifiable {
    case chart(InterviewChartVisual)
    case diagram(InterviewDiagramVisual)

    public var id: String {
        switch self {
        case .chart(let chart): chart.id
        case .diagram(let diagram): diagram.id
        }
    }

    private enum CodingKeys: String, CodingKey {
        case kind
    }

    private enum Kind: String, Codable {
        case chart
        case diagram
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .chart:
            self = .chart(try InterviewChartVisual(from: decoder))
        case .diagram:
            self = .diagram(try InterviewDiagramVisual(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .chart(let chart): try chart.encode(to: encoder)
        case .diagram(let diagram): try diagram.encode(to: encoder)
        }
    }
}

public struct InterviewChartVisual: Codable, Equatable, Sendable, Identifiable {
    public enum ChartType: String, Codable, Sendable {
        case bar
        case line
    }

    public let kind: String
    public let id: String
    public let title: String
    public let accessibilitySummary: String
    public let chartType: ChartType
    public let xAxisLabel: String?
    public let yAxisLabel: String?
    public let unit: String?
    public let series: [InterviewChartSeries]

    public init(
        id: String,
        title: String,
        accessibilitySummary: String,
        chartType: ChartType,
        xAxisLabel: String? = nil,
        yAxisLabel: String? = nil,
        unit: String? = nil,
        series: [InterviewChartSeries]
    ) {
        self.kind = "chart"
        self.id = id
        self.title = title
        self.accessibilitySummary = accessibilitySummary
        self.chartType = chartType
        self.xAxisLabel = xAxisLabel
        self.yAxisLabel = yAxisLabel
        self.unit = unit
        self.series = series
    }
}

public struct InterviewChartSeries: Codable, Equatable, Sendable {
    public let name: String
    public let points: [InterviewChartPoint]

    public init(name: String, points: [InterviewChartPoint]) {
        self.name = name
        self.points = points
    }
}

public struct InterviewChartPoint: Codable, Equatable, Sendable {
    public let label: String
    public let value: Double

    public init(label: String, value: Double) {
        self.label = label
        self.value = value
    }
}

public struct InterviewDiagramVisual: Codable, Equatable, Sendable, Identifiable {
    public enum DiagramType: String, Codable, Sendable {
        case flow
        case hierarchy
        case sequence
    }

    public enum Direction: String, Codable, Sendable {
        case topToBottom
        case leftToRight
    }

    public let kind: String
    public let id: String
    public let title: String
    public let accessibilitySummary: String
    public let diagramType: DiagramType
    public let direction: Direction
    public let canvasWidth: Double
    public let canvasHeight: Double
    public let nodes: [InterviewDiagramNode]
    public let edges: [InterviewDiagramEdge]

    public init(
        id: String,
        title: String,
        accessibilitySummary: String,
        diagramType: DiagramType,
        direction: Direction,
        canvasWidth: Double,
        canvasHeight: Double,
        nodes: [InterviewDiagramNode],
        edges: [InterviewDiagramEdge]
    ) {
        self.kind = "diagram"
        self.id = id
        self.title = title
        self.accessibilitySummary = accessibilitySummary
        self.diagramType = diagramType
        self.direction = direction
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.nodes = nodes
        self.edges = edges
    }
}

public struct InterviewDiagramNode: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let label: String
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(
        id: String,
        label: String,
        x: Double,
        y: Double,
        width: Double,
        height: Double
    ) {
        self.id = id
        self.label = label
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct InterviewDiagramEdge: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let source: String
    public let target: String
    public let label: String?
    public let points: [InterviewVisualPoint]

    public init(
        id: String,
        source: String,
        target: String,
        label: String? = nil,
        points: [InterviewVisualPoint]
    ) {
        self.id = id
        self.source = source
        self.target = target
        self.label = label
        self.points = points
    }
}

public struct InterviewVisualPoint: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}
