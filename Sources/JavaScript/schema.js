import { readFileSync } from 'node:fs';

const readSchema = (name) => JSON.parse(readFileSync(
    new URL(`../../Schemas/${name}`, import.meta.url),
    'utf8'
));

export const visualGenerationSchema = Object.freeze(
    readSchema('visual-generation-v1.schema.json')
);

const {
    $schema: _generationDialect,
    $id: _generationId,
    title: _generationTitle,
    ...generationProviderSchema
} = visualGenerationSchema;

// Structured-output providers accept the contract body, not JSON Schema's
// document metadata. Runtime validation remains authoritative for all limits.
export const visualGenerationProviderSchema = Object.freeze(generationProviderSchema);

export const visualDocumentSchema = Object.freeze(
    readSchema('visual-document-v1.schema.json')
);
