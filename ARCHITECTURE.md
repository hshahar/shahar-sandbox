# Architecture Overview

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         External Users                               │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             │ HTTP/HTTPS
                             │
┌────────────────────────────▼────────────────────────────────────────┐
│                    Ingress Controller (NGINX)                        │
│  Routes:                                                             │
│    / → Frontend                                                      │
│    /api → Backend                                                    │
└────────────┬──────────────────────────┬────────────────────────────┘
             │                          │
             │                          │
┌────────────▼───────────┐  ┌──────────▼────────────┐
│   Frontend Service     │  │   Backend Service      │
│   (ClusterIP)          │  │   (ClusterIP)          │
└────────────┬───────────┘  └──────────┬────────────┘
             │                          │
             │                          │
┌────────────▼───────────┐  ┌──────────▼────────────┐
│  Frontend Deployment   │  │  Backend Deployment    │
│  - Nginx Pods          │  │  - API Pods            │
│  - Replicas: 1-3       │  │  - Replicas: 1-10      │
│  - Rolling Updates     │  │  - Rolling Updates     │
│  - Health Checks       │  │  - Health Checks       │
│                        │  │  - Auto Scaling (HPA)  │
└────────────────────────┘  └──────────┬────────────┘
                                       │
                                       │
                            ┌──────────▼────────────┐
                            │   PostgreSQL Service  │
                            │   (Headless)          │
                            └──────────┬────────────┘
                                       │
                            ┌──────────▼────────────┐
                            │  PostgreSQL           │
                            │  StatefulSet          │
                            │  - 1 Replica          │
                            │  - Health Checks      │
                            └──────────┬────────────┘
                                       │
                            ┌──────────▼────────────┐
                            │  Persistent Volume    │
                            │  (PVC + PV)           │
                            │  Size: 1-20Gi         │
                            └───────────────────────┘
```

## Multi-Environment Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                       Kubernetes Cluster                              │
│                     (Rancher Desktop / Docker Desktop)                │
│                                                                       │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌──────────────┐│
│  │   Namespace: dev    │  │ Namespace: staging  │  │Namespace:prod││
│  │                     │  │                     │  │              ││
│  │  Frontend (1 pod)   │  │  Frontend (2 pods)  │  │Frontend(3)   ││
│  │  Backend (1 pod)    │  │  Backend (2-5 pods) │  │Backend(3-10) ││
│  │  PostgreSQL (1 pod) │  │  PostgreSQL (1 pod) │  │PostgreSQL(1) ││
│  │  Storage: 1Gi       │  │  Storage: 5Gi       │  │Storage: 20Gi ││
│  │                     │  │                     │  │              ││
│  └─────────────────────┘  └─────────────────────┘  └──────────────┘│
│                                                                       │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │              Ingress NGINX Controller                          │ │
│  │  (Shared across all namespaces)                               │ │
│  └────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

## Component Interactions

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│   Browser   │────────>│  Ingress    │────────>│  Frontend   │
└─────────────┘         └─────────────┘         │   Service   │
                                                 └──────┬──────┘
                                                        │
                        ┌───────────────────────────────┘
                        │
                        │ Proxy /api requests
                        │
                        ▼
                 ┌──────────────┐
                 │   Backend    │
                 │   Service    │
                 └──────┬───────┘
                        │
                        │ Database queries
                        │
                        ▼
                 ┌──────────────┐
                 │  PostgreSQL  │
                 │   Service    │
                 └──────┬───────┘
                        │
                        ▼
                 ┌──────────────┐
                 │ Persistent   │
                 │   Volume     │
                 └──────────────┘
```

## Data Flow

### Request Flow:
```
1. User → http://dev.myapp.local
2. DNS → 127.0.0.1 (localhost)
3. Ingress Controller → Route based on path
4. Frontend Service → Load balance to Frontend Pods
5. Frontend Pod → Serve static content
6. Frontend → Proxy /api requests to Backend
7. Backend Service → Load balance to Backend Pods
8. Backend Pod → Query PostgreSQL
9. PostgreSQL → Read/Write to Persistent Volume
10. Response flows back through the chain
```

## Deployment Strategy

