# Devenv + DevSpace Integration Guide

> **Purpose:** Explains how devenv and DevSpace work together to provide a complete development workflow: devenv manages the local/cluster dev environment, DevSpace manages the Kubernetes orchestration.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         LOCAL MACHINE                                │
│                                                                       │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────────┐  │
│  │   Editor    │    │  devspace   │    │      kubectl            │  │
│  │ (VS Code,   │    │    CLI      │    │    (cluster access)     │  │
│  │  Cursor,    │    │             │    │                         │  │
│  │  Neovim)    │    │             │    │                         │  │
│  └─────────────┘    └──────┬──────┘    └─────────────────────────┘  │
│                             │                                         │
└─────────────────────────────┼─────────────────────────────────────────┘
                              │
                              │ devspace dev / devspace build
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      KUBERNETES CLUSTER                               │
│                                                                       │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    DEV POD (Interactive)                       │  │
│  │                                                               │  │
│  │  ┌─────────────────────────────────────────────────────────┐ │  │
│  │  │              devenv environment                         │ │  │
│  │  │  (languages, services, tools from devenv.nix)           │ │  │
│  │  └─────────────────────────────────────────────────────────┘ │  │
│  │                                                               │  │
│  │  Mounts: /workspace (shared storage)                         │  │
│  │                                                               │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                       │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │              SHARED STORAGE (JuiceFS / NFS)                   │  │
│  │                                                               │  │
│  │  /workspace/                                                  │  │
│  │    ├── project-a/    (devenv.nix, src/, etc.)                │  │
│  │    ├── project-b/    (devenv.nix, src/, etc.)                │  │
│  │    └── models/       (LLM weights, shared cache)             │  │
│  │                                                               │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                       │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │              EPHEMERAL BUILD PODS (Jobs)                      │  │
│  │                                                               │  │
│  │  - Heavy compilation (nix build, cargo build --release)      │  │
│  │  - Container image builds (BuildKit)                         │  │
│  │  - Cross-compilation jobs                                    │  │
│  │                                                               │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

---

## How They Work Together

### Devenv: Environment Definition

devenv defines **what** your development environment contains:

```nix
# devenv.nix - "I need Python, Postgres, and these tools"
{
  languages.python = {
    enable = true;
    venv.enable = true;
  };

  services.postgres = {
    enable = true;
    initialDatabases = [{ name = "myapp"; }];
  };

  packages = [ pkgs.redis ];
}
```

### DevSpace: Cluster Orchestration

DevSpace defines **where** and **how** that environment runs:

```yaml
# devspace.yaml - "Run it on the GPU node with shared storage"
dev:
  app:
    labelSelector:
      app: myapp
    terminal:
      command: ["/bin/bash"]

profiles:
  - name: gpu
    patches:
      - op: add
        path: deployments.dev.helm.values.containers[0].resources
        value:
          limits:
            nvidia.com/gpu: 1
```

### The Integration Point

The Dev Pod's container image is built from a Dockerfile that includes the devenv environment:

```dockerfile
# Dockerfile - Packages devenv environment into container
FROM nixos/nix:latest

# Install devenv
RUN nix profile install github:cachix/devenv/latest

# Copy project files
COPY . /app
WORKDIR /app

# Pre-build devenv environment (optional, for faster startup)
RUN devenv shell -- echo "Environment ready"

# Keep container running for interactive use
CMD ["sleep", "infinity"]
```

---

## Workflow Patterns

### Pattern 1: Interactive Development (devspace dev)

**Use case:** Writing code, debugging, running tests interactively

```bash
# 1. Start dev pod (uses default profile)
devspace dev

# 2. You're now in the pod's shell, inside the devenv environment
#    Code is on shared storage, changes persist

# 3. Run devenv commands inside the pod
devenv shell        # Enter devenv shell
devenv test         # Run tests
devenv up           # Start services (postgres, redis, etc.)

# 4. Switch to GPU node when needed
devspace dev -p gpu
```

**What happens:**

1. DevSpace creates a pod with your container image
2. Pod mounts shared storage at `/workspace`
3. You exec into the pod's shell
4. devenv environment is available (languages, tools, services)

