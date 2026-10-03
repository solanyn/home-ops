#!/usr/bin/env python3
"""Scan Gmail for tax-deductible receipts and upload to Paperless-ngx.

Searches Gmail for new emails from known vendors (Origin, Launtel, Cloudflare,
Anomaly/OpenCode Go, Anthropic, etc.) with PDF attachments, downloads them,
and uploads to Paperless with appropriate tags and correspondents.

Outputs a summary for the morning briefing.
"""

import base64
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timedelta
from pathlib import Path

# Add google-workspace scripts to path
sys.path.insert(0, "/opt/data/skills/productivity/google-workspace/scripts")
from google_api import build_service

# Configuration
PAPERLESS_URL = "http://paperless.default.svc.cluster.local:8000/api"
PAPERLESS_TOKEN = os.environ.get("PAPERLESS_TOKEN", "")
DOWNLOAD_DIR = Path("/tmp/paperless_scan")
DOWNLOAD_DIR.mkdir(exist_ok=True)

# Vendor definitions: (search_query, correspondent_name, tag_names, is_tax_deductible)
VENDORS = [
    # WFH claims - electricity
    ("from:origin.com.au subject:bill", "Origin Energy", ["wfh-claim", "electricity"], True),
    # WFH claims - internet
    ("from:launtel.net.au subject:receipt", "Launtel", ["wfh-claim", "internet"], True),
    # Software subscriptions
    ("from:anoma.ly subject:receipt", "Anomaly / OpenCode Go", ["wfh-claim", "software-subscription"], True),
    ("from:anthropic.com subject:receipt", "Anthropic", ["wfh-claim", "software-subscription"], True),
    ("from:openai.com subject:receipt", "OpenAI", ["wfh-claim", "software-subscription"], True),
    # Hosting
    ("from:cloudflare.com subject:invoice", "Cloudflare", ["wfh-claim", "hosting"], True),
    # Email hosting
    ("from:migadu.com subject:renewal", "Migadu", ["wfh-claim", "email-hosting"], True),

    # Equipment
    ("from:jbhifi.com.au subject:invoice", "JB Hi-Fi", ["wfh-claim", "equipment"], True),
    # Pay slips (already in Paperless but good to catch new ones)
    ("subject:payslip OR subject:pay advice", "Employer", ["payslip"], False),
]

# Tags: name -> id mapping (created on first run)
TAG_CACHE = {}
CORRESPONDENT_CACHE = {}


def get_or_create_tag(name: str) -> int:
    """Get tag ID by name, creating if needed."""
    if name in TAG_CACHE:
        return TAG_CACHE[name]
    
    # Search existing
    result = subprocess.run(
        ["curl", "-s", f"{PAPERLESS_URL}/tags/?search={name}",
         "-H", f"Authorization: Token {PAPERLESS_TOKEN}",
         "-H", "Accept: application/json"],
        capture_output=True, text=True
    )
    data = json.loads(result.stdout)
    for tag in data.get("results", []):
        if tag["name"] == name:
            TAG_CACHE[name] = tag["id"]
            return tag["id"]
    
    # Create
    result = subprocess.run(
        ["curl", "-s", "-X", "POST", f"{PAPERLESS_URL}/tags/",
         "-H", f"Authorization: Token {PAPERLESS_TOKEN}",
         "-H", "Content-Type: application/json",
         "-d", json.dumps({"name": name})],
        capture_output=True, text=True
    )
    tag = json.loads(result.stdout)
    TAG_CACHE[name] = tag["id"]
    return tag["id"]


