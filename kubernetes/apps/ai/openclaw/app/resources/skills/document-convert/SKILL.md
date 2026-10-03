---
name: document-convert
description: Convert documents to markdown using markitdown. Supports docx, pdf, xlsx, pptx, images, html, audio, and more. Use when extracting text from documents, converting files to markdown, or processing attachments.
---

# Document Convert Skill

Convert documents to markdown using Microsoft's markitdown tool via uvx.

## Usage

```bash
uvx --from "markitdown[all]" markitdown <file>
```

## Supported Formats

| Format | Extensions | Notes |
|--------|------------|-------|
| Word | .docx | Full formatting preserved |
| PDF | .pdf | Text extraction, tables |
| Excel | .xlsx | Converts to markdown tables |
| PowerPoint | .pptx | Slides as sections |
| Images | .jpg, .png, .gif | OCR/description (needs vision) |
| HTML | .html | Clean markdown conversion |
| Audio | .mp3, .wav | Transcription (needs ffmpeg) |
| CSV | .csv | Markdown tables |
| JSON | .json | Formatted output |
| XML | .xml | Structured extraction |
| ZIP | .zip | Lists contents |

## Examples

### Convert a Word document
```bash
uvx --from "markitdown[all]" markitdown resume.docx
```

### Convert PDF and save to file
```bash
uvx --from "markitdown[all]" markitdown report.pdf > report.md
```

### Convert Excel spreadsheet
```bash
uvx --from "markitdown[all]" markitdown data.xlsx
```

### Convert from URL
```bash
uvx --from "markitdown[all]" markitdown https://example.com/doc.pdf
```

## Notes

- First run downloads dependencies (~50MB), subsequent runs are cached
- Audio transcription requires ffmpeg (not available in all environments)
- Image OCR/description may require additional AI model configuration
- Output goes to stdout - redirect to file if needed

## Troubleshooting

**Missing dependency error:**
Use `markitdown[all]` to include all converters:
```bash
uvx --from "markitdown[all]" markitdown file.docx
```

**pydub warning about ffmpeg:**
Safe to ignore unless processing audio files.