---

### Pattern 2: In-Cluster Builds (devspace build)

**Use case:** Building container images without local Docker

```bash
# Build image using BuildKit in cluster
devspace build

# Image is pushed to your registry
# No local Docker daemon needed
```

**What happens:**

1. DevSpace sends build context to in-cluster BuildKit
2. BuildKit pod builds the image (using your Dockerfile)
3. Image is pushed to your registry
4. Your local machine never runs Docker

---

### Pattern 3: Heavy Compilation Jobs

**Use case:** Long-running builds (nix build, cargo build --release, cross-compilation)

```bash
# Trigger ephemeral build job
devspace run heavy-build

# Or manually create a job
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: nix-build
spec:
  template:
    spec:
      restartPolicy: Never
      nodeSelector:
        kubernetes.io/hostname: "strix-halo"  # Target specific node
      containers:
        - name: builder
          image: nixos/nix:latest
          command: ["nix", "build"]
          workingDir: /workspace/project
          volumeMounts:
            - name: storage
              mountPath: /workspace
          resources:
            requests:
              cpu: "16"
              memory: "32Gi"
      volumes:
        - name: storage
          persistentVolumeClaim:
            claimName: juicefs-workspace-pvc
EOF
```

**What happens:**

1. Job pod is created on target node
2. Mounts shared storage (same as dev pod)
3. Runs build, outputs to shared storage
4. Pod terminates automatically
5. Results available to dev pod immediately

---

### Pattern 4: Service-Heavy Development

**Use case:** Full-stack app with multiple services

```nix
# devenv.nix
{
  languages.javascript.enable = true;

  services = {
    postgres.enable = true;
    redis.enable = true;
    minio.enable = true;
  };

  processes = {
    api.exec = "npm run dev:api";
    worker.exec = "npm run dev:worker";
  };
}
```

```bash
# Start dev pod
devspace dev

# Inside pod, start all services
devenv up

# devenv's process manager starts:
# - postgres (with readiness probe)
# - redis
# - minio
# - api server
# - worker
```

---

## Configuration Guide

### devspace.yaml Structure

```yaml
version: v2beta1
name: my-project

vars:
  # Variables for customization
  IMAGE: registry.local/myapp
  PVC: shared-workspace

images:
  # Container image definitions
  app:
    image: "${IMAGE}"
    buildKit:
      inCluster: {}

deployments:
  # Kubernetes deployments
  dev:
    helm:
      values:
        containers:
          - image: "${IMAGE}:dev"
            volumeMounts:
              - containerPath: /workspace
                name: storage
        volumes:
          - name: storage
            persistentVolumeClaim:
              claimName: "${PVC}"

dev:
  # Interactive dev configuration
  dev:
    labelSelector:
      app: dev
    terminal:
      command: ["/bin/bash"]
    ports:
      - port: "8080:8080"

profiles:
  # Hardware/environment profiles
  - name: gpu
    patches:
      - op: add
        path: deployments.dev.helm.values.containers[0].resources
        value:
          limits:
            nvidia.com/gpu: 1

commands:
  # Custom commands
  test:
    command: devspace enter -- devenv test
```

### Profile Examples

#### NVIDIA GPU

```yaml
profiles:
  - name: gpu
    patches:
      - op: add
        path: deployments.dev.helm.values.containers[0].resources
        value:
          limits:
            nvidia.com/gpu: 1
      - op: add
        path: deployments.dev.helm.values.containers[0].env
        value:
          - name: NVIDIA_VISIBLE_DEVICES
            value: "all"
```

#### AMD GPU (ROCm)

```yaml
profiles:
  - name: amd
    patches:
      - op: add
        path: deployments.dev.helm.values.containers[0].volumeMounts
        value:
          - containerPath: /workspace
            name: storage
          - containerPath: /dev/kfd
            name: kfd
          - containerPath: /dev/dri
            name: dri
      - op: add
        path: deployments.dev.helm.values.volumes
        value:
          - name: storage
            persistentVolumeClaim:
              claimName: "${PVC}"
          - name: kfd
            hostPath:
              path: /dev/kfd
          - name: dri
            hostPath:
              path: /dev/dri
```

