# Kibana Dashboards Configuration

This directory contains Kibana dashboard configurations and saved objects for the SHA Blog Platform.

## Index Patterns

The ELK stack is configured to create separate indices per namespace:

- `k8s-logs-*` - All Kubernetes logs (fallback)
- `k8s-sha-dev-*` - Development environment logs
- `k8s-sha-staging-*` - Staging environment logs
- `k8s-sha-production-*` - Production environment logs

## Importing Dashboards

### Option 1: Using Kibana UI

1. Access Kibana at `http://sha-kibana.blog.local`
2. Go to **Management → Stack Management → Saved Objects**
3. Click **Import**
4. Select `kibana-index-patterns.json`
5. Click **Import**

### Option 2: Using Kibana API

```bash
# Import index patterns
curl -X POST "http://sha-kibana.blog.local/api/saved_objects/_import?overwrite=true" \
  -H "kbn-xsrf: true" \
  --form file=@kibana-index-patterns.json
```

## Useful Searches

### Backend Errors
```
k8s_container: "backend" AND level: "ERROR"
```

### HTTP 5xx Errors
```
status_code >= 500 AND status_code < 600
```

### Slow Requests (>1 second)
```
duration > 1000
```

### Requests by Endpoint
```
http_method: * AND path: "/api/posts"
```

### Pod Shutdown Events
```
message: "graceful shutdown" OR message: "SIGTERM"
```

## Creating Visualizations

### 1. Request Rate Over Time
- Visualization Type: Line chart
- Y-axis: Count
- X-axis: @timestamp (Date Histogram, interval: auto)
- Split Series: status_code (Top 5)

### 2. Response Time Distribution
- Visualization Type: Histogram
- Y-axis: Count
- X-axis: duration (Histogram, interval: 100)

### 3. Error Rate by Endpoint
- Visualization Type: Data Table
- Metrics: Count
- Bucket: path.keyword (Top 10)
- Filter: status_code >= 400

### 4. Pod Distribution
- Visualization Type: Pie chart
- Metrics: Count
- Bucket: k8s_pod.keyword (Top 10)

### 5. Log Level Distribution
- Visualization Type: Pie chart
- Metrics: Count
- Bucket: level.keyword

## Sample Queries

### Find all backend startup events
```json
{
  "query": {
    "bool": {
      "must": [
        { "match": { "k8s_container": "backend" }},
        { "match": { "message": "Application started successfully" }}
      ]
    }
  }
}
```

### Find requests from specific client
```json
{
  "query": {
    "match": {
      "client_ip": "10.244.0.1"
    }
  }
}
```

### Find all database connection errors
```json
{
  "query": {
    "bool": {
      "must": [
        { "match": { "level": "ERROR" }},
        { "match": { "message": "database" }}
      ]
    }
  }
}
```

## Dashboard Best Practices

1. **Set Time Range**: Always use appropriate time ranges (Last 15 minutes, Last hour, etc.)
2. **Use Filters**: Apply namespace and pod filters to narrow down logs
3. **Create Alerts**: Set up Kibana alerts for critical errors
4. **Export Dashboards**: Regularly export and version control your dashboards
5. **Document Queries**: Document complex queries for team reference

## Troubleshooting

### No data in Kibana

1. Check if Elasticsearch is receiving data:
```bash
curl http://elasticsearch.logging:9200/_cat/indices?v
```

2. Check if Filebeat is running:
```bash
kubectl get pods -n logging -l app=filebeat
```

3. Check Logstash logs:
```bash
kubectl logs -n logging -l app=logstash
```

### Missing fields

If you don't see expected fields (like `k8s_pod`, `status_code`), refresh the index pattern:
1. Go to **Management → Index Patterns**
2. Select your index pattern
3. Click the **Refresh** button (🔄)

### Logs not being parsed correctly

Check Logstash configuration in the ConfigMap:
```bash
kubectl get configmap -n logging logstash-config -o yaml
```