def get_or_create_correspondent(name: str) -> int:
    """Get correspondent ID by name, creating if needed."""
    if name in CORRESPONDENT_CACHE:
        return CORRESPONDENT_CACHE[name]
    
    # Search existing
    result = subprocess.run(
        ["curl", "-s", f"{PAPERLESS_URL}/correspondents/?search={name}",
         "-H", f"Authorization: Token {PAPERLESS_TOKEN}",
         "-H", "Accept: application/json"],
        capture_output=True, text=True
    )
    data = json.loads(result.stdout)
    for corr in data.get("results", []):
        if corr["name"] == name:
            CORRESPONDENT_CACHE[name] = corr["id"]
            return corr["id"]
    
    # Create
    result = subprocess.run(
        ["curl", "-s", "-X", "POST", f"{PAPERLESS_URL}/correspondents/",
         "-H", f"Authorization: Token {PAPERLESS_TOKEN}",
         "-H", "Content-Type: application/json",
         "-d", json.dumps({"name": name})],
        capture_output=True, text=True
    )
    corr = json.loads(result.stdout)
    CORRESPONDENT_CACHE[name] = corr["id"]
    return corr["id"]


def check_already_uploaded(subject: str, date: str) -> bool:
    """Check if a document with this subject+date is already in Paperless."""
    # Simple check: search by title
    title_part = subject[:30].replace(" ", "+")
    result = subprocess.run(
        ["curl", "-s", f"{PAPERLESS_URL}/documents/?title={title_part}",
         "-H", f"Authorization: Token {PAPERLESS_TOKEN}",
         "-H", "Accept: application/json"],
        capture_output=True, text=True
    )
    data = json.loads(result.stdout)
    return data.get("count", 0) > 0


def download_attachment(message_id: str, filename: str) -> str | None:
    """Download a PDF attachment from a Gmail message."""
    service = build_service("gmail", "v1")
    msg = service.users().messages().get(
        userId="me", id=message_id, format="full"
    ).execute()
    
    payload = msg.get("payload", {})
    
    def process_parts(parts):
        for part in parts:
            if part.get("filename") == filename:
                attachment_id = part.get("body", {}).get("attachmentId")
                if attachment_id:
                    att = service.users().messages().attachments().get(
                        userId="me", messageId=message_id, id=attachment_id
                    ).execute()
                    data = base64.urlsafe_b64decode(att["data"])
                    out_path = DOWNLOAD_DIR / filename
                    with open(out_path, "wb") as f:
                        f.write(data)
                    return str(out_path)
            if part.get("parts"):
                result = process_parts(part["parts"])
                if result:
                    return result
        return None
    
    if payload.get("parts"):
        return process_parts(payload["parts"])
    elif payload.get("filename") == filename:
        attachment_id = payload["body"]["attachmentId"]
        att = service.users().messages().attachments().get(
            userId="me", messageId=message_id, id=attachment_id
        ).execute()
        data = base64.urlsafe_b64decode(att["data"])
        out_path = DOWNLOAD_DIR / filename
        with open(out_path, "wb") as f:
            f.write(data)
        return str(out_path)
    
    return None


def upload_to_paperless(file_path: str, title: str, correspondent_id: int, tag_ids: list[int]) -> bool:
    """Upload a document to Paperless."""
    tag_args = []
    for tid in tag_ids:
        tag_args.extend(["-F", f"tags={tid}"])
    
    cmd = [
        "curl", "-s", "-X", "POST", f"{PAPERLESS_URL}/documents/post_document/",
        "-H", f"Authorization: Token {PAPERLESS_TOKEN}",
        "-F", f"document=@{file_path}",
        "-F", f"title={title}",
        f"-F", f"correspondent={correspondent_id}",
    ] + tag_args
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.stdout.startswith('"')  # UUID response = success