```
┌──────────────────────────────────────────────────────────────┐
│                    Rolling Update Strategy                    │
│                                                               │
│  Current State:                                               │
│  [Pod v1.0] [Pod v1.0] [Pod v1.0]                           │
│                                                               │
│  Step 1 - Create new pod:                                    │
│  [Pod v1.0] [Pod v1.0] [Pod v1.0] [Pod v2.0 Starting...]    │
│                                                               │
│  Step 2 - Wait for readiness:                                │
│  [Pod v1.0] [Pod v1.0] [Pod v1.0] [Pod v2.0 ✓]             │
│                                                               │
│  Step 3 - Terminate old pod:                                 │
│  [Pod v1.0] [Pod v1.0] [Pod v2.0] [Pod v2.0 Starting...]    │
│                                                               │
│  Step 4 - Continue until complete:                           │
│  [Pod v2.0] [Pod v2.0] [Pod v2.0]                           │
│                                                               │
│  Benefits:                                                    │
│  ✅ Zero downtime                                            │
│  ✅ Gradual rollout                                          │
│  ✅ Easy rollback                                            │
└──────────────────────────────────────────────────────────────┘
```

## Auto Scaling

```
┌──────────────────────────────────────────────────────────────┐
│              Horizontal Pod Autoscaler (HPA)                  │
│                                                               │
│  Normal Load (CPU: 30%):                                     │
│  [Backend Pod] [Backend Pod]                                 │
│  minReplicas: 2                                              │
│                                                               │
│  Medium Load (CPU: 75%):                                     │
│  [Backend Pod] [Backend Pod] [Backend Pod] [Backend Pod]     │
│  Scaled to: 4                                                │
│                                                               │
│  High Load (CPU: 90%):                                       │
│  [Pod][Pod][Pod][Pod][Pod][Pod][Pod][Pod]                   │
│  Scaled to: 8 (moving toward maxReplicas: 10)               │
│                                                               │
│  Load Decreases (CPU: 40%):                                  │
│  [Backend Pod] [Backend Pod] [Backend Pod]                   │
│  Scaled down to: 3 (gradual scale-down)                     │
└──────────────────────────────────────────────────────────────┘
```

## Persistent Storage

```
┌────────────────────────────────────────────────────────────┐
│                  PostgreSQL StatefulSet                     │
│                                                             │
│  ┌──────────────────────────────────────────────────┐     │
│  │  postgresql-0 (Pod)                               │     │
│  │  ┌────────────────────────────────────────────┐  │     │
│  │  │  Container: postgres:15-alpine              │  │     │
│  │  │  Volume Mount: /var/lib/postgresql/data    │  │     │
│  │  └─────────────────┬──────────────────────────┘  │     │
│  └────────────────────┼─────────────────────────────┘     │
│                       │                                     │
│                       │ Bound to                            │
│                       ▼                                     │
│  ┌────────────────────────────────────────────────┐       │
│  │  PersistentVolumeClaim (PVC)                   │       │
│  │  Name: postgresql-data-postgresql-0            │       │
│  │  Size: 1Gi (dev) / 5Gi (staging) / 20Gi (prod)│       │
│  │  Access: ReadWriteOnce                         │       │
│  └────────────────────┬───────────────────────────┘       │
│                       │                                     │
│                       │ Provisioned from                    │
│                       ▼                                     │
│  ┌────────────────────────────────────────────────┐       │
│  │  PersistentVolume (PV)                         │       │
│  │  Created by: Dynamic Provisioner               │       │
│  │  Backend: Local storage / Cloud storage        │       │
│  └────────────────────────────────────────────────┘       │
└────────────────────────────────────────────────────────────┘
```

## Secrets Management

