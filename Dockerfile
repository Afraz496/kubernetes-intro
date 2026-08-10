# The base image pins the OS and the Python version together.
# "slim" is Debian with a minimal package set - small, but you add what you need.
FROM python:3.12-slim

# System libraries. This is the layer that renv/venv/pip could never capture:
# nothing in requirements.txt knows that your build needs a C toolchain.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Dependencies are copied and installed BEFORE the source code, so that editing
# main.py doesn't invalidate the cached pip layer. Rebuilds go from ~60s to ~2s.
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ ./

# Don't run as root. Kubernetes clusters increasingly refuse containers that do.
RUN useradd --create-home --uid 10001 runner
USER runner

ENTRYPOINT ["python", "main.py"]
