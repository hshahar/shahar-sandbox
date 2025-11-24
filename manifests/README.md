# Standalone Kubernetes Manifests

This directory contains standalone Kubernetes YAML files and configuration files that are not part of Helm charts.

## Files

- **elk-manifest.yaml** - Complete ELK Stack deployment manifest (Elasticsearch, Logstash, Kibana, Filebeat)
- **external-services.yaml** - External service definitions
- **httproute-fix.yaml** - HTTPRoute configuration fix
- **httproute-timeout.yaml** - HTTPRoute timeout configuration
- **temp-cm.yaml** - Temporary ConfigMap (testing)
- **temp-cm.json** - Temporary ConfigMap in JSON format
- **temp-route.yaml** - Temporary route configuration
- **score-request.json** - Sample AI scoring request payload

## Usage

These manifests can be applied directly with kubectl:

```bash
kubectl apply -f manifests/elk-manifest.yaml
kubectl apply -f manifests/external-services.yaml
```

## Note

Most production deployments should use the Helm charts in the `helm/` directory instead of these standalone manifests. These files are primarily for:
- Testing and development
- Quick deployments without Helm
- Configuration examples
- Temporary fixes
