export const VISUAL_CONTRACT_VERSION = 1;

export const VISUAL_LIMITS = Object.freeze({
    maximumVisuals: 3,
    maximumVisualsPerKind: 2,
    maximumChartSeries: 4,
    maximumChartPointsPerSeries: 24,
    maximumChartPoints: 48,
    maximumDiagramNodes: 16,
    maximumDiagramEdges: 24,
    maximumCanvasDimension: 4000
});

export const CHART_TYPES = Object.freeze(['bar', 'line']);
export const DIAGRAM_TYPES = Object.freeze(['flow', 'hierarchy', 'sequence']);
export const DIAGRAM_DIRECTIONS = Object.freeze(['topToBottom', 'leftToRight']);
