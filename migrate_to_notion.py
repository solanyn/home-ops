#!/usr/bin/env python3

import os
import json
from pathlib import Path
from notion_client import Client

# Setup
NOTION_TOKEN = os.getenv("NOTION_TOKEN")
PARENT_PAGE_ID = os.getenv("NOTION_PARENT_PAGE_ID")
VAULT_PATH = Path("your_obsidian_vault_path")

notion = Client(auth=NOTION_TOKEN)

def create_page(title, content, parent_id):
    """Create a Notion page with markdown content"""
    try:
        # Convert markdown to Notion blocks (simplified)
        blocks = []
        for line in content.split('\n'):
            if line.strip():
                if line.startswith('# '):
                    blocks.append({
                        "object": "block",
                        "type": "heading_1",
                        "heading_1": {"rich_text": [{"type": "text", "text": {"content": line[2:]}}]}
                    })
                elif line.startswith('## '):
                    blocks.append({
                        "object": "block", 
                        "type": "heading_2",
                        "heading_2": {"rich_text": [{"type": "text", "text": {"content": line[3:]}}]}
                    })
                else:
                    blocks.append({
                        "object": "block",
                        "type": "paragraph", 
                        "paragraph": {"rich_text": [{"type": "text", "text": {"content": line}}]}
                    })
        
        page = notion.pages.create(
            parent={"page_id": parent_id},
            properties={"title": {"title": [{"type": "text", "text": {"content": title}}]}},
            children=blocks[:100]  # Notion API limit
        )
        return page["url"]
    except Exception as e:
        print(f"Error creating {title}: {e}")
        return None

def migrate_vault():
    """Migrate all markdown files"""
    for md_file in VAULT_PATH.rglob("*.md"):
        if md_file.name.startswith('.'):
            continue
            
        with open(md_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        title = md_file.stem
        url = create_page(title, content, PARENT_PAGE_ID)
        
        if url:
            print(f"✓ {title} → {url}")
        else:
            print(f"✗ Failed: {title}")

if __name__ == "__main__":
    migrate_vault()
