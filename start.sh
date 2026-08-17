#!/usr/bin/env bash

set -Eeuo pipefail

echo "========================================"
echo " HLS Proxy + Cloudflare Startup"
echo "========================================"

# ==================================================
# CONFIG
# ==================================================

CLOUDFLARE_TOKEN="eyJhIjoiNDk5ZmQ5Mzc5MDRjYWJhOGRmODJjNzI1ZGU0ZWRlNTQiLCJ0IjoiNzQyNzk5NDAtOGRiYi00NDM4LWE4ZGQtZmVkOTkxMGUxY2Y5IiwicyI6Ik5EQXhOR1ptWVRjdFpURmpNUzAwWWpnMExXRTBNREV0WldKa01UYzFOalJtWlRjMCJ9
"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HLS_DIR="$PROJECT_DIR/hls-proxy"
HLS_PORT=3000

# ==================================================
# FUNCTIONS
# ==================================================

cleanup() {
    echo ""
    echo "Stopping HLS proxy..."

    if [ -n "${HLS_PID:-}" ]; then
        kill "$HLS_PID" 2>/dev/null || true
    fi
}

trap cleanup EXIT INT TERM

# ==================================================
# 1. CLOUDFLARED
# ==================================================

echo ""
echo "[1/6] Checking cloudflared..."

if ! command -v cloudflared >/dev/null 2>&1; then

    echo "cloudflared not found."
    echo "Installing cloudflared..."

    sudo mkdir -p --mode=0755 /usr/share/keyrings

    curl -fsSL \
        https://pkg.cloudflare.com/cloudflare-public-v2.gpg \
        | sudo tee /usr/share/keyrings/cloudflare-public-v2.gpg >/dev/null

    echo \
        "deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main" \
        | sudo tee /etc/apt/sources.list.d/cloudflared.list >/dev/null

    sudo apt-get update

    sudo apt-get install -y cloudflared

fi

echo "cloudflared:"
cloudflared --version

# ==================================================
# 2. CHECK HLS PROJECT
# ==================================================

echo ""
echo "[2/6] Checking HLS proxy..."

if [ ! -d "$HLS_DIR" ]; then
    echo "ERROR:"
    echo "$HLS_DIR does not exist."
    exit 1
fi

if [ ! -f "$HLS_DIR/server.js" ]; then
    echo "ERROR:"
    echo "$HLS_DIR/server.js does not exist."
    exit 1
fi

echo "HLS proxy found."
echo "Location: $HLS_DIR"

# ==================================================
# 3. ROOT DEPENDENCIES
# ==================================================

echo ""
echo "[3/6] Installing root dependencies..."

cd "$PROJECT_DIR"

if [ -f "yarn.lock" ]; then

    yarn install --frozen-lockfile

elif [ -f "package-lock.json" ]; then

    npm install

elif [ -f "package.json" ]; then

    yarn install

else

    echo "No root package.json found."
    echo "Skipping root dependency installation."

fi

# ==================================================
# 4. HLS DEPENDENCIES
# ==================================================

echo ""
echo "[4/6] Installing HLS proxy dependencies..."

cd "$HLS_DIR"

if [ -f "package.json" ]; then

    echo "Found hls-proxy/package.json"

    if [ -f "yarn.lock" ]; then

        echo "Using yarn..."
        yarn install --frozen-lockfile

    elif [ -f "package-lock.json" ]; then

        echo "Using npm..."
        npm install

    else

        echo "No lockfile found."
        echo "Running npm install..."

        npm install

    fi

else

    echo "WARNING: hls-proxy/package.json not found."

    echo "Installing express..."

    npm install express

fi

# ==================================================
# CHECK EXPRESS
# ==================================================

echo ""
echo "Checking Express..."

if ! node -e "require('express')" >/dev/null 2>&1; then

    echo "Express is missing."
    echo "Installing express..."

    npm install express

fi

echo "Express: OK"

# ==================================================
# 5. CLOUDFLARE TOKEN
# ==================================================

echo ""
echo "[5/6] Checking Cloudflare token..."

if [ -z "$CLOUDFLARE_TOKEN" ]; then

    echo ""
    echo "ERROR: Cloudflare token is empty."
    exit 1

fi

if [ "$CLOUDFLARE_TOKEN" = "PASTE_YOUR_NEW_CLOUDFLARE_TOKEN_HERE" ]; then

    echo ""
    echo "ERROR: You haven't added your Cloudflare token."
    echo ""
    echo "Edit start.sh and change:"
    echo ""
    echo 'CLOUDFLARE_TOKEN="PASTE_YOUR_NEW_CLOUDFLARE_TOKEN_HERE"'
    echo ""
    echo "to:"
    echo ""
    echo 'CLOUDFLARE_TOKEN="YOUR_REAL_TOKEN"'
    echo ""

    exit 1

fi

echo "Cloudflare token: OK"

# ==================================================
# 6. START HLS PROXY
# ==================================================

echo ""
echo "========================================"
echo " Starting HLS Proxy"
echo "========================================"

cd "$HLS_DIR"

node server.js > /tmp/hls-proxy.log 2>&1 &

HLS_PID=$!

cd "$PROJECT_DIR"

echo "HLS PID: $HLS_PID"

echo ""
echo "Waiting for HLS proxy..."

# ==================================================
# WAIT FOR HLS
# ==================================================

HLS_READY=false

for i in $(seq 1 20); do

    # Check whether something is listening on port 3000
    if command -v ss >/dev/null 2>&1; then

        if ss -ltn 2>/dev/null | grep -q ":$HLS_PORT "; then
            HLS_READY=true
            break
        fi

    fi

    # Fallback: curl
    if curl -sS \
        --connect-timeout 1 \
        --max-time 2 \
        "http://127.0.0.1:$HLS_PORT/" \
        >/dev/null 2>&1; then

        HLS_READY=true
        break

    fi

    sleep 1

done

# ==================================================
# HLS FAILED
# ==================================================

if [ "$HLS_READY" != "true" ]; then

    echo ""
    echo "========================================"
    echo " ERROR: HLS PROXY DID NOT START"
    echo "========================================"

    echo ""
    echo "HLS proxy output:"
    echo "----------------------------------------"

    cat /tmp/hls-proxy.log 2>/dev/null || true

    echo "----------------------------------------"

    echo ""
    echo "Port $HLS_PORT status:"

    if command -v ss >/dev/null 2>&1; then
        ss -ltnp 2>/dev/null | grep ":$HLS_PORT" || true
    fi

    exit 1

fi

# ==================================================
# HLS READY
# ==================================================

echo ""
echo "========================================"
echo " HLS PROXY READY"
echo "========================================"

echo "URL: http://localhost:$HLS_PORT"
echo "PID: $HLS_PID"

# ==================================================
# CLOUDFLARE
# ==================================================

echo ""
echo "========================================"
echo " Starting Cloudflare Tunnel"
echo "========================================"

cloudflared tunnel run \
    --token "$CLOUDFLARE_TOKEN"