```
┌─────────────────────────────────────────────────────────────┐
│                     Secrets Flow                             │
│                                                              │
│  ┌────────────────────┐                                     │
│  │  Kubernetes Secret │                                     │
│  │  (Base64 encoded)  │                                     │
│  │                    │                                     │
│  │  - db-username     │                                     │
│  │  - db-password     │                                     │
│  │  - api-key         │                                     │
│  └─────────┬──────────┘                                     │
│            │                                                 │
│            │ Mounted as env vars                            │
│            │                                                 │
│    ┌───────▼────────┐         ┌──────────────┐            │
│    │  Backend Pod   │         │ PostgreSQL   │            │
│    │                │         │   Pod        │            │
│    │  Env:          │────────>│  Env:        │            │
│    │  - DB_USER     │ Connect │  - POSTGRES_ │            │
│    │  - DB_PASS     │         │    USER      │            │
│    │  - DB_HOST     │         │  - POSTGRES_ │            │
│    │  - API_KEY     │         │    PASSWORD  │            │
│    └────────────────┘         └──────────────┘            │
└─────────────────────────────────────────────────────────────┘
```

## CI/CD Pipeline

```
┌────────────────────────────────────────────────────────────────┐
│                     GitHub Actions Workflow                     │
│                                                                 │
│  Push to 'develop' branch                                      │
│         │                                                       │
│         ▼                                                       │
│  ┌─────────────────┐                                          │
│  │  Validate       │                                          │
│  │  - Helm lint    │                                          │
│  │  - Terraform    │                                          │
│  └────────┬────────┘                                          │
│           │                                                     │
│           ▼                                                     │
│  ┌─────────────────┐                                          │
│  │  Deploy to Dev  │                                          │
│  │  - kubectl      │                                          │
│  │  - helm upgrade │                                          │
│  └────────┬────────┘                                          │
│           │                                                     │
│           ▼                                                     │
│  ┌─────────────────┐                                          │
│  │  Verify         │                                          │
│  │  - Check pods   │                                          │
│  │  - Smoke tests  │                                          │
│  └─────────────────┘                                          │
│                                                                 │
│  Similar flow for:                                             │
│  - staging branch → Staging environment                        │
│  - main branch → Production environment                        │
└────────────────────────────────────────────────────────────────┘
```

## Technology Stack

```
┌──────────────────────────────────────────────────────────┐
│                    Technology Layers                      │
│                                                           │
│  Infrastructure as Code:                                 │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Terraform - Infrastructure provisioning           │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
│  Orchestration:                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Kubernetes - Container orchestration              │ │
│  │  Rancher Desktop - Local K8s cluster               │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
│  Package Management:                                     │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Helm - Application packaging and deployment       │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
│  Application Layer:                                      │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Frontend: Nginx 1.25-alpine                       │ │
│  │  Backend: hashicorp/http-echo (demo)               │ │
│  │  Database: PostgreSQL 15-alpine                    │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
│  Networking:                                             │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Ingress: NGINX Ingress Controller                 │ │
│  │  Services: ClusterIP, Headless                     │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
│  CI/CD:                                                  │
│  ┌────────────────────────────────────────────────────┐ │
│  │  GitHub Actions - Automated deployment             │ │
│  └────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

## Security Architecture

```
┌──────────────────────────────────────────────────────────┐
│                  Security Layers                          │
│                                                           │
│  1. Network Level:                                       │
│     • Ingress Controller (rate limiting, SSL)           │
│     • Service isolation (ClusterIP)                     │
│                                                           │
│  2. Application Level:                                   │
│     • Resource limits and requests                      │
│     • Health checks (liveness/readiness probes)         │
│     • Rolling updates (zero downtime)                   │
│                                                           │
│  3. Data Level:                                          │
│     • Kubernetes Secrets (base64 encoded)               │
│     • Persistent volumes (isolated per namespace)       │
│     • Database credentials separated per environment    │
│                                                           │
│  4. Access Control:                                      │
│     • Namespace isolation                                │
│     • RBAC (Role-Based Access Control) ready            │
│     • Service accounts                                   │
└──────────────────────────────────────────────────────────┘
```

## Best Practices Implemented

✅ Infrastructure as Code (Terraform)
✅ GitOps principles (CI/CD pipeline)
✅ Immutable infrastructure
✅ Container orchestration (Kubernetes)
✅ Declarative configuration (Helm)
✅ Environment parity (dev/staging/prod)
✅ Zero-downtime deployments
✅ Auto-scaling capabilities
✅ Health checks and self-healing
✅ Persistent storage for stateful apps
✅ Secrets management
✅ Resource management (limits/requests)
✅ Multi-environment support
✅ Easy rollback mechanism
