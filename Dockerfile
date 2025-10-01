# ---- Build stage ----
FROM python:3.12-slim AS builder

# Prevent interactive tzdata etc.
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# Work directory
WORKDIR /app

# Only copy requirements first for better layer caching
COPY requirements.txt .

# Install build deps only if needed for wheels (kept minimal here)
RUN pip install --upgrade pip && \
    pip wheel --wheel-dir /wheels -r requirements.txt

# ---- Runtime stage ----
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Create non-root user
RUN useradd -m -u 10001 appuser

WORKDIR /app

# Copy wheels + install, then copy app
COPY --from=builder /wheels /wheels
RUN pip install --no-index --find-links=/wheels /wheels/* && rm -rf /wheels
COPY app ./app

# Expose service port
EXPOSE 8000

# Basic healthcheck (container sidecar-friendly)
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/', timeout=2)" || exit 1

# Drop privileges
USER appuser

# Run the app (simple Flask dev server is fine for demo/CI)
CMD ["python", "app/main.py"]
