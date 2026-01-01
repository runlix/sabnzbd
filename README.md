# SABnzbd

Kubernetes-native distroless Docker image for [SABnzbd](https://github.com/sabnzbd/sabnzbd) - a Usenet downloader.

## Purpose

Provides a minimal, secure Docker image for running SABnzbd in Kubernetes environments. Built on the `distroless-runtime` base image with only the essential dependencies required for SABnzbd to function.

## Features

- Distroless base (no shell, minimal attack surface)
- Kubernetes-native permissions (no s6-overlay)
- Read-only root filesystem
- Non-root execution
- Minimal image size (~100MB vs ~500MB)

## Usage

### Docker

```bash
docker run -d \
  --name sabnzbd \
  -p 8080:8080 \
  -v /path/to/config:/config \
  ghcr.io/runlix/sabnzbd:release-latest
```

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sabnzbd
spec:
  template:
    spec:
      containers:
      - name: sabnzbd
        image: ghcr.io/runlix/sabnzbd:release-latest
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: config
          mountPath: /config
        securityContext:
          runAsUser: 1000
          runAsGroup: 1000
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
      volumes:
      - name: config
        persistentVolumeClaim:
          claimName: sabnzbd-config
      securityContext:
        fsGroup: 1000
```

## Tags

See [tags.json](tags.json) for available tags.

## Environment Variables

- `SABNZBD__SERVER__PORT`: Server port (default: 8080)

## License

GPL-3.0
