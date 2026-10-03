#!/bin/bash
# Check Migadu inbox for new/unread emails
# Usage: ./check-inbox.sh [--unread] [--folder INBOX] [--limit 10]

set -e

FOLDER="INBOX"
LIMIT=10
SEARCH="ALL"

while [[ $# -gt 0 ]]; do
  case $1 in
    --unread) SEARCH="UNSEEN"; shift ;;
    --folder) FOLDER="$2"; shift 2 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

PASSWORD=$(op read "op://kubernetes/migadu/IMAP_PASSWORD")

(
echo "a1 LOGIN hawow.shmawow@goyangi.io $PASSWORD"
echo "a2 SELECT \"$FOLDER\""
echo "a3 SEARCH $SEARCH"
echo "a4 LOGOUT"
) | openssl s_client -connect imap.migadu.com:993 -quiet 2>/dev/null | grep -E "^\* SEARCH|a[0-9]+ OK"
