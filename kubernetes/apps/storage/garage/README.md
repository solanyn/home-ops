# Garage Bootstrap

One-time setup commands for Garage cluster initialisation.

## Prerequisites

- Garage cluster deployed and running
- `garage` CLI available in pod
- RPC secret configured

## Bootstrap Steps

### 1. Get Node ID

```bash
kubectl exec -n storage garage-dc68cd697-cr5g8 -- /garage status
# Use the node ID from output (e.g., 950f00331b70eac7)
```

### 2. Configure Cluster Layout

```bash
kubectl exec -n storage garage-dc68cd697-cr5g8 -- /garage layout assign -z dc1 -c 1G 950f00331b70eac7
kubectl exec -n storage garage-dc68cd697-cr5g8 -- /garage layout apply --version 1
```

Note: Capacity is ignored for single node deployments and can be changed when adding nodes.

### 3. Create Shared Key

```bash
kubectl exec -n storage garage-dc68cd697-cr5g8 -- /garage key create shared-key
kubectl exec -n storage garage-dc68cd697-cr5g8 -- /garage key info shared-key
```

Store the Key ID and Secret key in 1Password under `garage` entry as:
- `GARAGE_ROOT_USER` = Key ID  
- `GARAGE_ROOT_PASSWORD` = Secret key

### 4. Create Buckets

```bash
kubectl exec -n storage garage-dc68cd697-cr5g8 -- /garage bucket create open-webui
kubectl exec -n storage garage-dc68cd697-cr5g8 -- /garage bucket allow --read --write --owner open-webui --key shared-key

kubectl exec -n storage garage-dc68cd697-cr5g8 -- /garage bucket create mlflow
kubectl exec -n storage garage-dc68cd697-cr5g8 -- /garage bucket allow --read --write --owner mlflow --key shared-key

kubectl exec -n storage garage-dc68cd697-cr5g8 -- /garage bucket create label-studio
kubectl exec -n storage garage-dc68cd697-cr5g8 -- /garage bucket allow --read --write --owner label-studio --key shared-key

kubectl exec -n storage garage-dc68cd697-cr5g8 -- /garage bucket create cloudnative-pg
kubectl exec -n storage garage-dc68cd697-cr5g8 -- /garage bucket allow --read --write --owner cloudnative-pg --key shared-key

kubectl exec -n storage garage-dc68cd697-cr5g8 -- /garage bucket create dragonfly
kubectl exec -n storage garage-dc68cd697-cr5g8 -- /garage bucket allow --read --write --owner dragonfly --key shared-key

kubectl exec -n storage garage-dc68cd697-cr5g8 -- /garage bucket create pxc
kubectl exec -n storage garage-dc68cd697-cr5g8 -- /garage bucket allow --read --write --owner pxc --key shared-key

kubectl exec -n storage garage-dc68cd697-cr5g8 -- /garage bucket create kubeflow
kubectl exec -n storage garage-dc68cd697-cr5g8 -- /garage bucket allow --read --write --owner kubeflow --key shared-key

kubectl exec -n storage garage-dc68cd697-cr5g8 -- /garage bucket create trino
kubectl exec -n storage garage-dc68cd697-cr5g8 -- /garage bucket allow --read --write --owner trino --key shared-key
```

### 5. Verify

```bash
kubectl exec -n storage garage-dc68cd697-cr5g8 -- /garage bucket list
kubectl exec -n storage garage-dc68cd697-cr5g8 -- /garage key list
```

## Notes

- All services use the same shared credentials
- Credentials stored in 1Password `garage` entry for ExternalSecrets
- Bootstrap is idempotent - commands can be re-run safely
