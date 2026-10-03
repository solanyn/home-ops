---
name: summarize
description: Summarize URLs, YouTube videos, podcasts, PDFs, and media files. Use for quick content digests, video summaries, or extracting key points from long content.
---

# Summarize Skill

Fast summaries from URLs, files, and media using steipete/summarize CLI.

## Usage

```bash
export PATH="/home/node/.local/bin:$PATH"
export NODE_TLS_REJECT_UNAUTHORIZED=0

# Web pages
summarize "https://example.com" --length short --plain

# YouTube (auto-detects)
summarize "https://youtu.be/dQw4w9WgXcQ" --length medium --plain

# Podcasts (RSS feed)
summarize "https://feeds.npr.org/500005/podcast.xml" --length long --plain

# Local files
summarize "/path/to/file.pdf" --length medium --plain
```

## Length Options

- `short` — ~900 chars
- `medium` — ~1,800 chars  
- `long` — ~4,200 chars
- `xl` — ~9,000 chars
- `xxl` — ~17,000 chars

Or specify chars directly: `--length 5000`

## Common Flags

- `--plain` — no ANSI formatting (use for piping)
- `--extract` — just extract content, no summary
- `--verbose` — debug output
- `--model <provider/model>` — specify LLM (default: auto)

## Notes

- Requires `NODE_TLS_REJECT_UNAUTHORIZED=0` due to container cert issues
- Works without API keys for extraction; needs keys for LLM summarization
- Supports: web pages, PDFs, images, audio/video, YouTube, podcasts, RSS
