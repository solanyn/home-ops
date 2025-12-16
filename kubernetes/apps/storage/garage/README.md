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

### 3. Create Shared Key

```bash
kubectl exec -n storage garage-0 -- garage key create shared-key
kubectl exec -n storage garage-0 -- garage key info shared-key
```

Store the Key ID and Secret key in 1Password under `garage` entry as:
- `GARAGE_ROOT_USER` = Key ID  
- `GARAGE_ROOT_PASSWORD` = Secret key

### 4. Create Buckets

```bash
services="open-webui mlflow label-studio cloudnative-pg dragonfly pxc kubeflow trino"

for service in $services; do
  kubectl exec -n storage garage-0 -- garage bucket create "$service"
  kubectl exec -n storage garage-0 -- garage bucket allow --read --write --owner "$service" --key shared-key
done
```

### 5. Verify

```bash
kubectl exec -n storage garage-0 -- garage bucket list
kubectl exec -n storage garage-0 -- garage key list
```

## Notes

- All services use the same shared credentials
- Credentials stored in 1Password `garage` entry for ExternalSecrets
- Bootstrap is idempotent - commands can be re-run safely
