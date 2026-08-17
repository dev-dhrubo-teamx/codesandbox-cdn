# HLS Proxy + Cloudflare Tunnel

A lightweight HLS proxy service designed to run in a cloud development environment and expose the local HLS proxy through a Cloudflare Tunnel.

## ✨ Features

* 🚀 Simple HLS proxy server
* ☁️ Cloudflare Tunnel integration
* 🔄 Automatic `cloudflared` installation
* 📦 Automatic dependency installation
* 🛠️ CodeSandbox startup support
* 🔐 Cloudflare Tunnel token support
* ❤️ Health and startup validation
* 📡 Runs the HLS proxy on port `3000`

---

## 📁 Project Structure

```text
.
├── hls-proxy/
│   ├── server.js
│   ├── package.json
│   └── node_modules/
│
├── package.json
├── yarn.lock
├── tasks.json
└── README.md
```

---

## 🧰 Requirements

Before running the project, make sure the environment provides:

* Node.js 20+
* Yarn or npm
* `curl`
* `sudo` access for automatic `cloudflared` installation
* A Cloudflare Tunnel
* A valid Cloudflare Tunnel token

---

## 🚀 Getting Started

### 1. Clone the repository

```bash
git clone <YOUR_REPOSITORY_URL>
cd <YOUR_PROJECT_DIRECTORY>
```

### 2. Install dependencies

Install the root dependencies:

```bash
yarn install
```

Then install the HLS proxy dependencies:

```bash
cd hls-proxy
npm install
cd ..
```

---

## ☁️ Cloudflare Tunnel

This project uses `cloudflared` to expose the local HLS proxy through a Cloudflare Tunnel.

If `cloudflared` is not installed, the CodeSandbox startup task automatically installs it using Cloudflare's official APT repository.

You can verify the installation with:

```bash
cloudflared --version
```

---

## 🔑 Cloudflare Token

The startup configuration expects a Cloudflare Tunnel token.

In `tasks.json`, configure:

```bash
cloudflared tunnel run --token "YOUR_NEW_CLOUDFLARE_TOKEN"
```

Replace:

```text
YOUR_NEW_CLOUDFLARE_TOKEN
```

with your actual Cloudflare Tunnel token.

### ⚠️ Security

**Never commit a real Cloudflare token to a public GitHub repository.**

For production or public repositories, use an environment variable or secret instead:

```bash
CLOUDFLARE_TUNNEL_TOKEN="your-token"
```

Then:

```bash
cloudflared tunnel run --token "$CLOUDFLARE_TUNNEL_TOKEN"
```

If a token has accidentally been exposed, revoke or rotate it immediately.

---

## ▶️ Running Locally

Start the HLS proxy:

```bash
cd hls-proxy
node server.js
```

The proxy should become available at:

```text
http://localhost:3000
```

You should see:

```text
Proxy running on http://localhost:3000
```

---

## ☁️ Running With Cloudflare

Once the HLS proxy is running on port `3000`, start the Cloudflare Tunnel:

```bash
cloudflared tunnel run --token "YOUR_NEW_CLOUDFLARE_TOKEN"
```

Cloudflare will establish a tunnel between the local development environment and your configured Cloudflare Tunnel.

---

## 🧪 CodeSandbox

This project is configured to support CodeSandbox startup tasks.

The startup process performs the following steps:

```text
CodeSandbox starts
       │
       ▼
Install project dependencies
       │
       ▼
Check cloudflared
       │
       ├── Installed ───────┐
       │                    │
       └── Missing          │
             │              │
             ▼              │
      Install cloudflared   │
             │              │
             └──────────────┘
                    │
                    ▼
             Install HLS dependencies
                    │
                    ▼
             Start HLS Proxy
                    │
                    ▼
             Verify port 3000
                    │
                    ▼
             Start Cloudflare Tunnel
```

---

## ⚙️ CodeSandbox `tasks.json`

The project can use the following startup configuration:

