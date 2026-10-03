---
name: mermaid
description: Render Mermaid diagrams to PNG or SVG using beautiful-mermaid + resvg. Use when asked to create flowcharts, sequence diagrams, state diagrams, class diagrams, ER diagrams, or any visual diagram. Prefer PNG output sent as images over code blocks.
---

# Mermaid Diagram Rendering

Render Mermaid markup to PNG (default) or SVG using `beautiful-mermaid` → `@resvg/resvg-js`.

## Quick Reference

```bash
# PNG (default) — binary output, redirect to file
echo 'graph TD
  A[Start] --> B{Decision}
  B -->|Yes| C[Do thing]
  B -->|No| D[Skip]' | bun /workspace/scripts/mermaid.mjs > /tmp/diagram.png

# SVG output
echo 'graph TD
  A --> B' | bun /workspace/scripts/mermaid.mjs --svg > /tmp/diagram.svg

# ASCII output (for terminal / text-only contexts)
echo 'graph TD
  A --> B' | bun /workspace/scripts/mermaid.mjs --ascii

# Custom width (default 800px)
echo 'graph TD
  A --> B' | bun /workspace/scripts/mermaid.mjs --width 1200 > /tmp/wide.png
```

## Rendering Pipeline

1. Mermaid markup → `beautiful-mermaid` `renderMermaidSVG()` → SVG string
2. SVG → `@resvg/resvg-js` → PNG buffer (when not `--svg`)
3. Inter fonts loaded from `/workspace/.fonts/` (36 OTF files)

## Programmatic Usage (bun)

When the script doesn't cover your needs, use the libraries directly:

```javascript
const { renderMermaidSVG, THEMES } = require('beautiful-mermaid');
const { Resvg } = require('@resvg/resvg-js');
const fs = require('fs');

// Render SVG with custom colors
const svg = renderMermaidSVG(mermaidCode, { bg: '#1E1E2E', fg: '#CDD6F4' });

// Convert to PNG
const resvg = new Resvg(svg, {
  fitTo: { mode: 'width', value: 800 },
  font: { fontDirs: ['/workspace/.fonts'] },
});
const png = resvg.render().asPng();
fs.writeFileSync('/tmp/diagram.png', png);
```

### Available Themes

`THEMES` keys: `zinc-light`, `zinc-dark`, `tokyo-night`, `tokyo-night-storm`, `tokyo-night-light`, `catppuccin-mocha`, `catppuccin-latte`, `nord`, `nord-light`, `dracula`, `github-light`, `github-dark`, `solarized-light`, `solarized-dark`, `one-dark`

Pass theme colors via `{ bg, fg }` options to `renderMermaidSVG()`.

### Available Functions

| Function | Returns | Notes |
|---|---|---|
| `renderMermaidSVG(code, opts?)` | SVG string | Sync, main workhorse |
| `renderMermaidSync(code, opts?)` | SVG string | Alias |
| `renderMermaidASCII(code)` | ASCII art string | For terminal/text output |
| `renderMermaid(code)` | Promise | Async variant |
| `parseMermaid(code)` | Parsed AST | For inspection |

## Sending Diagrams in Chat

Always render to PNG and send as an image attachment — not as a code block. Diagrams are visual; show them visually.

```bash
# Render to temp file, then attach
echo '<mermaid code>' | bun /workspace/scripts/mermaid.mjs > /tmp/diagram.png
# Then use the message tool with file attachment pointing to /tmp/diagram.png
```

## Supported Diagram Types

### Flowchart
```
graph TD
  A[Start] --> B{Decision}
  B -->|Yes| C[Action]
  B -->|No| D[Other]
  C --> E[End]
  D --> E
```

### Sequence Diagram
```
sequenceDiagram
  participant A as Client
  participant B as Server
  A->>B: Request
  B-->>A: Response
```

### State Diagram
```
stateDiagram-v2
  [*] --> Idle
  Idle --> Processing: start
  Processing --> Done: complete
  Processing --> Error: fail
  Error --> Idle: retry
  Done --> [*]
```

### Class Diagram
```
classDiagram
  class Animal {
    +String name
    +makeSound()
  }
  class Dog {
    +fetch()
  }
  Animal <|-- Dog
```

### ER Diagram
```
erDiagram
  USER ||--o{ ORDER : places
  ORDER ||--|{ LINE_ITEM : contains
  PRODUCT ||--o{ LINE_ITEM : "ordered in"
```

## Troubleshooting

### Fonts not rendering / fallback fonts
- Inter fonts must be at `/workspace/.fonts/` (36 OTF files)
- resvg needs `font: { fontDirs: ['/workspace/.fonts'] }` in options
- The SVG references `@import url(fonts.googleapis.com/...)` which only works in browsers; resvg uses local fonts instead

### PNG is too small / blurry
- Use `--width 1200` or `--width 1600` for complex diagrams (default: 800)
- Programmatically: increase `fitTo.value` in resvg options

### Script not found / bun issues
- Script path: `/workspace/scripts/mermaid.mjs`
- Run with `bun`, not `node` or `npx tsx` (bun is available in sandbox)
- Dependencies in `/workspace/node_modules/`

### Diagram syntax errors
- `beautiful-mermaid` throws on invalid syntax — check Mermaid docs for correct markup
- Common gotcha: special characters in labels need quotes (`A["Label with (parens)"]`)
