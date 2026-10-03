---
name: compress
description: >
  Compress natural language markdown files to reduce token usage while preserving
  all technical substance, code, URLs, paths, and structure. Saves ~35-50% input tokens.
  Use when asked to compress documents, memory files, or config docs.
  Triggers on "compress", "shrink tokens", "reduce tokens", "make smaller".
---

# Compress Skill

Compress markdown/text files into terse format. Cuts ~35-50% of tokens while keeping all technical accuracy.

## How

You ARE the compressor. Read the file, apply the rules below, write the compressed version. No external LLM call needed.

## Process

1. Read the target file
2. Back up original as `FILE.original.md`
3. Apply compression rules to prose sections only
4. Write compressed version to original path
5. Report byte savings

## Compression Rules

### Remove
- Articles (a, an, the), filler (just, really, basically, actually, simply)
- Pleasantries, hedging, redundant phrasing
- "in order to" → "to", "make sure to" → "ensure", "the reason is because" → "because"
- Connective fluff: however, furthermore, additionally

### Preserve EXACTLY
- Code blocks (fenced and indented) — copy verbatim
- Inline code (`backtick content`)
- URLs, file paths, commands
- Technical terms, proper nouns, dates, versions, env vars
- Markdown structure (headings, bullets, tables, numbering)

### Compress
- Short synonyms: "big" not "extensive", "fix" not "implement a solution"
- Fragments OK: "Run tests before push" not "You should always run tests"
- Drop "you should", "remember to" — just state action
- Merge redundant bullets saying same thing differently

## Auto-Clarity

Do NOT compress: security warnings, irreversible action confirmations, multi-step sequences where fragments risk misread.

## Boundaries

- Only compress .md, .txt files
- Never modify code files
- Never compress FILE.original.md (skip it)
- If unsure whether something is code or prose, leave unchanged

## Validation

After compressing, verify:
- All headings preserved (text and level)
- All code blocks identical
- All URLs present
- All file paths present
- Bullet count within ~15% of original
