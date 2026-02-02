# SABnzbd CI Configuration

This directory contains configuration and scripts for the CI/CD pipeline.

## Files

### docker-matrix.json

Defines the build matrix for multi-architecture Docker images. See the [schema documentation](https://github.com/runlix/build-workflow/blob/main/schema/docker-matrix-schema.json) for details.

**Variants:**
- `latest-amd64` - Stable build for AMD64
- `latest-arm64` - Stable build for ARM64
- `debug-amd64` - Debug build for AMD64 (includes debugging tools)
- `debug-arm64` - Debug build for ARM64 (includes debugging tools)

### smoke-test.sh

Automated smoke test script that validates built Docker images before they are released.

**What it tests:**
- ✅ Container starts successfully
- ✅ No critical errors in logs
- ✅ Web endpoint responds (`/`)
- ✅ API endpoint responds (`/api?mode=version`)
- ✅ Correct architecture is used
- ✅ SABnzbd process is running

**Environment Variables:**
- `IMAGE_TAG` (required) - The Docker image tag to test (set by workflow)
- `PLATFORM` (optional) - Platform to test, defaults to `linux/amd64`

**Usage:**

The smoke test is automatically executed by the GitHub Actions workflow after each image is built or promoted. You can also run it locally:

```bash
# Export the image tag you want to test
export IMAGE_TAG="ghcr.io/runlix/sabnzbd:pr-123-4.5.5-stable-amd64-abc1234"

# Run the smoke test
.ci/smoke-test.sh
```

**Exit Codes:**
- `0` - All tests passed
- `1` - One or more tests failed

**Customization:**

You can customize the smoke test by editing `.ci/smoke-test.sh`. Some common customizations:

- **Change initialization wait time** (currently 15 seconds):
  ```bash
  sleep 15  # Change to longer if SABnzbd takes time to start
  ```

- **Add additional endpoint tests**:
  ```bash
  # Test API queue endpoint
  if curl -fsSL "http://localhost:${SABNZBD_PORT}/api?mode=queue" \
     -o /dev/null; then
    echo "✅ API queue endpoint responding"
  fi
  ```

- **Change timeout values**:
  ```bash
  MAX_ATTEMPTS=24  # Number of web endpoint check attempts
  sleep 5          # Delay between attempts
  ```

## Testing Changes

Before committing changes to this configuration:

1. **Validate JSON syntax**:
   ```bash
   jq . docker-matrix.json
   ```

2. **Validate against schema**:
   ```bash
   curl -sL https://raw.githubusercontent.com/runlix/build-workflow/main/schema/docker-matrix-schema.json \
     > /tmp/schema.json
   ajv validate -s /tmp/schema.json -d docker-matrix.json
   ```

3. **Test smoke test locally** (requires Docker):
   ```bash
   # Build or pull an image
   docker pull ghcr.io/runlix/sabnzbd:latest

   # Run the smoke test
   export IMAGE_TAG="ghcr.io/runlix/sabnzbd:latest"
   .ci/smoke-test.sh
   ```

## Workflow Integration

The build workflow automatically:

1. **On Pull Requests**: Builds all variants and runs smoke tests
2. **On Merges to Release Branch**: Promotes PR images (or rebuilds if not found) and runs smoke tests
3. **After Tests Pass**: Creates multi-arch manifests and pushes to registry

See [build-workflow documentation](https://github.com/runlix/build-workflow/tree/main/docs) for more details.
