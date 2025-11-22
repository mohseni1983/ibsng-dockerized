# Kubernetes Deployment Troubleshooting

## Common Issues and Solutions

### Issue: ImagePullBackOff - Architecture Mismatch

**Error:**
```
Error: ErrImagePull
Failed to pull image "mohseni676/ibsng-dockerized:latest": 
no matching manifest for linux/arm64/v8 in the manifest list entries
```

**Cause:** The image was built for AMD64 but your cluster is running on ARM64 (Apple Silicon).

**Solutions:**

#### Option 1: Use AMD64 Emulation (Docker Desktop)

Docker Desktop on Mac supports AMD64 emulation. Ensure it's enabled:

1. Open Docker Desktop
2. Go to Settings → Features in development
3. Enable "Use containerd for pulling and storing images" (if available)
4. Or ensure "Use Rosetta for x86/amd64 emulation on Apple Silicon" is enabled

Then restart the pod:
```bash
kubectl delete pod -n ibsng -l component=application
```

#### Option 2: Rebuild Image for Multi-Arch

Build and push a multi-architecture image:

```bash
# Create a new builder (if needed)
docker buildx create --name multiarch --use

# Build and push for both architectures
docker buildx build --platform linux/amd64,linux/arm64 \
  -t mohseni676/ibsng-dockerized:latest \
  --push .
```

#### Option 3: Use Platform-Specific Tag

If you have an AMD64-only image, use a specific tag:

```bash
# Update deployment to use AMD64 tag
kubectl set image deployment/ibsng-app ibsng=mohseni676/ibsng-dockerized:latest-amd64 -n ibsng
```

#### Option 4: Force Node Architecture

Add nodeSelector to deployment to run on AMD64 nodes (if available):

```yaml
spec:
  template:
    spec:
      nodeSelector:
        kubernetes.io/arch: amd64
```

### Issue: Database Connection Errors

**Error:**
```
FATAL: database "ibs" does not exist
```

**Solution:** The database initialization might not have completed. Check database logs:

```bash
kubectl logs -f deployment/ibsng-db -n ibsng
```

Wait for the database to be fully initialized before the app starts.

### Issue: Pods Stuck in Pending

**Error:**
```
0/1 nodes are available: pod has unbound immediate PersistentVolumeClaims
```

**Solution:** Check PVC status:

```bash
kubectl get pvc -n ibsng
kubectl describe pvc <pvc-name> -n ibsng
```

Ensure your cluster has a storage class configured and sufficient storage.

### Issue: Health Check Failures

**Error:**
```
Readiness probe failed
Liveness probe failed
```

**Solution:** The application might need more time to start. Adjust probe timings:

```yaml
livenessProbe:
  initialDelaySeconds: 120  # Increase from 60
readinessProbe:
  initialDelaySeconds: 60   # Increase from 40
```

### Issue: Cannot Access Web Interface

**Check Service Type:**

```bash
kubectl get svc ibsng-app -n ibsng
```

- **LoadBalancer**: Wait for external IP assignment
- **NodePort**: Use `<NODE-IP>:<NODE-PORT>`
- **ClusterIP**: Use port-forward:

```bash
kubectl port-forward svc/ibsng-app 8080:80 -n ibsng
# Then access: http://localhost:8080/IBSng/admin
```

### Issue: Init Container Failing

**Error:** `wait-for-db` init container keeps restarting

**Solution:** Check database connectivity:

```bash
# Test from init container
kubectl exec -it <pod-name> -n ibsng -c wait-for-db -- \
  pg_isready -h ibsng-db -p 5432 -U ibs

# Check database service
kubectl get svc ibsng-db -n ibsng
kubectl get endpoints ibsng-db -n ibsng
```

### General Debugging Commands

```bash
# Check all resources
kubectl get all -n ibsng

# View pod events
kubectl describe pod <pod-name> -n ibsng

# View logs
kubectl logs -f deployment/ibsng-app -n ibsng
kubectl logs -f deployment/ibsng-db -n ibsng

# Check recent events
kubectl get events -n ibsng --sort-by='.lastTimestamp'

# Check resource usage
kubectl top pods -n ibsng

# Shell into pod
kubectl exec -it <pod-name> -n ibsng -- /bin/bash
```

### Quick Fixes

**Restart deployment:**
```bash
kubectl rollout restart deployment/ibsng-app -n ibsng
kubectl rollout restart deployment/ibsng-db -n ibsng
```

**Delete and recreate:**
```bash
kubectl delete deployment ibsng-app -n ibsng
kubectl apply -f k8s/ibsng-deployment.yaml
```

**Check image pull secrets (if using private registry):**
```bash
kubectl get secrets -n ibsng
```

---

For more help, check the main README.md in the k8s directory.