def scan_vendor(service, vendor_query: str, correspondent_name: str, 
                tag_names: list[str], days_back: int = 7) -> list[dict]:
    """Scan Gmail for a specific vendor and return new receipts."""
    results = []
    
    # Search for recent emails
    query = f"{vendor_query} newer_than:{days_back}d"
    
    try:
        response = service.users().messages().list(
            userId="me", q=query, maxResults=20
        ).execute()
        
        messages = response.get("messages", [])
        
        for msg_summary in messages:
            msg_id = msg_summary["id"]
            
            # Get full message
            msg = service.users().messages().get(
                userId="me", id=msg_id, format="full"
            ).execute()
            
            headers = {h["name"].lower(): h["value"] 
                      for h in msg.get("payload", {}).get("headers", [])}
            
            subject = headers.get("subject", "")
            date = headers.get("date", "")
            from_addr = headers.get("from", "")
            
            # Check if already uploaded
            if check_already_uploaded(subject, date):
                continue
            
            # Find PDF attachments
            payload = msg.get("payload", {})
            pdf_files = []
            
            def find_pdfs(parts):
                for part in parts:
                    if part.get("filename", "").lower().endswith(".pdf"):
                        pdf_files.append(part["filename"])
                    if part.get("parts"):
                        find_pdfs(part["parts"])
            
            if payload.get("parts"):
                find_pdfs(payload["parts"])
            elif payload.get("filename", "").lower().endswith(".pdf"):
                pdf_files.append(payload["filename"])
            
            if pdf_files:
                for pdf_name in pdf_files:
                    results.append({
                        "message_id": msg_id,
                        "subject": subject,
                        "date": date,
                        "from": from_addr,
                        "filename": pdf_name,
                        "correspondent": correspondent_name,
                        "tags": tag_names,
                    })
            else:
                # No PDF attachment - note it for manual handling
                results.append({
                    "message_id": msg_id,
                    "subject": subject,
                    "date": date,
                    "from": from_addr,
                    "filename": None,  # No attachment
                    "correspondent": correspondent_name,
                    "tags": tag_names,
                    "note": "No PDF attachment (inline HTML receipt)"
                })
    
    except Exception as e:
        print(f"  Error scanning {correspondent_name}: {e}", file=sys.stderr)
    
    return results


def main():
    """Main scan function."""
    service = build_service("gmail", "v1")
    
    all_receipts = []
    new_uploads = []
    manual_needed = []
    
    print("Scanning Gmail for tax-deductible receipts...\n")
    
    for query, correspondent, tags, is_deductible in VENDORS:
        if not is_deductible:
            continue
        
        receipts = scan_vendor(service, query, correspondent, tags)
        
        if receipts:
            print(f"Found {len(receipts)} new from {correspondent}")
            
            for r in receipts:
                if r["filename"]:
                    # Download and upload
                    print(f"  Uploading: {r['filename']}")
                    file_path = download_attachment(r["message_id"], r["filename"])
                    
                    if file_path:
                        # Create title from date
                        date_match = re.search(r'(\w+),\s+(\d+\s+\w+\s+\d{4})', r["date"])
                        if date_match:
                            date_str = date_match.group(2).replace(" ", "-")
                        else:
                            date_str = datetime.now().strftime("%Y-%m-%d")
                        
                        title = f"{correspondent} {date_str}"
                        
                        # Get/create tag and correspondent IDs
                        corr_id = get_or_create_correspondent(correspondent)
                        tag_ids = [get_or_create_tag(t) for t in tags]
                        
                        # Upload
                        if upload_to_paperless(file_path, title, corr_id, tag_ids):
                            new_uploads.append(f"✓ {title}")
                            print(f"    Uploaded: {title}")
                        else:
                            print(f"    Failed to upload")
                    else:
                        print(f"    Failed to download")
                else:
                    # No PDF - note for manual handling
                    manual_needed.append({
                        "vendor": correspondent,
                        "subject": r["subject"],
                        "date": r["date"][:10] if r["date"] else "?",
                    })
    
    # Output summary
    print(f"\n{'='*60}")
    print(f"Paperless Scan Summary")
    print(f"{'='*60}")
    
    if new_uploads:
        print(f"\nNewly uploaded ({len(new_uploads)}):")
        for item in new_uploads:
            print(f"  {item}")
    
    if manual_needed:
        print(f"\nManual upload needed ({len(manual_needed)} - no PDF attachment):")
        for item in manual_needed:
            print(f"  {item['vendor']}: {item['subject'][:40]} ({item['date']})")
    
    if not new_uploads and not manual_needed:
        print("\nNo new receipts found since last scan.")
    
    return {
        "uploaded": len(new_uploads),
        "manual_needed": len(manual_needed),
        "details": new_uploads + [f"⚠ {m['vendor']}: {m['subject'][:30]}" for m in manual_needed]
    }


if __name__ == "__main__":
    result = main()
