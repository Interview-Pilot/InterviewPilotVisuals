import {
    CHART_TYPES,
    DIAGRAM_DIRECTIONS,
    DIAGRAM_TYPES,
    VISUAL_LIMITS
} from './constants.js';

export class VisualValidationError extends Error {
    constructor(message) {
        super(message);
        this.name = 'VisualValidationError';
    }
}

const fail = (message) => {
    throw new VisualValidationError(message);
};

const requireObject = (value, path) => {
    if (!value || typeof value !== 'object' || Array.isArray(value)) {
        fail(`${path} must be an object`);
    }
    return value;
};

const requireExactKeys = (value, path, keys) => {
    const actual = Object.keys(value).sort();
    const expected = [...keys].sort();
    if (actual.length !== expected.length || actual.some((key, index) => key !== expected[index])) {
        fail(`${path} contains unsupported fields`);
    }
};

const requireArray = (value, path, minimum, maximum) => {
    if (!Array.isArray(value) || value.length < minimum || value.length > maximum) {
        fail(`${path} must contain between ${minimum} and ${maximum} items`);
    }
    return value;
};

const requireString = (value, path, maximum, nullable = false) => {
    if (nullable && value === null) return null;
    if (typeof value !== 'string') fail(`${path} must be a string`);
    const trimmed = value.trim();
    if (!trimmed || trimmed.length > maximum || /[\u0000-\u0008\u000B\u000C\u000E-\u001F]/u.test(trimmed)) {
        fail(`${path} is invalid`);
    }
    return trimmed;
};

const requireEnum = (value, path, allowed) => {
    if (!allowed.includes(value)) fail(`${path} is unsupported`);
    return value;
};

const requireNumber = (value, path) => {
    if (typeof value !== 'number' || !Number.isFinite(value)) {
        fail(`${path} must be a finite number`);
    }
    return value;
};

const requireInteger = (value, path, minimum, maximum) => {
    if (!Number.isInteger(value) || value < minimum || value > maximum) {
        fail(`${path} must be an integer between ${minimum} and ${maximum}`);
    }
    return value;
};

const normalizeWhitespace = (value) => value.replace(/\s+/gu, ' ').trim();

const requireEvidence = (value, answer, path) => {
    const evidence = requireString(value, path, 500);
    if (!normalizeWhitespace(answer).includes(normalizeWhitespace(evidence))) {
        fail(`${path} is not grounded in the source answer`);
    }
    return evidence;
};

const sanitizeChart = (value, answer, path) => {
    requireObject(value, path);
    requireExactKeys(value, path, [
        'kind',
        'title',
        'accessibilitySummary',
        'chartType',
        'xAxisLabel',
        'yAxisLabel',
        'unit',
        'series'
    ]);
    if (value.kind !== 'chart') fail(`${path}.kind must be chart`);

    let totalPoints = 0;
    const series = requireArray(
        value.series,
        `${path}.series`,
        1,
        VISUAL_LIMITS.maximumChartSeries
    ).map((item, seriesIndex) => {
        const seriesPath = `${path}.series[${seriesIndex}]`;
        requireObject(item, seriesPath);
        requireExactKeys(item, seriesPath, ['name', 'points']);
        const points = requireArray(
            item.points,
            `${seriesPath}.points`,
            1,
            VISUAL_LIMITS.maximumChartPointsPerSeries
        ).map((point, pointIndex) => {
            const pointPath = `${seriesPath}.points[${pointIndex}]`;
            requireObject(point, pointPath);
            requireExactKeys(point, pointPath, ['label', 'value', 'evidence']);
            totalPoints += 1;
            return {
                label: requireString(point.label, `${pointPath}.label`, 80),
                value: requireNumber(point.value, `${pointPath}.value`),
                evidence: requireEvidence(point.evidence, answer, `${pointPath}.evidence`)
            };
        });
        return {
            name: requireString(item.name, `${seriesPath}.name`, 80),
            points
        };
    });
    if (totalPoints > VISUAL_LIMITS.maximumChartPoints) {
        fail(`${path} exceeds the total chart point limit`);
    }

    return {
        kind: 'chart',
        title: requireString(value.title, `${path}.title`, 120),
        accessibilitySummary: requireString(
            value.accessibilitySummary,
            `${path}.accessibilitySummary`,
            500
        ),
        chartType: requireEnum(value.chartType, `${path}.chartType`, CHART_TYPES),
        xAxisLabel: requireString(value.xAxisLabel, `${path}.xAxisLabel`, 80, true),
        yAxisLabel: requireString(value.yAxisLabel, `${path}.yAxisLabel`, 80, true),
        unit: requireString(value.unit, `${path}.unit`, 40, true),
        series
    };
};

