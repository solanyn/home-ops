# Garage Bootstrap

One-time setup commands for Garage cluster initialisation.

## Prerequisites

- Garage cluster deployed and running
- `garage` CLI available in pod
- RPC secret configured

## Bootstrap Steps

### 1. Get Node ID

```bash
kubectl exec -n storage garage-0 -- garage status
NODE_ID=$(kubectl exec -n storage garage-0 -- garage status | grep -v "HEALTHY NODES" | grep -v "^$" | awk '{print $1}' | head -1)
```

### 2. Configure Cluster Layout

```bash
kubectl exec -n storage garage-0 -- garage layout assign -z dc1 -c 50G "$NODE_ID"
kubectl exec -n storage garage-0 -- garage layout apply --version 1
```

### 3. Create Admin Key

```bash
kubectl exec -n storage garage-0 -- garage key create admin-key
```

### 4. Create Buckets and Keys

For each application bucket:

```bash
BUCKET="bucket-name"
kubectl exec -n storage garage-0 -- garage bucket create "$BUCKET"
kubectl exec -n storage garage-0 -- garage key create "${BUCKET}-key"
kubectl exec -n storage garage-0 -- garage bucket allow --read --write --owner "$BUCKET" --key "${BUCKET}-key"
```

Required buckets:
- bps
- cloudnative-pg
- dragonflydb
- feast
- iceberg
- kfp-pipelines
- label-studio
- milvus
- open-webui
- pxc
- tldr
- trino
- tsw

### 5. Verify

```bash
kubectl exec -n storage garage-0 -- garage bucket list
kubectl exec -n storage garage-0 -- garage key list
```

## Notes

- Bootstrap is idempotent - commands can be re-run safely
- Layout version increments with each change
- Keys are created with full permissions on their respective buckets
