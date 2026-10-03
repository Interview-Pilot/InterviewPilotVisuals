import { readFileSync } from 'node:fs';

const readSchema = (name) => JSON.parse(readFileSync(
    new URL(`../../Schemas/${name}`, import.meta.url),
    'utf8'
));

export const visualGenerationSchema = Object.freeze(
    readSchema('visual-generation-v1.schema.json')
);

export const visualDocumentSchema = Object.freeze(
    readSchema('visual-document-v1.schema.json')
);
