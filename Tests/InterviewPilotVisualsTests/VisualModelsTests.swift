import XCTest
@testable import InterviewPilotVisuals

final class VisualModelsTests: XCTestCase {
    func testDecodesMixedVisualDocument() throws {
        let data = Data(json.utf8)
        let document = try JSONDecoder().decode(InterviewVisualDocument.self, from: data)
        XCTAssertNoThrow(try document.validated())

        XCTAssertEqual(document.contractVersion, 1)
        XCTAssertEqual(document.visuals.count, 2)
        guard case .chart(let chart) = document.visuals[0] else {
            return XCTFail("Expected chart")
        }
        XCTAssertEqual(chart.series[0].points[0].value, 10)
        guard case .diagram(let diagram) = document.visuals[1] else {
            return XCTFail("Expected diagram")
        }
        XCTAssertEqual(diagram.nodes.count, 2)
        XCTAssertEqual(diagram.edges[0].points.count, 2)
    }

    func testRejectsUnboundedGeometry() throws {
        let document = try JSONDecoder().decode(
            InterviewVisualDocument.self,
            from: Data(json.replacingOccurrences(of: "\"canvasWidth\": 320", with: "\"canvasWidth\": 5000").utf8)
        )

        XCTAssertThrowsError(try document.validated())
    }

    func testRoundTripPreservesKinds() throws {
        let decoder = JSONDecoder()
        let original = try decoder.decode(InterviewVisualDocument.self, from: Data(json.utf8))
        let encoded = try JSONEncoder().encode(original)
        let decoded = try decoder.decode(InterviewVisualDocument.self, from: encoded)

        XCTAssertEqual(decoded, original)
    }

    private let json = #"""
    {
      "contractVersion": 1,
      "sourceAnswerHash": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      "visuals": [
        {
          "kind": "chart",
          "id": "visual-1",
          "title": "Revenue",
          "accessibilitySummary": "Revenue increased.",
          "chartType": "bar",
          "xAxisLabel": "Year",
          "yAxisLabel": "Revenue",
          "unit": null,
          "series": [{"name": "Revenue", "points": [{"label": "2024", "value": 10}]}]
        },
        {
          "kind": "diagram",
          "id": "visual-2",
          "title": "Flow",
          "accessibilitySummary": "A leads to B.",
          "diagramType": "flow",
          "direction": "leftToRight",
          "canvasWidth": 320,
          "canvasHeight": 120,
          "nodes": [
            {"id": "a", "label": "A", "x": 10, "y": 20, "width": 100, "height": 50},
            {"id": "b", "label": "B", "x": 210, "y": 20, "width": 100, "height": 50}
          ],
          "edges": [
            {"id": "edge-1", "source": "a", "target": "b", "label": null, "points": [{"x": 110, "y": 45}, {"x": 210, "y": 45}]}
          ]
        }
      ]
    }
    """#
}
