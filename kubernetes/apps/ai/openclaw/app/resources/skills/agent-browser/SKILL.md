---
name: agent-browser
description: Browser automation CLI for AI agents. Use when navigating websites, filling forms, clicking buttons, taking screenshots, extracting data, scraping pages, or automating any browser task. Triggers on "open a website", "fill out a form", "click a button", "take a screenshot", "scrape data", "login to a site".
---

# Browser Automation (agent-browser)

CLI uses Chrome/Chromium via CDP. Installed globally via bun.

## Core Workflow

1. Navigate: `agent-browser open <url>`
2. Snapshot: `agent-browser snapshot -i` (get element refs like `@e1`, `@e2`)
3. Interact: Use refs to click, fill, select
4. Re-snapshot: After navigation or DOM changes

```bash
export PATH="/workspace/.bun/bin:/tmp:$PATH"

agent-browser open https://example.com/form
agent-browser snapshot -i
# Output: @e1 [input type="email"], @e2 [button] "Submit"

agent-browser fill @e1 "user@example.com"
agent-browser click @e2
agent-browser wait 2000
agent-browser snapshot -i
```

## Commands

```bash
agent-browser open <url>              # Navigate
agent-browser snapshot -i             # Get interactive element refs
agent-browser screenshot              # Full page screenshot
agent-browser screenshot --selector ".main"  # Element screenshot
agent-browser click @e1               # Click element
agent-browser fill @e1 "text"         # Fill input
agent-browser select @e1 "option"     # Select dropdown
agent-browser type "text"             # Type without targeting
agent-browser wait 2000               # Wait ms
agent-browser scroll down             # Scroll
agent-browser evaluate "document.title"  # Run JS
agent-browser close                   # Close browser
```

## Command Chaining

```bash
agent-browser open https://example.com && agent-browser snapshot -i
agent-browser fill @e1 "user" && agent-browser fill @e2 "pass" && agent-browser click @e3
```

Chain when you don't need intermediate output. Run separately when you need to parse refs.

## Extract Data

```bash
agent-browser open https://example.com
agent-browser evaluate "JSON.stringify([...document.querySelectorAll('h2')].map(e => e.textContent))"
```

## Screenshots

```bash
agent-browser screenshot                    # PNG to stdout
agent-browser screenshot --output page.png  # Save to file
agent-browser screenshot --full-page        # Full scrollable page
```

## Notes

- Browser persists between commands via background daemon
- First run may need `agent-browser install` to download Chrome
- Sandbox has no display — headless mode only
- Useful for scraping recipe sites, checking deploy previews, etc.
