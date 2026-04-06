# SABnzbd

Kubernetes-native distroless Docker image for [SABnzbd](https://github.com/sabnzbd/sabnzbd), built and published through the shared CI v3 workflow stack in [`runlix/build-workflow`](https://github.com/runlix/build-workflow).

## Published Image

- Image: `ghcr.io/runlix/sabnzbd`
- Current stable tag example: `ghcr.io/runlix/sabnzbd:4.5.5-stable`
- Current debug tag example: `ghcr.io/runlix/sabnzbd:4.5.5-debug`

The authoritative published tags, digests, and source revision are recorded in [release.json](release.json).

## Branch Layout

- `main`: documentation, release metadata, and automation configuration
- `release`: Dockerfiles, CI wrappers, smoke tests, and build inputs

Normal release flow:
1. changes land on `release`
2. `Publish Release` builds and publishes the images
3. the workflow opens a sync PR back to `main`
4. `main` records the published result in `release.json`

## Usage

### Docker

```bash
docker run -d \
  --name sabnzbd \
  -p 8080:8080 \
  -v /path/to/config:/config \
  ghcr.io/runlix/sabnzbd:4.5.5-stable
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
          image: ghcr.io/runlix/sabnzbd:4.5.5-stable
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

## Environment Variables

- `SABNZBD__SERVER__PORT`: server port override, defaults to `8080`

## License

GPL-3.0
