# Frontend Nginx Configuration Fix

## The Problem

When you created blog posts through the web UI, they were NOT getting auto-scored because:

**The frontend's nginx was proxying `/api` requests directly to the backend pod, bypassing the Gateway/HTTPRoute!**

### Architecture Flow (BEFORE - BROKEN):

```
Browser → Frontend Pod (nginx) → Backend Pod directly
                                  ↓
                            (Bypasses Gateway)
```

### What Should Happen (AFTER - FIXED):

```
Browser → Gateway (LoadBalancer) → HTTPRoute routes:
                                    - /api → Backend Pod ✅
                                    - / → Frontend Pod ✅
```

## The Root Cause

In `helm/microservices-app/templates/frontend-configmap.yaml`, lines 142-152:

```nginx
location /api/ {
    proxy_pass http://{{ backend-service }}:8000/;
    # ... proxy headers ...
}
```

This nginx config was **incorrectly proxying API requests** instead of letting the Gateway handle routing!

## The Fix

**Removed the `/api/` location block** from the frontend nginx config.

Now the frontend nginx ONLY serves static React files and lets the browser make requests to `/api`, which go through the Gateway as intended.

### Fixed Config:

```nginx
server {
    listen 8080;
    server_name _;
    
    root /usr/share/nginx/html;
    index index.html;
    
    # SPA routing - serve static files or fall back to index.html
    # The Gateway/HTTPRoute handles /api routing to backend
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
```

## Files Changed

1. **`helm/microservices-app/templates/frontend-configmap.yaml`** - Removed `/api/` proxy
2. **`app/frontend/nginx.conf`** - Removed `/api/` proxy (for consistency)

## How to Apply

### Option 1: Wait for ArgoCD (Automatic)
ArgoCD will sync the changes within 3 minutes.

### Option 2: Manual Sync (Immediate)
```bash
# If you have argocd CLI:
argocd app sync sha-blog-dev

# Or patch the ConfigMap directly:
kubectl patch configmap -n sha-dev sha-blog-dev-sha-microservices-app-frontend-config \
  --type merge \
  --patch-file patch-cm.json

# Then restart frontend:
kubectl rollout restart deployment -n sha-dev sha-blog-dev-sha-microservices-app-frontend
```

## Testing After Fix

1. Access the blog via the Gateway LoadBalancer:
   ```bash
   kubectl get gateway -n sha-dev -o jsonpath="{.items[0].status.addresses[0].value}"
   # Open: http://<GATEWAY-URL>
   ```

2. Create a new blog post through the UI

3. Check backend logs (should see scoring trigger):
   ```bash
   kubectl logs -n sha-dev -l app=backend --tail=20
   ```
   
   **You MUST see:**
   ```
   "Created new post XX, AI scoring queued"
   ```

4. Wait 90 seconds for Ollama to score

5. Check the score:
   ```bash
   kubectl exec -n sha-dev sha-blog-dev-sha-microservices-app-postgresql-0 -- \
     psql -U devuser -d sha_blog_dev -c \
     "SELECT id, title, ai_score FROM blog_posts ORDER BY id DESC LIMIT 5;"
   ```

## Summary

✅ Backend timeout fixed (90s for Ollama)
✅ AI agent health checks fixed (won't crash during scoring)
✅ Network policies fixed (backend can reach AI agent)
✅ **Frontend nginx fixed (no longer bypasses Gateway)** ← THIS WAS THE MAIN ISSUE!

**Auto-scoring will now work when you create posts through the web UI!**

