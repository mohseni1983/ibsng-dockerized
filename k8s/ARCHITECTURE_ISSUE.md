# Architecture Compatibility Issue

## Problem Summary

Your Kubernetes cluster is running on **ARM64** (Apple Silicon), but the Docker image `mohseni676/ibsng-dockerized:latest` was built only for **AMD64** architecture.

**Error:**
```
Error: ErrImagePull
no matching manifest for linux/arm64/v8 in the manifest list entries
```

## Current Status

✅ **Database (PostgreSQL)**: Running successfully  
❌ **Application (IBSng)**: Cannot pull image due to architecture mismatch

## Solutions

### Option 1: Use Docker Compose (Recommended for Local Development)

Since Docker Compose supports AMD64 emulation better than Kubernetes on Docker Desktop:

```bash
cd /path/to/ibsng-dockerized
docker-compose up -d
```

This will work because Docker Desktop's regular Docker engine supports platform emulation.

### Option 2: Build Multi-Architecture Image

Build and push a multi-architecture image that supports both AMD64 and ARM64:

```bash
# Create builder (one time)
docker buildx create --name multiarch --use
docker buildx inspect --bootstrap

# Build for both architectures
docker buildx build --platform linux/amd64,linux/arm64 \
  -t mohseni676/ibsng-dockerized:latest \
  -t mohseni676/ibsng-dockerized:v1.0.0 \
  --push .
```

**Note:** CentOS 7 doesn't have official ARM64 repositories, so this may require using a different base image or building from source.

### Option 3: Use Cloud Kubernetes with AMD64 Nodes

Deploy to a cloud Kubernetes service (GKE, EKS, AKS) that has AMD64 nodes:

```bash
# Example for GKE
gcloud container clusters create ibsng-cluster \
  --machine-type=e2-medium \
  --num-nodes=2 \
  --zone=us-central1-a

# Then deploy
kubectl apply -f k8s/
```

### Option 4: Use Different Base Image

Modify the Dockerfile to use a base image that supports ARM64:

```dockerfile
# Instead of centos:7, use:
FROM rockylinux:8  # or almalinux:8, or ubuntu:22.04
```

Then rebuild and push the image.

### Option 5: Enable Platform Emulation in Docker Desktop

1. Open Docker Desktop
2. Go to Settings → General
3. Enable "Use Rosetta for x86/amd64 emulation on Apple Silicon"
4. Restart Docker Desktop
5. Try deploying again

**Note:** This may not work for Kubernetes, as Kubernetes in Docker Desktop uses containerd which may not support emulation the same way.

## Quick Workaround: Use Local Image

If you have the image locally:

```bash
# Load image into Kubernetes
docker save mohseni676/ibsng-dockerized:latest | \
  docker exec -i $(docker ps -q -f name=k8s) ctr -n k8s.io images import -

# Or use kind/kindest to load
kind load docker-image mohseni676/ibsng-dockerized:latest
```

## Recommended Action

For **local development on Apple Silicon Mac**:
- Use **Docker Compose** instead of Kubernetes
- The docker-compose.yml file is already configured and working

For **production deployment**:
- Use a cloud Kubernetes service with AMD64 nodes
- Or build a proper multi-architecture image
- Or migrate to a base image that supports ARM64

## Current Deployment Status

```bash
# Check status
kubectl get pods -n ibsng

# Database is working:
# ✅ ibsng-db: Running

# Application needs architecture fix:
# ❌ ibsng-app: ImagePullBackOff
```

## Next Steps

1. **Immediate**: Use `docker-compose up -d` for local development
2. **Short-term**: Deploy to cloud K8s with AMD64 nodes
3. **Long-term**: Build proper multi-arch image or migrate base OS

---

**Last Updated**: 2025-11-22  
**Issue**: Architecture mismatch (AMD64 image on ARM64 cluster)

