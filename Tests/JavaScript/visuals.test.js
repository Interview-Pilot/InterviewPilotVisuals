import assert from 'node:assert/strict';
import test from 'node:test';
import {
    createVisualDocument,
    hashSourceAnswer,
    validateGeneratedVisuals,
    VisualValidationError
} from '../../Sources/JavaScript/index.js';

const sourceAnswer = `Revenue increased from 10 million in 2024 to 14 million in 2025.
Discovery leads to analysis, and analysis leads to a decision.
The candidate sends the proposal, and the interviewer reviews the proposal.`;

const chart = {
    kind: 'chart',
    title: 'Revenue growth',
    accessibilitySummary: 'Revenue rises from 10 million to 14 million.',
    chartType: 'bar',
    xAxisLabel: 'Year',
    yAxisLabel: 'Revenue',
    unit: 'million',
    series: [{
        name: 'Revenue',
        points: [
            { label: '2024', value: 10, evidence: '10 million in 2024' },
            { label: '2025', value: 14, evidence: '14 million in 2025' }
        ]
    }]
};

const flow = {
    kind: 'diagram',
    title: 'Decision flow',
    accessibilitySummary: 'Discovery is followed by analysis and a decision.',
    diagramType: 'flow',
    direction: 'leftToRight',
    nodes: [
        { id: 'discovery', label: 'Discovery', evidence: 'Discovery' },
        { id: 'analysis', label: 'Analysis', evidence: 'analysis' },
        { id: 'decision', label: 'Decision', evidence: 'decision' }
    ],
    edges: [
        {
            source: 'discovery',
            target: 'analysis',
            label: null,
            order: 0,
            evidence: 'Discovery leads to analysis'
        },
        {
            source: 'analysis',
            target: 'decision',
            label: null,
            order: 0,
            evidence: 'analysis leads to a decision'
        }
    ]
};

const sequence = {
    kind: 'diagram',
    title: 'Proposal review',
    accessibilitySummary: 'The candidate sends a proposal for interviewer review.',
    diagramType: 'sequence',
    direction: 'leftToRight',
    nodes: [
        { id: 'candidate', label: 'Candidate', evidence: 'candidate' },
        { id: 'interviewer', label: 'Interviewer', evidence: 'interviewer' }
    ],
    edges: [
        {
            source: 'candidate',
            target: 'interviewer',
            label: 'Sends proposal',
            order: 1,
            evidence: 'candidate sends the proposal'
        },
        {
            source: 'interviewer',
            target: 'candidate',
            label: 'Reviews proposal',
            order: 2,
            evidence: 'interviewer reviews the proposal'
        }
    ]
};

test('creates a bounded render document for charts and directed diagrams', () => {
    const result = createVisualDocument({ visuals: [chart, flow] }, sourceAnswer);

    assert.equal(result.contractVersion, 1);
    assert.equal(result.sourceAnswerHash, hashSourceAnswer(sourceAnswer));
    assert.equal(result.visuals.length, 2);
    assert.deepEqual(result.visuals[0].series[0].points, [
        { label: '2024', value: 10 },
        { label: '2025', value: 14 }
    ]);
    assert.ok(result.visuals[1].canvasWidth > 0);
    assert.ok(result.visuals[1].canvasHeight > 0);
    assert.equal(result.visuals[1].nodes.length, 3);
    assert.ok(result.visuals[1].edges.every((edge) => edge.points.length >= 2));
});

test('lays out sequence messages in declared order', () => {
    const result = createVisualDocument({ visuals: [sequence] }, sourceAnswer);
    const diagram = result.visuals[0];

    assert.equal(diagram.diagramType, 'sequence');
    assert.equal(diagram.edges.length, 2);
    assert.ok(diagram.edges[0].points[0].y < diagram.edges[1].points[0].y);
});

test('accepts an empty result when no visual is justified', () => {
    assert.deepEqual(validateGeneratedVisuals({ visuals: [] }, sourceAnswer), { visuals: [] });
});

test('rejects evidence that is absent from the answer', () => {
    const invalid = structuredClone(chart);
    invalid.series[0].points[0].evidence = 'unsupported source statement';

    assert.throws(
        () => createVisualDocument({ visuals: [invalid] }, sourceAnswer),
        VisualValidationError
    );
});

test('rejects more than two visuals of one kind', () => {
    assert.throws(
        () => createVisualDocument({ visuals: [chart, chart, chart] }, sourceAnswer),
        /too many chart items/u
    );
});

test('rejects cyclic hierarchy diagrams', () => {
    const hierarchy = structuredClone(flow);
    hierarchy.diagramType = 'hierarchy';
    hierarchy.edges.push({
        source: 'decision',
        target: 'discovery',
        label: null,
        order: 0,
        evidence: 'Discovery leads to analysis, and analysis leads to a decision'
    });

    assert.throws(
        () => createVisualDocument({ visuals: [hierarchy] }, sourceAnswer),
        /must not contain a cycle/u
    );
});

test('rejects duplicate or invalid sequence ordering', () => {
    const invalid = structuredClone(sequence);
    invalid.edges[1].order = 1;

    assert.throws(
        () => createVisualDocument({ visuals: [invalid] }, sourceAnswer),
        /unique positive order/u
    );
});