#### High-Memory (for LLMs)

```yaml
profiles:
  - name: llm
    patches:
      - op: replace
        path: deployments.dev.helm.values.containers[0].resources
        value:
          requests:
            memory: "64Gi"
          limits:
            memory: "128Gi"
            nvidia.com/gpu: 1
```

#### Specific Node

```yaml
profiles:
  - name: strix
    patches:
      - op: add
        path: deployments.dev.helm.values.nodeSelector
        value:
          kubernetes.io/hostname: "strix-halo"
```

---

## Dockerfile Patterns

### Pattern 1: Devenv-Based (Recommended)

```dockerfile
FROM nixos/nix:latest

# Enable flakes
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

# Install devenv
RUN nix profile install github:cachix/devenv/latest

# Copy project
COPY . /app
WORKDIR /app

# Pre-evaluate devenv (caches environment)
RUN devenv shell -- echo "ready"

CMD ["sleep", "infinity"]
```

### Pattern 2: Pre-Built Artifacts

```dockerfile
# Stage 1: Build with Nix
FROM nixos/nix:latest AS builder

RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf
COPY . /build
WORKDIR /build
RUN nix build

# Stage 2: Runtime
FROM ubuntu:22.04

# Copy built artifacts
COPY --from=builder /build/result/bin/* /usr/local/bin/

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

CMD ["/usr/local/bin/myapp"]
```

### Pattern 3: Language-Specific (Python Example)

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install devenv for dev mode
RUN pip install devenv

# Copy project
COPY . .

# Install dependencies
RUN pip install -r requirements.txt

# For dev: sleep infinity
# For prod: CMD ["python", "main.py"]
CMD ["sleep", "infinity"]
```

---

## Shared Storage Setup

### JuiceFS (Recommended)

```yaml
# pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: juicefs-workspace-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: juicefs-sc
  resources:
    requests:
      storage: 100Gi
```

### NFS

```yaml
# pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-workspace-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-client
  resources:
    requests:
      storage: 100Gi
```

---

## Common Commands

```bash
# Interactive development
devspace dev                    # Start dev pod
devspace dev -p gpu             # Start on GPU node
devspace dev -p strix           # Target specific node

# Inside dev pod
devenv shell                    # Enter devenv environment
devenv up                       # Start services
devenv test                     # Run tests

# Building
devspace build                  # Build container image
devspace run build-nix          # Run nix build in cluster
devspace run heavy-build        # Trigger heavy build job

# Management
devspace logs                   # View pod logs
devspace purge                  # Delete dev pod
devspace reset                  # Reset everything
```

---

## Troubleshooting

### Dev pod won't start

```bash
# Check pod status
kubectl get pods -l app=dev

# Check events
kubectl describe pod -l app=dev

# Check PVC exists
kubectl get pvc
```

### Services not starting in devenv

```bash
# Inside dev pod, check process manager
devenv up --log-level debug

# Check service logs
devenv logs postgres
```

### Build fails in cluster

```bash
# Check BuildKit pod
kubectl get pods -n buildkit

# Check build logs
devspace build --verbose
```

### Shared storage not mounting

```bash
# Check CSI driver
kubectl get csidrivers

# Check PV/PVC binding
kubectl get pv,pvc

# Check mount in pod
devspace enter -- df -h /workspace
```

---

## Summary

| Tool               | Responsibility                                       |
| ------------------ | ---------------------------------------------------- |
| **devenv**         | Define dev environment (languages, services, tools)  |
| **DevSpace**       | Orchestrate Kubernetes pods, builds, deployments     |
| **Shared Storage** | Persist code across pod restarts, share between pods |
| **Dockerfile**     | Package devenv environment into container image      |

**Workflow:**

1. Define environment in `devenv.nix`
2. Package into container with `Dockerfile`
3. Orchestrate with `devspace.yaml`
4. Develop with `devspace dev` + `devenv shell`