const hasHierarchyCycle = (nodes, edges) => {
    const adjacency = new Map(nodes.map((node) => [node.id, []]));
    for (const edge of edges) adjacency.get(edge.source).push(edge.target);
    const visiting = new Set();
    const visited = new Set();
    const visit = (id) => {
        if (visiting.has(id)) return true;
        if (visited.has(id)) return false;
        visiting.add(id);
        if (adjacency.get(id).some(visit)) return true;
        visiting.delete(id);
        visited.add(id);
        return false;
    };
    return nodes.some((node) => visit(node.id));
};

const sanitizeDiagram = (value, answer, path) => {
    requireObject(value, path);
    requireExactKeys(value, path, [
        'kind',
        'title',
        'accessibilitySummary',
        'diagramType',
        'direction',
        'nodes',
        'edges'
    ]);
    if (value.kind !== 'diagram') fail(`${path}.kind must be diagram`);

    const nodes = requireArray(
        value.nodes,
        `${path}.nodes`,
        2,
        VISUAL_LIMITS.maximumDiagramNodes
    ).map((node, index) => {
        const nodePath = `${path}.nodes[${index}]`;
        requireObject(node, nodePath);
        requireExactKeys(node, nodePath, ['id', 'label', 'evidence']);
        const id = requireString(node.id, `${nodePath}.id`, 32);
        if (!/^[A-Za-z][A-Za-z0-9_-]{0,31}$/u.test(id)) {
            fail(`${nodePath}.id is invalid`);
        }
        return {
            id,
            label: requireString(node.label, `${nodePath}.label`, 100),
            evidence: requireEvidence(node.evidence, answer, `${nodePath}.evidence`)
        };
    });
    const nodeIds = new Set(nodes.map((node) => node.id));
    if (nodeIds.size !== nodes.length) fail(`${path}.nodes contains duplicate ids`);

    const edges = requireArray(
        value.edges,
        `${path}.edges`,
        1,
        VISUAL_LIMITS.maximumDiagramEdges
    ).map((edge, index) => {
        const edgePath = `${path}.edges[${index}]`;
        requireObject(edge, edgePath);
        requireExactKeys(edge, edgePath, ['source', 'target', 'label', 'order', 'evidence']);
        const source = requireString(edge.source, `${edgePath}.source`, 32);
        const target = requireString(edge.target, `${edgePath}.target`, 32);
        if (!nodeIds.has(source) || !nodeIds.has(target) || source === target) {
            fail(`${edgePath} references invalid nodes`);
        }
        return {
            source,
            target,
            label: requireString(edge.label, `${edgePath}.label`, 100, true),
            order: requireInteger(edge.order, `${edgePath}.order`, 0, 99),
            evidence: requireEvidence(edge.evidence, answer, `${edgePath}.evidence`)
        };
    });

    const diagramType = requireEnum(value.diagramType, `${path}.diagramType`, DIAGRAM_TYPES);
    if (diagramType === 'hierarchy' && hasHierarchyCycle(nodes, edges)) {
        fail(`${path} hierarchy must not contain a cycle`);
    }
    if (diagramType === 'sequence') {
        const orders = edges.map((edge) => edge.order);
        if (orders.some((order) => order < 1) || new Set(orders).size !== orders.length) {
            fail(`${path} sequence edges must have unique positive order values`);
        }
    }

    return {
        kind: 'diagram',
        title: requireString(value.title, `${path}.title`, 120),
        accessibilitySummary: requireString(
            value.accessibilitySummary,
            `${path}.accessibilitySummary`,
            500
        ),
        diagramType,
        direction: requireEnum(value.direction, `${path}.direction`, DIAGRAM_DIRECTIONS),
        nodes,
        edges
    };
};

export const validateGeneratedVisuals = (value, sourceAnswer) => {
    requireObject(value, 'visual generation');
    requireExactKeys(value, 'visual generation', ['visuals']);
    if (typeof sourceAnswer !== 'string' || !sourceAnswer.trim()) {
        fail('source answer is required');
    }

    const counts = { chart: 0, diagram: 0 };
    const visuals = requireArray(
        value.visuals,
        'visuals',
        0,
        VISUAL_LIMITS.maximumVisuals
    ).map((visual, index) => {
        const kind = visual?.kind;
        if (kind !== 'chart' && kind !== 'diagram') {
            fail(`visuals[${index}].kind is unsupported`);
        }
        counts[kind] += 1;
        if (counts[kind] > VISUAL_LIMITS.maximumVisualsPerKind) {
            fail(`visuals contains too many ${kind} items`);
        }
        return kind === 'chart'
            ? sanitizeChart(visual, sourceAnswer, `visuals[${index}]`)
            : sanitizeDiagram(visual, sourceAnswer, `visuals[${index}]`);
    });

    return { visuals };
};
