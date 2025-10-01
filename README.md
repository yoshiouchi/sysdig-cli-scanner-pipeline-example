# Sysdig CLI Scanner – GitHub Actions Build & Scan Example

This repository demonstrates how to integrate the **Sysdig CLI Scanner** into a container image build pipeline using **GitHub Actions**.  
It builds a simple Python app into a Docker image and scans it for vulnerabilities during CI. If findings meet/exceed your chosen gate, the workflow **fails** to prevent insecure images from progressing.

---

## What you’ll learn

- Build a Docker image via **GitHub Actions**
- Scan the image with **Sysdig CLI Scanner** (using the official binary)
- **Fail the pipeline** on vulnerabilities (configurable threshold)
- (Optional) Use a named **Sysdig policy** to standardize your gates

---

## Prerequisites

- A Sysdig Secure SaaS account (e.g., `au1`, `us2`, `eu1`, `jp1`)
- A Sysdig **API token** with permissions to run image scans
- A GitHub repository with Actions enabled

---

## Quick Start

1. **Fork or clone** this repository.
2. **Create secret** in your repo:  
   - Go to: `Settings → Secrets and variables → Actions → New repository secret`  
   - Name: `SECURE_API_TOKEN`  
   - Value: *your Sysdig Secure API token*
3. **Confirm region URL** in the workflow (`.github/workflows/build-and-scan.yml`):  
   ```yaml
   env:
     SYSDIG_SECURE_URL: https://app.au1.sysdig.com  # change if needed
   ```
   Common regions:
   - `https://us2.app.sysdig.com`
   - `https://app.us4.sysdig.com`
   - `https://eu1.app.sysdig.com`
   - `https://app.au1.sysdig.com`
4. **Push a commit** or open a PR → the workflow will run automatically.  
   - The scan step is configured to fail the job if findings meet/exceed the gate.

---

## How it works

### App & Image
- Minimal Flask app at `app/main.py`
- Multi-stage Dockerfile builds a small Python 3.12 image

### Workflow (high level)
1. **Build image** locally (no push)
2. **Download scanner** from Sysdig’s official endpoint
3. **Scan** the locally built image:
   - Target format: `docker://local/<image>:<sha>`
   - Auth via environment variable: `SECURE_API_TOKEN`
   - Region URL via `SYSDIG_SECURE_URL`
   - Gate via `--fail-on` (defaults to `high`)
   - (Optional) Policy via `--policy=<name>`

If the scan exits non-zero (e.g., `--fail-on high` and HIGH/CRITICAL vulns found), the job fails and the PR check turns red.

---

## Configuration

The workflow uses these environment variables:

| Variable | Purpose | Example / Default |
|---|---|---|
| `SECURE_API_TOKEN` | **Required**. Sysdig API token (stored as GitHub Secret). | Set as repo secret `SECURE_API_TOKEN` |
| `SYSDIG_SECURE_URL` | Sysdig region URL. | `https://app.au1.sysdig.com` |
| `FAIL_ON` | Minimum severity to fail CI (`low`, `medium`, `high`, `critical`). | `high` |
| `BYPASS_SCAN_FAIL` | If set to `"true"`, pipeline continues even if scan fails. | `false` |
| `IMAGE_NAME` | Image name used in CI build. | `sysdig-cli-scanner-pipeline-example` |

**Policy (optional):**  
If your org manages gates via a named policy, set `--policy` in the scan step:
```yaml
--policy=cli-scanner-on-github-actions
```
Otherwise the `--fail-on` flag alone is enough for a basic gate.

---

## Repo Structure

```
.
├── app/
│   └── main.py         # Minimal Flask app ("Hello, Sysdig")
├── Dockerfile          # Multi-stage build, non-root runtime
├── requirements.txt    # Flask dependency
├── .dockerignore
├── .github/
│   └── workflows/
│       └── build-and-scan.yml
└── README.md
```

---

## The Workflow (key section)

The scan step in `.github/workflows/build-and-scan.yml` looks like this:

```yaml
- name: Scan with Sysdig CLI Scanner
  run: |
    set -euo pipefail
    echo "Scanning: docker://local/${IMAGE_NAME}:${IMAGE_TAG}"
    if ! SECURE_API_TOKEN="${SECURE_API_TOKEN}"         sysdig-cli-scanner           --apiurl "${SYSDIG_SECURE_URL}"           --policy=cli-scanner-on-github-actions           --fail-on "${FAIL_ON}"           docker://local/${IMAGE_NAME}:${IMAGE_TAG}
    then
      if [ "${BYPASS_SCAN_FAIL}" = "true" ]; then
        echo "Scan failed but BYPASS_SCAN_FAIL=true; continuing."
      else
        echo "Scan failed and BYPASS_SCAN_FAIL=false; failing job."
        exit 1
      fi
    fi
```

> If the runner has trouble with VM mode or docker archives, scanning the **local engine reference** (as above) is the simplest and most reliable route.

---

## Local Testing (optional)

Build and test locally before pushing:

```bash
# Build the image
docker build -t sysdig-cli-scanner-pipeline-example:dev .

# (Optional) Run it
docker run --rm -p 8000:8000 sysdig-cli-scanner-pipeline-example:dev
curl http://localhost:8000/
```

You can also test the scanner locally (if you’ve downloaded it and have a token):

```bash
SECURE_API_TOKEN="<your-token>" sysdig-cli-scanner   --apiurl "https://app.au1.sysdig.com"   --fail-on high   docker://sysdig-cli-scanner-pipeline-example:dev
```

---

## Troubleshooting

- **401/403 or auth errors** → Check that `SECURE_API_TOKEN` is valid and has the right permissions; confirm the correct `SYSDIG_SECURE_URL` region.
- **“Unable to get image”** → Ensure you scan a reference that exists on the runner. In this repo we use `docker://local/<name>:<sha>` after `load: true` in the build step.
- **Pipeline always green** → Verify `--fail-on` is set (e.g., `high`) or that your policy is enforcing a threshold.
- **First run fails** → Common when secrets/region aren’t set. Fix those and re-run.

---

## Security Notes

- The scanner binary is fetched fresh each run from Sysdig’s official endpoint.
- API tokens are stored only as **GitHub Actions secrets** and passed at runtime as env vars.
- The image runs the demo app as a **non-root** user.

---

## Credits

- Based on Sysdig CLI Scanner usage and the official install instructions.
- Repo created to serve as a concise, production-oriented example for CI gating.

---
