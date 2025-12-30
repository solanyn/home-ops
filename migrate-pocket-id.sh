#!/bin/bash
# Pocket ID PostgreSQL to SQLite migration script

set -euo pipefail

NAMESPACE="default"
APP="pocket-id"
POSTGRES_POD="postgres-rw-0"
POSTGRES_NAMESPACE="storage"

echo "=== Pocket ID Migration: PostgreSQL → SQLite ==="

# 1. Scale down pocket-id
echo "Scaling down pocket-id..."
kubectl scale deployment pocket-id -n $NAMESPACE --replicas=0

# 2. Export PostgreSQL data
echo "Exporting PostgreSQL data..."
kubectl exec -n $POSTGRES_NAMESPACE $POSTGRES_POD -- pg_dump -U postgres pocket_id > pocket_id_backup.sql

# 3. Convert PostgreSQL dump to SQLite format
echo "Converting to SQLite format..."
# This requires manual conversion or tools like pgloader
cat > convert_to_sqlite.sql << 'EOF'
-- Manual conversion needed - PostgreSQL specific syntax to SQLite
-- Common conversions:
-- SERIAL -> INTEGER PRIMARY KEY AUTOINCREMENT
-- TIMESTAMP WITH TIME ZONE -> DATETIME
-- BOOLEAN -> INTEGER (0/1)
-- TEXT[] -> TEXT (JSON array)
EOF

echo "Manual conversion required:"
echo "1. Edit pocket_id_backup.sql to convert PostgreSQL syntax to SQLite"
echo "2. Remove PostgreSQL-specific features (sequences, etc.)"
echo "3. Convert data types as needed"

# 4. Apply SQLite configuration (already done)
echo "Applying SQLite configuration..."
flux reconcile ks pocket-id

# 5. Wait for SQLite version to be ready
echo "Waiting for SQLite version..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=pocket-id -n $NAMESPACE --timeout=300s

# 6. Import data to SQLite
echo "Import data manually using kubectl exec into the pod"
echo "kubectl exec -it deployment/pocket-id -n $NAMESPACE -- sqlite3 /data/pocket-id.db < converted_data.sql"

echo "Migration preparation complete. Manual data conversion required."
