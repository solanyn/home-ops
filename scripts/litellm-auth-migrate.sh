#!/bin/bash
# Litellm Auth Migration: Copy OAuth tokens to RWX PVC for failover
# Run from mac.internal with KUBECONFIG=~/git/home-ops/kubeconfig
# Purpose: If litellm pod restarts/fails, auth state is preserved on RWX volume
set -e

set -x

export KUBECONFIG=~/git/home-ops/kubeconfig
NODE=k8s-0

# Step 0: Verify Miroir gateway is running
echo "=== Step 0: Check Miroir gateway ==="
kubectl get pods -n miroir-system -l app.kubernetes.io/name=miroir-gateway
if ! kubectl get pods -n miroir-system -l app.kubernetes.io/name=miroir-gateway | grep -q Running; then
  echo "ERROR: Miroir gateway not ready. Enable gateway first."
  exit 1
fi

# Step 1: Verify old auth path exists
echo ""
echo "=== Step 1: Verify auth source ==="
if [ -d /var/lib/litellm/chatgpt ]; then
  echo "Source found: /var/lib/litellm/chatgpt"
  ls -la /var/lib/litellm/chatgpt
else
  echo "WARNING: /var/lib/litellm/chatgpt not found - OAuth tokens already moved?"
  echo "Check: /var/lib/litellm/"
  ls -la /var/lib/litellm/
  exit 0
fi

# Step 2: Create temp busybox pod that mounts RWX PVC
echo ""
echo "=== Step 2: Mount RWX PVC ==="
mkdir -p /tmp/auth-temp

kubectl run -it -n ai copy-pod --image=alpine:3.18 --rm \
  --overrides='{
    "spec": {
      "volumes": [{
        "name": "rwx",
        "persistentVolumeClaim": {"claimName": "litellm"}
      }],
      "containers": [{
        "name": "copy",
        "image": "alpine:3.18",
        "volumeMounts": [{"name": "rwx", "mountPath": "/tmp/rwx"}]
      }],
      "restartPolicy": "Never",
      "terminationGracePeriodSeconds": 1
    }
  }'

# Give the pod a moment to start
sleep 3

# Step 3: Copy auth data from node to RWX mount
echo ""
echo "=== Step 3: Copy auth secrets to RWX ==="
sudo cp -r /var/lib/litellm/chatgpt /tmp/rwx/ 2>&1 || {
  echo "ERROR: Failed to copy. Check permissions:"
  ls -la /tmp/rwx/
  ls -la /var/lib/litellm/
  exit 1
}

# Verify copy succeeded (inside container)
echo "Verifying copy (from inside pod):"
EXEC_OUTPUT=$(kubectl exec -n ai copy-pod -c copy -- ls -la /tmp/rwx/chatgpt 2>&1)
echo "$EXEC_OUTPUT" | grep -q chatgpt || {
  echo "ERROR: Copy not found in RWX mount!"
  echo "Contents: $EXEC_OUTPUT"
  exit 1
}
echo "✓ Copy verified"

# Step 4: Cleanup pod
echo ""
echo "=== Step 4: Cleanup pod ==="
kubectl delete pod copy-pod -n ai

# Step 5: Final verification
echo ""
echo "=== Step 5: Final verification ==="
kubectl exec -n ai tmp-litellm -- /bin/ls -la /var/lib/litellm/chatgpt 2>&1 || {
  echo "INFO: tmp-litellm not found - litellm may have restarted already"
  echo "Check litellm pod logs:"
  kubectl logs -n ai -l app.kubernetes.io/name=litellm | tail -20
}

echo ""
echo "=== Complete ==="
echo "Auth secrets copied to RWX PVC. Check that litellm pod has been updated to use RWX."

# Optional: Clean up old RWO PVC after verifying litellm restarts successfully
# Uncomment to auto-cleanup:
# kubectl delete pvc litellm-current -n ai