#!/bin/bash
set -e

# IBSng Kubernetes Deployment Script
# This script deploys IBSng to a Kubernetes cluster

NAMESPACE="ibsng"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Deploying IBSng to Kubernetes..."
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ Error: kubectl is not installed or not in PATH"
    exit 1
fi

# Check cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: Cannot connect to Kubernetes cluster"
    exit 1
fi

echo "✅ Kubernetes cluster connection verified"
echo ""

# Create namespace
echo "📦 Creating namespace..."
kubectl apply -f "${SCRIPT_DIR}/namespace.yaml"

# Create ConfigMap
echo "⚙️  Creating ConfigMap..."
kubectl apply -f "${SCRIPT_DIR}/configmap.yaml"

# Create Secret
echo "🔐 Creating Secret..."
if kubectl get secret ibsng-secrets -n "${NAMESPACE}" &> /dev/null; then
    echo "   Secret already exists, skipping..."
else
    kubectl apply -f "${SCRIPT_DIR}/secret.yaml"
    echo "   ⚠️  WARNING: Using default passwords! Change them in production!"
fi

# Create PVCs
echo "💾 Creating PersistentVolumeClaims..."
kubectl apply -f "${SCRIPT_DIR}/postgres-pvc.yaml"
kubectl apply -f "${SCRIPT_DIR}/ibsng-pvc.yaml"

# Wait for PVCs to be bound
echo "   Waiting for PVCs to be bound..."
kubectl wait --for=condition=Bound pvc/postgres-pvc -n "${NAMESPACE}" --timeout=60s || true
kubectl wait --for=condition=Bound pvc/ibsng-logs-pvc -n "${NAMESPACE}" --timeout=60s || true
kubectl wait --for=condition=Bound pvc/ibsng-data-pvc -n "${NAMESPACE}" --timeout=60s || true
kubectl wait --for=condition=Bound pvc/ibsng-templates-pvc -n "${NAMESPACE}" --timeout=60s || true

# Deploy PostgreSQL
echo "🗄️  Deploying PostgreSQL database..."
kubectl apply -f "${SCRIPT_DIR}/postgres-deployment.yaml"
kubectl apply -f "${SCRIPT_DIR}/postgres-service.yaml"

# Wait for database to be ready
echo "   Waiting for database to be ready..."
kubectl wait --for=condition=available deployment/ibsng-db -n "${NAMESPACE}" --timeout=300s || true

# Deploy IBSng application
echo "🌐 Deploying IBSng application..."
kubectl apply -f "${SCRIPT_DIR}/ibsng-deployment.yaml"
kubectl apply -f "${SCRIPT_DIR}/ibsng-service.yaml"

# Wait for application to be ready
echo "   Waiting for application to be ready..."
kubectl wait --for=condition=available deployment/ibsng-app -n "${NAMESPACE}" --timeout=300s || true

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📊 Status:"
kubectl get pods -n "${NAMESPACE}"
echo ""
echo "🌐 Services:"
kubectl get svc -n "${NAMESPACE}"
echo ""

# Get access information
SERVICE_TYPE=$(kubectl get svc ibsng-app -n "${NAMESPACE}" -o jsonpath='{.spec.type}')

if [ "${SERVICE_TYPE}" == "LoadBalancer" ]; then
    EXTERNAL_IP=$(kubectl get svc ibsng-app -n "${NAMESPACE}" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    if [ -n "${EXTERNAL_IP}" ]; then
        echo "🌍 Access the web interface at:"
        echo "   http://${EXTERNAL_IP}/IBSng/admin"
    else
        echo "⏳ LoadBalancer IP is being assigned. Check with:"
        echo "   kubectl get svc ibsng-app -n ${NAMESPACE}"
    fi
elif [ "${SERVICE_TYPE}" == "NodePort" ]; then
    NODE_PORT=$(kubectl get svc ibsng-app -n "${NAMESPACE}" -o jsonpath='{.spec.ports[0].nodePort}')
    echo "🌍 Access the web interface at:"
    echo "   http://<NODE-IP>:${NODE_PORT}/IBSng/admin"
    echo "   Get node IPs with: kubectl get nodes -o wide"
else
    echo "🌍 Access the web interface via port-forward:"
    echo "   kubectl port-forward svc/ibsng-app 8080:80 -n ${NAMESPACE}"
    echo "   Then visit: http://localhost:8080/IBSng/admin"
fi

echo ""
echo "🔑 Default credentials:"
echo "   Username: system"
echo "   Password: system"
echo ""
echo "⚠️  Remember to change default passwords!"
echo ""
echo "📝 View logs:"
echo "   kubectl logs -f deployment/ibsng-app -n ${NAMESPACE}"
echo "   kubectl logs -f deployment/ibsng-db -n ${NAMESPACE}"

