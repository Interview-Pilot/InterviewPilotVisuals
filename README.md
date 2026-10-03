# InterviewPilotVisuals

InterviewPilotVisuals owns the versioned contract and deterministic layout used
to turn an Interview Pilot answer into optional native charts and diagrams.

The package deliberately separates responsibilities:

- A model may describe semantic chart or diagram content only.
- JavaScript validation rejects unsupported, ungrounded, or oversized output.
- JavaScript layout converts validated diagrams into bounded geometry.
- Apple clients decode the final document and render it with Swift Charts and
  SwiftUI drawing primitives.

The package never executes model-provided code, HTML, SVG, URLs, styles, or
coordinates. Invalid visual output must be discarded without affecting the
answer that produced it.

## Verification

```sh
npm ci
npm test
swift test
```
