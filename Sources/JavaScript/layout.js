import dagre from '@dagrejs/dagre';
import { createHash } from 'node:crypto';
import { VISUAL_CONTRACT_VERSION, VISUAL_LIMITS } from './constants.js';
import { VisualValidationError, validateGeneratedVisuals } from './validation.js';

const round = (value) => Math.round(value * 100) / 100;

const estimateNodeSize = (label) => {
    const characterUnits = [...label].reduce(
        (total, character) => total + (/^[\x00-\x7F]$/u.test(character) ? 0.58 : 1),
        0
    );
    const width = Math.min(220, Math.max(120, 36 + characterUnits * 7));
    const lines = Math.max(1, Math.ceil((characterUnits * 7) / Math.max(84, width - 28)));
    return { width: round(width), height: round(34 + lines * 18) };
};

const createDagreLayout = (visual) => {
    const graph = new dagre.graphlib.Graph({ multigraph: true });
    graph.setGraph({
        rankdir: visual.direction === 'leftToRight' ? 'LR' : 'TB',
        nodesep: 28,
        edgesep: 16,
        ranksep: 54,
        marginx: 16,
        marginy: 16
    });
    graph.setDefaultEdgeLabel(() => ({}));

    for (const node of visual.nodes) graph.setNode(node.id, estimateNodeSize(node.label));
    visual.edges.forEach((edge, index) => {
        graph.setEdge(edge.source, edge.target, {}, `edge-${index + 1}`);
    });
    dagre.layout(graph);

    const graphSize = graph.graph();
    const canvasWidth = Math.max(1, round(graphSize.width));
    const canvasHeight = Math.max(1, round(graphSize.height));
    if (
        canvasWidth > VISUAL_LIMITS.maximumCanvasDimension
        || canvasHeight > VISUAL_LIMITS.maximumCanvasDimension
    ) {
        throw new VisualValidationError('diagram layout exceeds the canvas limit');
    }

    return {
        canvasWidth,
        canvasHeight,
        nodes: visual.nodes.map((node) => {
            const layout = graph.node(node.id);
            return {
                id: node.id,
                label: node.label,
                x: round(layout.x - layout.width / 2),
                y: round(layout.y - layout.height / 2),
                width: round(layout.width),
                height: round(layout.height)
            };
        }),
        edges: visual.edges.map((edge, index) => {
            const layout = graph.edge({
                v: edge.source,
                w: edge.target,
                name: `edge-${index + 1}`
            });
            return {
                id: `edge-${index + 1}`,
                source: edge.source,
                target: edge.target,
                label: edge.label,
                points: layout.points.map((point) => ({ x: round(point.x), y: round(point.y) }))
            };
        })
    };
};

const createSequenceLayout = (visual) => {
    const margin = 16;
    const gap = 36;
    const nodes = visual.nodes.map((node) => ({
        ...node,
        ...estimateNodeSize(node.label)
    }));
    let cursor = margin;
    const positionedNodes = nodes.map((node) => {
        const positioned = {
            id: node.id,
            label: node.label,
            x: round(cursor),
            y: margin,
            width: node.width,
            height: node.height
        };
        cursor += node.width + gap;
        return positioned;
    });
    const nodeById = new Map(positionedNodes.map((node) => [node.id, node]));
    const headerHeight = Math.max(...positionedNodes.map((node) => node.height));
    const orderedEdges = [...visual.edges].sort((left, right) => left.order - right.order);
    const edges = orderedEdges.map((edge, index) => {
        const source = nodeById.get(edge.source);
        const target = nodeById.get(edge.target);
        const y = margin + headerHeight + 40 + index * 46;
        return {
            id: `edge-${index + 1}`,
            source: edge.source,
            target: edge.target,
            label: edge.label,
            points: [
                { x: round(source.x + source.width / 2), y: round(y) },
                { x: round(target.x + target.width / 2), y: round(y) }
            ]
        };
    });
    const canvasWidth = Math.max(1, round(cursor - gap + margin));
    const canvasHeight = round(margin + headerHeight + 72 + orderedEdges.length * 46);
    if (
        canvasWidth > VISUAL_LIMITS.maximumCanvasDimension
        || canvasHeight > VISUAL_LIMITS.maximumCanvasDimension
    ) {
        throw new VisualValidationError('sequence layout exceeds the canvas limit');
    }
    return { canvasWidth, canvasHeight, nodes: positionedNodes, edges };
};

const buildChart = (visual, index) => ({
    kind: 'chart',
    id: `visual-${index + 1}`,
    title: visual.title,
    accessibilitySummary: visual.accessibilitySummary,
    chartType: visual.chartType,
    xAxisLabel: visual.xAxisLabel,
    yAxisLabel: visual.yAxisLabel,
    unit: visual.unit,
    series: visual.series.map((series) => ({
        name: series.name,
        points: series.points.map((point) => ({
            label: point.label,
            value: point.value
        }))
    }))
});

const buildDiagram = (visual, index) => {
    const layout = visual.diagramType === 'sequence'
        ? createSequenceLayout(visual)
        : createDagreLayout(visual);
    return {
        kind: 'diagram',
        id: `visual-${index + 1}`,
        title: visual.title,
        accessibilitySummary: visual.accessibilitySummary,
        diagramType: visual.diagramType,
        direction: visual.direction,
        ...layout
    };
};

export const hashSourceAnswer = (sourceAnswer) => (
    createHash('sha256').update(sourceAnswer, 'utf8').digest('hex')
);

export const createVisualDocument = (generated, sourceAnswer) => {
    const validated = validateGeneratedVisuals(generated, sourceAnswer);
    return {
        contractVersion: VISUAL_CONTRACT_VERSION,
        sourceAnswerHash: hashSourceAnswer(sourceAnswer),
        visuals: validated.visuals.map((visual, index) => (
            visual.kind === 'chart'
                ? buildChart(visual, index)
                : buildDiagram(visual, index)
        ))
    };
};
