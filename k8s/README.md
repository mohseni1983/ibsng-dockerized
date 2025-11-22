# IBSng Kubernetes Deployment

This directory contains Kubernetes manifests for deploying IBSng on a Kubernetes cluster.

## Prerequisites

- Kubernetes cluster (v1.19+)
- kubectl configured to access your cluster
- Storage class configured (for PersistentVolumes)
- Ingress controller (optional, for external access)

## Quick Start

### 1. Create Namespace and Resources

Deploy all resources at once:

```bash
# Apply all manifests
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml
kubectl apply -f postgres-pvc.yaml
kubectl apply -f postgres-deployment.yaml
kubectl apply -f postgres-service.yaml
kubectl apply -f ibsng-pvc.yaml
kubectl apply -f ibsng-deployment.yaml
kubectl apply -f ibsng-service.yaml

# Or use kustomize
kubectl apply -k .
```

### 2. Verify Deployment

```bash
# Check pods
kubectl get pods -n ibsng

# Check services
kubectl get svc -n ibsng

# Check PVCs
kubectl get pvc -n ibsng

# View logs
kubectl logs -f deployment/ibsng-app -n ibsng
kubectl logs -f deployment/ibsng-db -n ibsng
```

### 3. Access the Application

#### Using LoadBalancer Service

```bash
# Get external IP
kubectl get svc ibsng-app -n ibsng

# Access web interface
# http://<EXTERNAL-IP>/IBSng/admin
```

#### Using NodePort Service

Edit `ibsng-service.yaml` and change `type: LoadBalancer` to `type: NodePort`, then:

```bash
# Get node port
kubectl get svc ibsng-app -n ibsng

# Access via any node IP and the node port
# http://<NODE-IP>:<NODE-PORT>/IBSng/admin
```

#### Using Ingress

1. Edit `ingress.yaml` with your domain name
2. Apply: `kubectl apply -f ingress.yaml`
3. Access via your domain: `http://ibsng.example.com/IBSng/admin`

## Configuration

### Environment Variables

Edit `configmap.yaml` to change database configuration (non-sensitive):
- `IBSNG_DB_HOST`
- `IBSNG_DB_PORT`
- `IBSNG_DB_NAME`
- `IBSNG_DB_USER`

### Secrets

**IMPORTANT**: Change default passwords in production!

```bash
# Create secret manually (recommended for production)
kubectl create secret generic ibsng-secrets \
  --from-literal=postgres-password='your-secure-password' \
  --from-literal=ibsng-db-password='your-secure-password' \
  -n ibsng

# Or edit secret.yaml and apply
kubectl apply -f secret.yaml
```

### Resource Limits

Edit resource requests/limits in:
- `postgres-deployment.yaml` - Database resources
- `ibsng-deployment.yaml` - Application resources

### Storage

Adjust PVC sizes in:
- `postgres-pvc.yaml` - Database storage (default: 10Gi)
- `ibsng-pvc.yaml` - Application storage (logs: 5Gi, data: 5Gi, templates: 1Gi)

## Default Credentials

- **Web Interface**: http://<service-ip>/IBSng/admin
  - Username: `system`
  - Password: `system`

⚠️ **Change these immediately after first login!**

## Scaling

### Scale Application

```bash
kubectl scale deployment ibsng-app --replicas=3 -n ibsng
```

**Note**: IBSng may require shared storage or session affinity for multiple replicas. Consider using a StatefulSet if needed.

### Scale Database

```bash
# For production, consider using PostgreSQL operator for HA
kubectl scale deployment ibsng-db --replicas=1 -n ibsng
```

## Monitoring

### Health Checks

Both deployments include liveness and readiness probes:

- **Database**: Checks PostgreSQL readiness
- **Application**: Checks web interface availability

### View Status

```bash
# Pod status
kubectl get pods -n ibsng -o wide

# Describe pod for events
kubectl describe pod <pod-name> -n ibsng

# Check resource usage
kubectl top pods -n ibsng
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod events
kubectl describe pod <pod-name> -n ibsng

# Check logs
kubectl logs <pod-name> -n ibsng

# Check previous container logs (if crashed)
kubectl logs <pod-name> -n ibsng --previous
```

### Database Connection Issues

```bash
# Test database connectivity from app pod
kubectl exec -it deployment/ibsng-app -n ibsng -- \
  psql -h ibsng-db -U ibs -d IBSng

# Check database logs
kubectl logs deployment/ibsng-db -n ibsng
```

### Storage Issues

```bash
# Check PVC status
kubectl get pvc -n ibsng

# Check PV status
kubectl get pv

# Describe PVC for events
kubectl describe pvc <pvc-name> -n ibsng
```

### Service Access Issues

```bash
# Check service endpoints
kubectl get endpoints -n ibsng

# Test service from within cluster
kubectl run -it --rm debug --image=busybox --restart=Never -n ibsng -- \
  wget -qO- http://ibsng-app/IBSng/admin
```

## Backup and Restore

### Database Backup

```bash
# Create backup
kubectl exec deployment/ibsng-db -n ibsng -- \
  pg_dump -U ibs IBSng > backup.sql

# Or use the backup script from the container
kubectl exec deployment/ibsng-app -n ibsng -- \
  /usr/bin/backup_ibs /tmp/backup.sql
kubectl cp ibsng/<pod-name>:/tmp/backup.sql ./backup.sql
```

### Database Restore

```bash
# Copy backup to pod
kubectl cp ./backup.sql ibsng/<pod-name>:/tmp/backup.sql

# Restore
kubectl exec deployment/ibsng-db -n ibsng -- \
  psql -U ibs -d IBSng < backup.sql
```

## Production Considerations

1. **Security**:
   - Change all default passwords
   - Use Kubernetes secrets management (Sealed Secrets, External Secrets)
   - Enable RBAC
   - Use NetworkPolicies to restrict traffic

2. **High Availability**:
   - Use PostgreSQL operator for database HA
   - Consider StatefulSet for application if needed
   - Use multiple replicas with proper session affinity

3. **Monitoring**:
   - Set up Prometheus metrics
   - Configure alerting
   - Monitor resource usage

4. **Backup**:
   - Automated database backups
   - PVC snapshots
   - Disaster recovery plan

5. **SSL/TLS**:
   - Configure ingress with TLS
   - Use cert-manager for automatic certificate management

## Cleanup

```bash
# Delete all resources
kubectl delete -k .

# Or delete namespace (removes everything)
kubectl delete namespace ibsng
```

## Support

For issues:
- Check pod logs: `kubectl logs -f deployment/ibsng-app -n ibsng`
- Check events: `kubectl get events -n ibsng --sort-by='.lastTimestamp'`
- Review deployment documentation

---

**Image**: `mohseni676/ibsng-dockerized:latest`  
**Namespace**: `ibsng`  
**Last Updated**: 2025-11-22