```json
{
  "setupTasks": [
    {
      "name": "Install Dependencies",
      "command": "yarn install && if [ -d hls-proxy ] && [ -f hls-proxy/package.json ]; then cd hls-proxy && npm install; fi"
    },
    {
      "name": "Install Cloudflared",
      "command": "if ! command -v cloudflared >/dev/null 2>&1; then sudo mkdir -p --mode=0755 /usr/share/keyrings && curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg | sudo tee /usr/share/keyrings/cloudflare-public-v2.gpg >/dev/null && echo 'deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main' | sudo tee /etc/apt/sources.list.d/cloudflared.list >/dev/null && sudo apt-get update && sudo apt-get install -y cloudflared; fi"
    }
  ],
  "tasks": {
    "start": {
      "name": "Start HLS Proxy + Cloudflare",
      "command": "sh -c 'set -e; echo \"========================================\"; echo \" Starting HLS Proxy + Cloudflare\"; echo \"========================================\"; if ! command -v cloudflared >/dev/null 2>&1; then echo \"Installing cloudflared...\"; sudo mkdir -p --mode=0755 /usr/share/keyrings; curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg | sudo tee /usr/share/keyrings/cloudflare-public-v2.gpg >/dev/null; echo \"deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main\" | sudo tee /etc/apt/sources.list.d/cloudflared.list >/dev/null; sudo apt-get update; sudo apt-get install -y cloudflared; fi; echo \"cloudflared: $(cloudflared --version)\"; if [ ! -d hls-proxy ]; then echo \"ERROR: hls-proxy directory not found\"; exit 1; fi; if [ ! -f hls-proxy/server.js ]; then echo \"ERROR: hls-proxy/server.js not found\"; exit 1; fi; echo \"Installing HLS dependencies...\"; cd hls-proxy; if [ -f package.json ]; then if [ -f yarn.lock ]; then yarn install --frozen-lockfile; elif [ -f package-lock.json ]; then npm install; else npm install; fi; fi; echo \"Starting HLS proxy...\"; node server.js > /tmp/hls-proxy.log 2>&1 & HLS_PID=$!; cd ..; sleep 3; if ! kill -0 $HLS_PID 2>/dev/null; then echo \"HLS process check failed, checking port 3000...\"; fi; if command -v ss >/dev/null 2>&1; then if ! ss -ltn 2>/dev/null | grep -q \":3000 \"; then echo \"ERROR: HLS proxy is not listening on port 3000\"; cat /tmp/hls-proxy.log 2>/dev/null || true; exit 1; fi; else if ! curl -sS --connect-timeout 2 --max-time 3 http://127.0.0.1:3000/ >/dev/null 2>&1; then echo \"ERROR: HLS proxy is not responding on port 3000\"; cat /tmp/hls-proxy.log 2>/dev/null || true; exit 1; fi; fi; echo \"HLS proxy is running on port 3000\"; echo \"Starting Cloudflare tunnel...\"; cloudflared tunnel run --token \"YOUR_NEW_CLOUDFLARE_TOKEN\"'",
      "runAtStart": true
    },
    "install": {
      "name": "Install Dependencies",
      "command": "yarn install && if [ -d hls-proxy ] && [ -f hls-proxy/package.json ]; then cd hls-proxy && npm install; fi"
    }
  }
}
```

> **Important:** Do not commit a real Cloudflare token inside `tasks.json` if this repository is public.

---

## 🔍 Troubleshooting

### `cloudflared: command not found`

Install it manually:

```bash
sudo mkdir -p --mode=0755 /usr/share/keyrings

curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg \
  | sudo tee /usr/share/keyrings/cloudflare-public-v2.gpg >/dev/null

echo 'deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main' \
  | sudo tee /etc/apt/sources.list.d/cloudflared.list

sudo apt-get update
sudo apt-get install -y cloudflared
```

Verify:

```bash
cloudflared --version
```

### `Cannot find module 'express'`

Install the HLS proxy dependencies:

```bash
cd hls-proxy
npm install
```

Or, if the project uses Yarn:

```bash
yarn install
```

### HLS proxy does not start

Check the server directly:

```bash
cd hls-proxy
node server.js
```

Expected output:

```text
Proxy running on http://localhost:3000
```

### Check port 3000

```bash
curl http://127.0.0.1:3000/
```

You can also check whether something is listening:

```bash
ss -ltnp | grep 3000
```

### Cloudflare tunnel does not connect

Verify:

```bash
cloudflared --version
```

Then test the tunnel manually:

```bash
cloudflared tunnel run --token "YOUR_NEW_CLOUDFLARE_TOKEN"
```

Make sure the token belongs to the correct Cloudflare Tunnel.

---

## 🛡️ Security Recommendations

* Never commit Cloudflare tokens.
* Never expose API keys in `tasks.json`.
* Rotate tokens immediately if they are leaked.
* Use GitHub Secrets or CodeSandbox environment variables for production deployments.
* Keep dependencies updated.
* Avoid running unnecessary services with elevated privileges.

---

## 📜 License

Add your preferred license here, for example:

```text
MIT License
```

If this project is not intended to be open source, remove the license section.

---

## 👤 Author

**Your Name**

* GitHub: `@your-username`

---

## ⭐ Contributing

Contributions, bug reports, and improvements are welcome.

### Development workflow

```bash
git clone <repository-url>
cd <project-directory>

yarn install

cd hls-proxy
npm install

cd ..
```

Make your changes, test locally, and submit a pull request.

---

## 📌 Status

**Project Status:** Active Development

The project is currently optimized for running the HLS proxy inside a CodeSandbox-style cloud development environment with Cloudflare Tunnel support.
